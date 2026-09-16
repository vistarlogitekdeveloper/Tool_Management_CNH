import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper over Dio that owns three concerns the screens should never see:
/// bearer-token injection, silent refresh on 401, and unwrapping the API's
/// `{ success, data, meta }` envelope.
class ApiClient {
  ApiClient({required TokenStorage storage, Dio? dio, String? baseUrl})
      : _storage = storage,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
      // Let the interceptor decide; don't have Dio throw before we can refresh.
      validateStatus: (status) => status != null && status < 500,
    );
    _dio.interceptors.add(_authInterceptor());
    if (AppConfig.isDebug) {
      _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false, error: true));
    }
  }

  final Dio _dio;
  final TokenStorage _storage;

  Dio get raw => _dio;
  String get baseUrl => _dio.options.baseUrl;

  /// Fired when refresh fails — the app router listens and returns to login.
  final _sessionExpired = StreamController<void>.broadcast();
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  /// Guards against a burst of 401s each launching its own refresh.
  Future<String?>? _refreshInFlight;

  InterceptorsWrapper _authInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty && !options.extra.containsKey('skipAuth')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode != 401 || response.requestOptions.extra['isRetry'] == true) {
            return handler.next(response);
          }
          // Access token expired — refresh once, then replay the request.
          final fresh = await _refreshToken();
          if (fresh == null) {
            _sessionExpired.add(null);
            return handler.next(response);
          }
          try {
            final options = response.requestOptions
              ..headers['Authorization'] = 'Bearer $fresh'
              ..extra['isRetry'] = true;
            final retried = await _dio.fetch<dynamic>(options);
            return handler.resolve(retried);
          } catch (_) {
            return handler.next(response);
          }
        },
      );

  Future<String?> _refreshToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final response = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl)).post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payload = Map<String, dynamic>.from(data['data'] as Map);
        await _storage.saveTokens(
          accessToken: payload['accessToken'] as String,
          refreshToken: payload['refreshToken'] as String,
        );
        if (payload['user'] is Map) {
          await _storage.saveUser(Map<String, dynamic>.from(payload['user'] as Map));
        }
        return payload['accessToken'] as String;
      }
      // The server answered, and the answer was that this refresh token is no
      // good. Only then is the session actually over.
      await _storage.clear();
      return null;
    } on DioException catch (error) {
      debugPrint('Token refresh failed: $error');
      // A timeout, a DNS failure or a 5xx says nothing about whether the token is
      // still valid. Clearing storage here signed people out of a working session
      // every time the network hiccuped; leave it in place and let the next
      // attempt succeed.
      return null;
    } catch (error) {
      debugPrint('Token refresh failed: $error');
      return null;
    }
  }

  /* ── Verbs ─────────────────────────────────────────────────────────────── */

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _send<T>(() => _dio.get<dynamic>(path, queryParameters: _clean(query), cancelToken: cancelToken));

  /// Like [get] but returns the `meta` block alongside `data`, for paged lists.
  Future<PagedResult<T>> getPaged<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic>) parse,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _sendRaw(
      () => _dio.get<dynamic>(path, queryParameters: _clean(query), cancelToken: cancelToken),
    );
    final list = (envelope['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList();
    return PagedResult<T>(items: list, meta: PageMeta.fromJson(envelope['meta']));
  }

  Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.post<dynamic>(path, data: data, queryParameters: _clean(query)));

  Future<T> patch<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.patch<dynamic>(path, data: data));

  Future<T> put<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.put<dynamic>(path, data: data));

  Future<T> delete<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.delete<dynamic>(path, data: data));

  /// Multipart upload used for drawings, tool photos and certificates.
  Future<Map<String, dynamic>> upload({
    required String category,
    required List<int> bytes,
    required String filename,
    String? entityType,
    String? entityId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (entityType != null) 'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
    });
    final envelope = await _sendRaw(
      () => _dio.post<dynamic>(
        '/files',
        data: form,
        queryParameters: {'category': category},
        onSendProgress: onProgress,
      ),
    );
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  /// Binary download (Excel / PDF report exports).
  Future<DownloadedFile> download(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        options: Options(responseType: ResponseType.bytes, validateStatus: (s) => s != null && s < 500),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw ApiException(
          message: 'The export could not be generated (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final disposition = response.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      return DownloadedFile(
        bytes: response.data ?? const [],
        filename: match?.group(1) ?? 'export',
        contentType: response.headers.value('content-type') ?? 'application/octet-stream',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /* ── Internals ─────────────────────────────────────────────────────────── */

  Future<T> _send<T>(Future<Response<dynamic>> Function() request) async {
    final envelope = await _sendRaw(request);
    return envelope['data'] as T;
  }

  Future<Map<String, dynamic>> _sendRaw(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 500;
      final body = response.data;

      if (status >= 400) {
        throw ApiException.fromDio(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }
      if (body == null) return <String, dynamic>{'data': null};
      if (body is Map) return Map<String, dynamic>.from(body);
      // A non-enveloped body (a raw file, say) still needs a uniform shape.
      return <String, dynamic>{'data': body};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Drop nulls and empty strings so they don't become `?status=` in the URL.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      out[key] = value;
    });
    return out.isEmpty ? null : out;
  }

  void dispose() {
    _sessionExpired.close();
    _dio.close(force: true);
  }
}

/// Pagination metadata returned by every list endpoint.
class PageMeta {
  const PageMeta({
    this.page = 1,
    this.limit = AppConfig.pageSize,
    this.total = 0,
    this.totalPages = 1,
    this.hasNext = false,
    this.hasPrev = false,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory PageMeta.fromJson(Object? json) {
    if (json is! Map) return const PageMeta();
    final m = Map<String, dynamic>.from(json);
    return PageMeta(
      page: (m['page'] as num?)?.toInt() ?? 1,
      limit: (m['limit'] as num?)?.toInt() ?? AppConfig.pageSize,
      total: (m['total'] as num?)?.toInt() ?? 0,
      totalPages: (m['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: m['hasNext'] as bool? ?? false,
      hasPrev: m['hasPrev'] as bool? ?? false,
    );
  }

  int get firstRow => total == 0 ? 0 : (page - 1) * limit + 1;
  int get lastRow => total == 0 ? 0 : ((page - 1) * limit + limit).clamp(0, total);
}

class PagedResult<T> {
  const PagedResult({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  bool get isEmpty => items.isEmpty;
}

class DownloadedFile {
  const DownloadedFile({required this.bytes, required this.filename, required this.contentType});

  final List<int> bytes;
  final String filename;
  final String contentType;
}
