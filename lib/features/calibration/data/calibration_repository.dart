import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/calibration.dart';
import '../../../models/json.dart';

class CalibrationRepository {
  CalibrationRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<CalibrationStatus>> schedule(CalibrationQuery query) =>
      _api.getPaged('/calibration', query: query.toQuery(), parse: CalibrationStatus.fromJson);

  Future<CalibrationSummary> summary() async =>
      CalibrationSummary.fromJson(await _api.get<Json>('/calibration/summary'));

  Future<List<CalibrationStatus>> due({int? days}) async {
    final data = await _api.get<List<dynamic>>('/calibration/due', query: {'days': days});
    return data
        .whereType<Map>()
        .map((e) => CalibrationStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MonthlyCalibrationPlan> monthlyPlan(String month) async =>
      MonthlyCalibrationPlan.fromJson(await _api.get<Json>('/calibration/plan/$month'));

  Future<List<CalibrationRecord>> historyForTool(int toolId) async {
    final data = await _api.get<List<dynamic>>('/calibration/tool/$toolId');
    return data
        .whereType<Map>()
        .map((e) => CalibrationRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CalibrationRecord> record({
    required int toolId,
    DateTime? calibrationDate,
    DateTime? nextDueDate,
    int? frequencyMonths,
    String? certificateNo,
    String? certificateAttachmentId,
    int? vendorId,
    double? cost,
    String result = 'PASS',
    String? performedBy,
    String? remarks,
  }) async =>
      CalibrationRecord.fromJson(await _api.post<Json>('/calibration', data: {
        'toolId': toolId,
        if (calibrationDate != null) 'calibrationDate': _d(calibrationDate),
        if (nextDueDate != null) 'nextDueDate': _d(nextDueDate),
        if (frequencyMonths != null) 'frequencyMonths': frequencyMonths,
        if (certificateNo?.isNotEmpty == true) 'certificateNo': certificateNo,
        if (certificateAttachmentId != null) 'certificateAttachmentId': certificateAttachmentId,
        if (vendorId != null) 'vendorId': vendorId,
        if (cost != null) 'cost': cost,
        'result': result,
        if (performedBy?.isNotEmpty == true) 'performedBy': performedBy,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<Json> plan({
    required int toolId,
    required DateTime plannedDate,
    int? vendorId,
    String? remarks,
  }) =>
      _api.post<Json>('/calibration/plan', data: {
        'toolId': toolId,
        'plannedDate': _d(plannedDate),
        if (vendorId != null) 'vendorId': vendorId,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      });

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@immutable
class CalibrationQuery {
  const CalibrationQuery({
    this.q = '',
    this.status,
    this.month,
    this.page = 1,
    this.limit = 25,
    this.sort = 'nextDue',
    this.order = 'asc',
  });

  final String q;
  final String? status;

  /// 'YYYY-MM' — the RFQ's monthly calibration schedule filter.
  final String? month;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null) 'status': status,
        if (month != null) 'month': month,
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  CalibrationQuery copyWith({
    String? q,
    String? status,
    String? month,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearStatus = false,
    bool clearMonth = false,
  }) =>
      CalibrationQuery(
        q: q ?? this.q,
        status: clearStatus ? null : (status ?? this.status),
        month: clearMonth ? null : (month ?? this.month),
        page: page ?? 1,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  @override
  bool operator ==(Object other) =>
      other is CalibrationQuery &&
      other.q == q &&
      other.status == status &&
      other.month == month &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode => Object.hash(q, status, month, page, limit, sort, order);
}

final calibrationRepositoryProvider =
    Provider<CalibrationRepository>((ref) => CalibrationRepository(ref.watch(apiClientProvider)));

final calibrationQueryProvider = StateProvider<CalibrationQuery>((ref) => const CalibrationQuery());

final calibrationScheduleProvider = FutureProvider.autoDispose<PagedResult<CalibrationStatus>>(
  (ref) => ref.watch(calibrationRepositoryProvider).schedule(ref.watch(calibrationQueryProvider)),
);

final calibrationSummaryProvider = FutureProvider.autoDispose<CalibrationSummary>(
  (ref) => ref.watch(calibrationRepositoryProvider).summary(),
);

/// The month shown on the calendar view, as 'YYYY-MM'.
final calibrationMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
});

final monthlyPlanProvider = FutureProvider.autoDispose<MonthlyCalibrationPlan>(
  (ref) => ref.watch(calibrationRepositoryProvider).monthlyPlan(ref.watch(calibrationMonthProvider)),
);

final toolCalibrationHistoryProvider =
    FutureProvider.autoDispose.family<List<CalibrationRecord>, int>(
  (ref, toolId) => ref.watch(calibrationRepositoryProvider).historyForTool(toolId),
);
