import 'package:dio/dio.dart';

/// A failure the UI can present as a sentence. Every network error is funnelled
/// through here so screens never have to interpret a `DioException`.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;

  /// field name -> message, populated from the API's VALIDATION_ERROR payload
  /// so a form can highlight the offending input.
  final Map<String, String> fieldErrors;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  /// 422 — a business rule was violated (insufficient stock, calibration
  /// overdue, already returned). These are expected outcomes, not bugs.
  bool get isBusinessRule => statusCode == 422;

  bool get isNetwork => statusCode == null;

  bool get isInsufficientStock => code == 'INSUFFICIENT_STOCK';
  bool get isCalibrationBlocked => code == 'CALIBRATION_BLOCKED';

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: 'The server took too long to respond. Check the plant network and try again.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Cannot reach the TMS server. Check your connection, then try again.',
          code: 'OFFLINE',
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled', code: 'CANCELLED');
      case DioExceptionType.badCertificate:
        return ApiException(message: 'The server certificate was rejected.', code: 'BAD_CERT');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = error.response;
    final status = response?.statusCode;
    final body = response?.data;

    if (body is Map && body['error'] is Map) {
      final err = Map<String, dynamic>.from(body['error'] as Map);
      return ApiException(
        message: (err['message'] as String?)?.trim().isNotEmpty == true
            ? err['message'] as String
            : _defaultMessage(status),
        statusCode: status,
        code: err['code'] as String?,
        fieldErrors: _parseFieldErrors(err['details']),
        details: err['details'],
      );
    }

    return ApiException(message: _defaultMessage(status), statusCode: status);
  }

  static Map<String, String> _parseFieldErrors(Object? details) {
    if (details is! List) return const {};
    final out = <String, String>{};
    for (final item in details) {
      if (item is Map && item['field'] != null && item['message'] != null) {
        out[item['field'].toString()] = item['message'].toString();
      }
    }
    return out;
  }

  static String _defaultMessage(int? status) => switch (status) {
        400 => 'The request was rejected. Please check the values entered.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Your role does not allow this action.',
        404 => 'That record could not be found.',
        409 => 'Someone else changed this record. Refresh and try again.',
        422 => 'That operation is not allowed in the current state.',
        429 => 'Too many requests. Please wait a moment.',
        final int code when code >= 500 =>
          'The server hit an unexpected error. Please report this to IT.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => message;
}
