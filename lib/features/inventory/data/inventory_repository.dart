import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/inventory.dart';
import '../../../models/json.dart';
import '../../../models/tool.dart';

class InventoryRepository {
  InventoryRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<InventoryRow>> list(InventoryQuery query) =>
      _api.getPaged('/inventory', query: query.toQuery(), parse: InventoryRow.fromJson);

  Future<InventorySummary> summary() async =>
      InventorySummary.fromJson(await _api.get<Json>('/inventory/summary'));

  Future<List<LowStockItem>> lowStock() async {
    final data = await _api.get<List<dynamic>>('/inventory/low-stock');
    return data.whereType<Map>().map((e) => LowStockItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Valuation> valuation() async =>
      Valuation.fromJson(await _api.get<Json>('/inventory/valuation'));

  Future<PagedResult<StockMovement>> transactions({
    int? toolId,
    String? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) =>
      _api.getPaged('/inventory/transactions',
          query: {
            'toolId': toolId,
            'type': type,
            'from': _d(from),
            'to': _d(to),
            'page': page,
            'limit': limit,
          },
          parse: StockMovement.fromJson);

  Future<Json> adjust({
    required int toolId,
    required String direction,
    required int qty,
    required String reason,
    int? locationId,
  }) =>
      _api.post<Json>('/inventory/adjust', data: {
        'toolId': toolId,
        'direction': direction,
        'qty': qty,
        'reason': reason,
        if (locationId != null) 'locationId': locationId,
      });

  static String? _d(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@immutable
class InventoryQuery {
  const InventoryQuery({
    this.q = '',
    this.categoryId,
    this.locationId,
    this.lowStock,
    this.page = 1,
    this.limit = 25,
    this.sort = 'toolCode',
    this.order = 'asc',
  });

  final String q;
  final int? categoryId;
  final int? locationId;
  final bool? lowStock;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (locationId != null) 'locationId': locationId,
        if (lowStock != null) 'lowStock': lowStock,
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  InventoryQuery copyWith({
    String? q,
    int? categoryId,
    int? locationId,
    bool? lowStock,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearCategory = false,
    bool clearLocation = false,
    bool clearLowStock = false,
  }) =>
      InventoryQuery(
        q: q ?? this.q,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        lowStock: clearLowStock ? null : (lowStock ?? this.lowStock),
        page: page ?? 1,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  InventoryQuery withSort(String column) => copyWith(
        sort: column,
        order: sort == column && order == 'asc' ? 'desc' : 'asc',
        page: 1,
      );

  @override
  bool operator ==(Object other) =>
      other is InventoryQuery &&
      other.q == q &&
      other.categoryId == categoryId &&
      other.locationId == locationId &&
      other.lowStock == lowStock &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode => Object.hash(q, categoryId, locationId, lowStock, page, limit, sort, order);
}

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepository(ref.watch(apiClientProvider)));

final inventoryQueryProvider = StateProvider<InventoryQuery>((ref) => const InventoryQuery());

final inventoryListProvider = FutureProvider.autoDispose<PagedResult<InventoryRow>>(
  (ref) => ref.watch(inventoryRepositoryProvider).list(ref.watch(inventoryQueryProvider)),
);

final inventorySummaryProvider = FutureProvider.autoDispose<InventorySummary>(
  (ref) => ref.watch(inventoryRepositoryProvider).summary(),
);

final lowStockProvider = FutureProvider.autoDispose<List<LowStockItem>>(
  (ref) => ref.watch(inventoryRepositoryProvider).lowStock(),
);

final valuationProvider = FutureProvider.autoDispose<Valuation>(
  (ref) => ref.watch(inventoryRepositoryProvider).valuation(),
);

final toolLedgerProvider = FutureProvider.autoDispose.family<PagedResult<StockMovement>, int>(
  (ref, toolId) => ref.watch(inventoryRepositoryProvider).transactions(toolId: toolId, limit: 100),
);
