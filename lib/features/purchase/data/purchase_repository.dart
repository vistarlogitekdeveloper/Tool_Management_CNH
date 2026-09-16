import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/purchase.dart';

class PurchaseRepository {
  PurchaseRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<PurchaseOrder>> list(PurchaseQuery query) =>
      _api.getPaged('/purchase', query: query.toQuery(), parse: PurchaseOrder.fromJson);

  Future<PurchaseOrder> byId(int id) async =>
      PurchaseOrder.fromJson(await _api.get<Json>('/purchase/$id'));

  Future<PurchaseSummary> summary() async =>
      PurchaseSummary.fromJson(await _api.get<Json>('/purchase/summary'));

  Future<List<ReorderSuggestion>> reorderSuggestions() async {
    final data = await _api.get<List<dynamic>>('/purchase/reorder-suggestions');
    return data
        .whereType<Map>()
        .map((e) => ReorderSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PurchaseOrder> create({
    required int vendorId,
    required List<PoDraftLine> lines,
    DateTime? poDate,
    DateTime? expectedDate,
    String? referenceNo,
    String? remarks,
  }) async =>
      PurchaseOrder.fromJson(await _api.post<Json>('/purchase', data: {
        'vendorId': vendorId,
        'items': lines.map((l) => l.toJson()).toList(),
        if (poDate != null) 'poDate': _d(poDate),
        if (expectedDate != null) 'expectedDate': _d(expectedDate),
        if (referenceNo?.isNotEmpty == true) 'referenceNo': referenceNo,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<PurchaseOrder> approve(int id, {required bool approve, String? remarks}) async =>
      PurchaseOrder.fromJson(await _api.post<Json>('/purchase/$id/approve', data: {
        'decision': approve ? 'APPROVE' : 'REJECT',
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<PurchaseOrder> markInTransit(int id, {DateTime? expectedDate}) async =>
      PurchaseOrder.fromJson(await _api.post<Json>('/purchase/$id/in-transit', data: {
        if (expectedDate != null) 'expectedDate': _d(expectedDate),
      }));

  /// Omitting [items] receives everything still outstanding on the order.
  Future<PurchaseOrder> receive(
    int id, {
    List<Map<String, dynamic>>? items,
    DateTime? receiptDate,
    String? invoiceNo,
    int? locationId,
    String? remarks,
  }) async =>
      PurchaseOrder.fromJson(await _api.post<Json>('/purchase/$id/receive', data: {
        if (items != null) 'items': items,
        if (receiptDate != null) 'receiptDate': _d(receiptDate),
        if (invoiceNo?.isNotEmpty == true) 'invoiceNo': invoiceNo,
        if (locationId != null) 'locationId': locationId,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@immutable
class PurchaseQuery {
  const PurchaseQuery({
    this.q = '',
    this.status,
    this.vendorId,
    this.toolId,
    this.openOnly,
    this.from,
    this.to,
    this.page = 1,
    this.limit = 25,
    this.sort = 'poDate',
    this.order = 'desc',
  });

  final String q;
  final String? status;
  final int? vendorId;
  final int? toolId;
  final bool? openOnly;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null) 'status': status,
        if (vendorId != null) 'vendorId': vendorId,
        if (toolId != null) 'toolId': toolId,
        if (openOnly == true) 'openOnly': true,
        if (from != null) 'from': PurchaseRepository._d(from!),
        if (to != null) 'to': PurchaseRepository._d(to!),
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  PurchaseQuery copyWith({
    String? q,
    String? status,
    int? vendorId,
    int? toolId,
    bool? openOnly,
    DateTime? from,
    DateTime? to,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearStatus = false,
    bool clearVendor = false,
    bool clearOpenOnly = false,
  }) =>
      PurchaseQuery(
        q: q ?? this.q,
        status: clearStatus ? null : (status ?? this.status),
        vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
        toolId: toolId ?? this.toolId,
        openOnly: clearOpenOnly ? null : (openOnly ?? this.openOnly),
        from: from ?? this.from,
        to: to ?? this.to,
        page: page ?? 1,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  @override
  bool operator ==(Object other) =>
      other is PurchaseQuery &&
      other.q == q &&
      other.status == status &&
      other.vendorId == vendorId &&
      other.toolId == toolId &&
      other.openOnly == openOnly &&
      other.from == from &&
      other.to == to &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode =>
      Object.hash(q, status, vendorId, toolId, openOnly, from, to, page, limit, sort, order);
}

final purchaseRepositoryProvider =
    Provider<PurchaseRepository>((ref) => PurchaseRepository(ref.watch(apiClientProvider)));

final purchaseQueryProvider = StateProvider<PurchaseQuery>((ref) => const PurchaseQuery());

final purchaseListProvider = FutureProvider.autoDispose<PagedResult<PurchaseOrder>>(
  (ref) => ref.watch(purchaseRepositoryProvider).list(ref.watch(purchaseQueryProvider)),
);

final purchaseSummaryProvider = FutureProvider.autoDispose<PurchaseSummary>(
  (ref) => ref.watch(purchaseRepositoryProvider).summary(),
);

final purchaseDetailProvider = FutureProvider.autoDispose.family<PurchaseOrder, int>(
  (ref, id) => ref.watch(purchaseRepositoryProvider).byId(id),
);

final reorderSuggestionsProvider = FutureProvider.autoDispose<List<ReorderSuggestion>>(
  (ref) => ref.watch(purchaseRepositoryProvider).reorderSuggestions(),
);
