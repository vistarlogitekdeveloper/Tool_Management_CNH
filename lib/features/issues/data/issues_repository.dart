import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/issue.dart';
import '../../../models/json.dart';

class IssuesRepository {
  IssuesRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<ToolIssue>> list(IssueQuery query) =>
      _api.getPaged('/issues', query: query.toQuery(), parse: ToolIssue.fromJson);

  Future<ToolIssue> byId(int id) async => ToolIssue.fromJson(await _api.get<Json>('/issues/$id'));

  Future<IssueSummary> summary() async => IssueSummary.fromJson(await _api.get<Json>('/issues/summary'));

  Future<ToolIssue> issue(IssueRequest request) async =>
      ToolIssue.fromJson(await _api.post<Json>('/issues', data: request.toJson()));

  Future<ToolIssue> returnTool(
    int issueId, {
    int? qty,
    DateTime? returnDate,
    String condition = 'GOOD',
    String? remarks,
  }) async =>
      ToolIssue.fromJson(await _api.post<Json>('/issues/$issueId/return', data: {
        if (qty != null) 'qty': qty,
        if (returnDate != null) 'returnDate': _d(returnDate),
        'condition': condition,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
      }));

  Future<ToolIssue> extend(int issueId, {required DateTime dueDate, required String reason}) async =>
      ToolIssue.fromJson(await _api.post<Json>('/issues/$issueId/extend', data: {
        'dueDate': _d(dueDate),
        'reason': reason,
      }));

  Future<List<Reservation>> reservations({String? status, int? toolId}) async {
    final data = await _api.get<List<dynamic>>('/issues/reservations',
        query: {'status': status, 'toolId': toolId});
    return data.whereType<Map>().map((e) => Reservation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Reservation> reserve({
    required int toolId,
    required int employeeId,
    required int qty,
    required DateTime fromDate,
    required DateTime toDate,
    int? locationId,
    String? purpose,
  }) async =>
      Reservation.fromJson(await _api.post<Json>('/issues/reservations', data: {
        'toolId': toolId,
        'employeeId': employeeId,
        'qty': qty,
        'fromDate': _d(fromDate),
        'toDate': _d(toDate),
        if (locationId != null) 'locationId': locationId,
        if (purpose?.isNotEmpty == true) 'purpose': purpose,
      }));

  Future<Reservation> cancelReservation(int id, {String? reason}) async => Reservation.fromJson(
      await _api.post<Json>('/issues/reservations/$id/cancel', data: {'reason': reason}));

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@immutable
class IssueQuery {
  const IssueQuery({
    this.q = '',
    this.status,
    this.toolId,
    this.employeeId,
    this.departmentId,
    this.locationId,
    this.from,
    this.to,
    this.page = 1,
    this.limit = 25,
    this.sort = 'issueDate',
    this.order = 'desc',
  });

  final String q;

  /// null = all; 'OPEN' and 'OVERDUE' are computed server-side.
  final String? status;
  final int? toolId;
  final int? employeeId;
  final int? departmentId;
  final int? locationId;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;
  final String sort;
  final String order;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null) 'status': status,
        if (toolId != null) 'toolId': toolId,
        if (employeeId != null) 'employeeId': employeeId,
        if (departmentId != null) 'departmentId': departmentId,
        if (locationId != null) 'locationId': locationId,
        if (from != null) 'from': IssuesRepository._d(from!),
        if (to != null) 'to': IssuesRepository._d(to!),
        'page': page,
        'limit': limit,
        'sort': sort,
        'order': order,
      };

  IssueQuery copyWith({
    String? q,
    String? status,
    int? toolId,
    int? employeeId,
    int? departmentId,
    int? locationId,
    DateTime? from,
    DateTime? to,
    int? page,
    int? limit,
    String? sort,
    String? order,
    bool clearStatus = false,
    bool clearDepartment = false,
    bool clearDates = false,
  }) =>
      IssueQuery(
        q: q ?? this.q,
        status: clearStatus ? null : (status ?? this.status),
        toolId: toolId ?? this.toolId,
        employeeId: employeeId ?? this.employeeId,
        departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
        locationId: locationId ?? this.locationId,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        page: page ?? 1,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  @override
  bool operator ==(Object other) =>
      other is IssueQuery &&
      other.q == q &&
      other.status == status &&
      other.toolId == toolId &&
      other.employeeId == employeeId &&
      other.departmentId == departmentId &&
      other.locationId == locationId &&
      other.from == from &&
      other.to == to &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort &&
      other.order == order;

  @override
  int get hashCode =>
      Object.hash(q, status, toolId, employeeId, departmentId, locationId, from, to, page, limit, sort, order);
}

final issuesRepositoryProvider =
    Provider<IssuesRepository>((ref) => IssuesRepository(ref.watch(apiClientProvider)));

final issueQueryProvider = StateProvider<IssueQuery>((ref) => const IssueQuery());

final issuesListProvider = FutureProvider.autoDispose<PagedResult<ToolIssue>>(
  (ref) => ref.watch(issuesRepositoryProvider).list(ref.watch(issueQueryProvider)),
);

final issueSummaryProvider = FutureProvider.autoDispose<IssueSummary>(
  (ref) => ref.watch(issuesRepositoryProvider).summary(),
);

final issueDetailProvider = FutureProvider.autoDispose.family<ToolIssue, int>(
  (ref, id) => ref.watch(issuesRepositoryProvider).byId(id),
);

/// Which reservations the Reservations view is showing. Null means every status,
/// so a store keeper can look back at what was fulfilled or cancelled.
final reservationStatusProvider = StateProvider<String?>((ref) => 'ACTIVE');

final reservationsProvider = FutureProvider.autoDispose<List<Reservation>>(
  (ref) => ref.watch(issuesRepositoryProvider).reservations(
        status: ref.watch(reservationStatusProvider),
      ),
);

/// Active reservations only — used by the KPI strip and by the issue dialog to
/// tell the user a tool is partly spoken for.
final activeReservationsProvider = FutureProvider.autoDispose<List<Reservation>>(
  (ref) => ref.watch(issuesRepositoryProvider).reservations(status: 'ACTIVE'),
);
