import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/tool.dart';

class ToolsRepository {
  ToolsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<Tool>> list(ToolQuery query) =>
      _api.getPaged('/tools', query: query.toQuery(), parse: Tool.fromJson);

  Future<Tool> byId(int id) async => Tool.fromJson(await _api.get<Json>('/tools/$id'));

  Future<List<ToolOption>> lookup({String? q, bool availableOnly = false, int limit = 50}) async {
    final data = await _api.get<List<dynamic>>('/tools/lookup', query: {
      'q': q,
      'availableOnly': availableOnly,
      'limit': limit,
    });
    return data.whereType<Map>().map((e) => ToolOption.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ToolHistory> history(int id, {DateTime? from, DateTime? to}) async =>
      ToolHistory.fromJson(await _api.get<Json>('/tools/$id/history', query: {
        'from': _d(from),
        'to': _d(to),
      }));

  Future<Tool> create(Json payload) async => Tool.fromJson(await _api.post<Json>('/tools', data: payload));

  Future<Tool> update(int id, Json payload) async =>
      Tool.fromJson(await _api.patch<Json>('/tools/$id', data: payload));

  Future<void> deactivate(int id, {String status = 'INACTIVE', String? reason}) =>
      _api.delete<Json>('/tools/$id', data: {'status': status, if (reason != null) 'reason': reason});

  static String? _d(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Filter state for the Tool Master grid. Immutable so Riverpod can key on it.
@immutable
class ToolQuery {
  const ToolQuery({
    this.q = '',
    this.categoryId,
    this.locationId,
    this.shop,
    this.status,
    this.lowStock,
    this.calibrationRequired,
    this.page = 1,
    this.limit = 25,
    this.sort = 'toolCode',
    this.order = 'asc',
  });

  final String q;
  final int? categoryId;
  final int? locationId;
  final String? shop;
  final String? status;
  final bool? lowStock;
  final bool? calibrationRequired;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (locationId != null) 'locationId': locationId,
        if (shop != null) 'shop': shop,
        if (status != null) 'status': status,
        if (lowStock != null) 'lowStock': lowStock,
        if (calibrationRequired != null) 'calibrationRequired': calibrationRequired,
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  ToolQuery copyWith({
    String? q,
    int? categoryId,
    int? locationId,
    String? shop,
    String? status,
    bool? lowStock,
    bool? calibrationRequired,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearCategory = false,
    bool clearLocation = false,
    bool clearStatus = false,
    bool clearLowStock = false,
  }) =>
      ToolQuery(
        q: q ?? this.q,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        shop: shop ?? this.shop,
        status: clearStatus ? null : (status ?? this.status),
        lowStock: clearLowStock ? null : (lowStock ?? this.lowStock),
        calibrationRequired: calibrationRequired ?? this.calibrationRequired,
        // Any filter change resets to page 1 unless the caller says otherwise.
        page: page ?? 1,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  /// Toggling the same column flips direction; a new column starts ascending.
  ToolQuery withSort(String column) => copyWith(
        sort: column,
        order: sort == column && order == 'asc' ? 'desc' : 'asc',
        page: 1,
      );

  bool get hasFilters =>
      q.trim().isNotEmpty || categoryId != null || locationId != null || status != null || lowStock != null;

  @override
  bool operator ==(Object other) =>
      other is ToolQuery &&
      other.q == q &&
      other.categoryId == categoryId &&
      other.locationId == locationId &&
      other.shop == shop &&
      other.status == status &&
      other.lowStock == lowStock &&
      other.calibrationRequired == calibrationRequired &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
      q, categoryId, locationId, shop, status, lowStock, calibrationRequired, page, limit, sort, order);
}

final toolsRepositoryProvider =
    Provider<ToolsRepository>((ref) => ToolsRepository(ref.watch(apiClientProvider)));

final toolQueryProvider = StateProvider<ToolQuery>((ref) => const ToolQuery());

final toolsListProvider = FutureProvider.autoDispose<PagedResult<Tool>>(
  (ref) => ref.watch(toolsRepositoryProvider).list(ref.watch(toolQueryProvider)),
);

final toolDetailProvider = FutureProvider.autoDispose.family<Tool, int>(
  (ref, id) => ref.watch(toolsRepositoryProvider).byId(id),
);

final toolHistoryProvider = FutureProvider.autoDispose.family<ToolHistory, int>(
  (ref, id) => ref.watch(toolsRepositoryProvider).history(id),
);

/// Options for the issue / PO / transfer pickers, cached for the session.
final toolOptionsProvider = FutureProvider<List<ToolOption>>(
  (ref) => ref.watch(toolsRepositoryProvider).lookup(limit: 200),
);
