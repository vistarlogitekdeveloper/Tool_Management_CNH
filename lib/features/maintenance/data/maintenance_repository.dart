import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/maintenance.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<MaintenanceRecord>> list(MaintenanceQuery query) =>
      _api.getPaged('/maintenance', query: query.toQuery(), parse: MaintenanceRecord.fromJson);

  Future<MaintenanceRecord> byId(int id) async =>
      MaintenanceRecord.fromJson(await _api.get<Json>('/maintenance/$id'));

  Future<MaintenanceSummary> summary() async =>
      MaintenanceSummary.fromJson(await _api.get<Json>('/maintenance/summary'));

  Future<MaintenanceCostAnalysis> costAnalysis({DateTime? from, DateTime? to}) async =>
      MaintenanceCostAnalysis.fromJson(await _api.get<Json>('/maintenance/cost-analysis', query: {
        'from': from == null ? null : _d(from),
        'to': to == null ? null : _d(to),
      }));

  Future<MaintenanceRecord> create({
    required int toolId,
    required String type,
    required int qty,
    required String reason,
    DateTime? recordDate,
    int? vendorId,
    double? cost,
    int? reportedByEmployeeId,
    DateTime? expectedReturnDate,
    String? attachmentId,
    String? remarks,
  }) async =>
      MaintenanceRecord.fromJson(await _api.post<Json>('/maintenance', data: {
        'toolId': toolId,
        'type': type,
        'qty': qty,
        'reason': reason,
        if (recordDate != null) 'recordDate': _d(recordDate),
        if (vendorId != null) 'vendorId': vendorId,
        if (cost != null) 'cost': cost,
        if (reportedByEmployeeId != null) 'reportedByEmployeeId': reportedByEmployeeId,
        if (expectedReturnDate != null) 'expectedReturnDate': _d(expectedReturnDate),
        if (attachmentId != null) 'attachmentId': attachmentId,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<MaintenanceRecord> decide(int id, {required bool approve, String? remarks}) async =>
      MaintenanceRecord.fromJson(await _api.post<Json>('/maintenance/$id/decision', data: {
        'decision': approve ? 'APPROVE' : 'REJECT',
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<MaintenanceRecord> complete(
    int id, {
    String completionStatus = 'REPAIRED',
    DateTime? completedDate,
    double? finalCost,
    String? remarks,
  }) async =>
      MaintenanceRecord.fromJson(await _api.post<Json>('/maintenance/$id/complete', data: {
        'completionStatus': completionStatus,
        if (completedDate != null) 'completedDate': _d(completedDate),
        if (finalCost != null) 'finalCost': finalCost,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@immutable
class MaintenanceQuery {
  const MaintenanceQuery({
    this.q = '',
    this.type,
    this.approvalStatus,
    this.toolId,
    this.vendorId,
    this.openOnly,
    this.from,
    this.to,
    this.page = 1,
    this.limit = 25,
    this.sort = 'date',
    this.order = 'desc',
  });

  final String q;
  final String? type;
  final String? approvalStatus;
  final int? toolId;
  final int? vendorId;
  final bool? openOnly;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (type != null) 'type': type,
        if (approvalStatus != null) 'approvalStatus': approvalStatus,
        if (toolId != null) 'toolId': toolId,
        if (vendorId != null) 'vendorId': vendorId,
        if (openOnly == true) 'openOnly': true,
        if (from != null) 'from': MaintenanceRepository._d(from!),
        if (to != null) 'to': MaintenanceRepository._d(to!),
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  MaintenanceQuery copyWith({
    String? q,
    String? type,
    String? approvalStatus,
    int? toolId,
    int? vendorId,
    bool? openOnly,
    DateTime? from,
    DateTime? to,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearType = false,
    bool clearApproval = false,
    bool clearOpenOnly = false,
  }) =>
      MaintenanceQuery(
        q: q ?? this.q,
        type: clearType ? null : (type ?? this.type),
        approvalStatus: clearApproval ? null : (approvalStatus ?? this.approvalStatus),
        toolId: toolId ?? this.toolId,
        vendorId: vendorId ?? this.vendorId,
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
      other is MaintenanceQuery &&
      other.q == q &&
      other.type == type &&
      other.approvalStatus == approvalStatus &&
      other.toolId == toolId &&
      other.vendorId == vendorId &&
      other.openOnly == openOnly &&
      other.from == from &&
      other.to == to &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode =>
      Object.hash(q, type, approvalStatus, toolId, vendorId, openOnly, from, to, page, limit, sort, order);
}

final maintenanceRepositoryProvider =
    Provider<MaintenanceRepository>((ref) => MaintenanceRepository(ref.watch(apiClientProvider)));

final maintenanceQueryProvider = StateProvider<MaintenanceQuery>((ref) => const MaintenanceQuery());

final maintenanceListProvider = FutureProvider.autoDispose<PagedResult<MaintenanceRecord>>(
  (ref) => ref.watch(maintenanceRepositoryProvider).list(ref.watch(maintenanceQueryProvider)),
);

final maintenanceSummaryProvider = FutureProvider.autoDispose<MaintenanceSummary>(
  (ref) => ref.watch(maintenanceRepositoryProvider).summary(),
);

final maintenanceCostProvider = FutureProvider.autoDispose<MaintenanceCostAnalysis>(
  (ref) => ref.watch(maintenanceRepositoryProvider).costAnalysis(),
);
