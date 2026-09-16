import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/report.dart';

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<List<ReportDefinition>> catalogue() async {
    final data = await _api.get<List<dynamic>>('/reports');
    return data
        .whereType<Map>()
        .map((e) => ReportDefinition.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ReportResult> run(String key, ReportFilters filters) async =>
      ReportResult.fromJson(await _api.get<Json>('/reports/$key', query: filters.toQuery()));

  /// Fetches the rendered .xlsx / .pdf / .csv bytes for saving or sharing.
  Future<DownloadedFile> export(String key, ReportFilters filters, String format) =>
      _api.download('/reports/$key', query: {...filters.toQuery(), 'format': format});

  Future<PagedResult<AuditEntry>> auditLog({
    String? q,
    int? userId,
    String? action,
    String? module,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) =>
      _api.getPaged('/audit',
          query: {
            'q': q,
            'userId': userId,
            'action': action,
            'module': module,
            'from': _d(from),
            'to': _d(to),
            'page': page,
            'limit': limit,
          },
          parse: AuditEntry.fromJson);

  Future<AuditFilters> auditFilters() async =>
      AuditFilters.fromJson(await _api.get<Json>('/audit/filters'));

  Future<List<AuditEntry>> auditForEntity(String entityType, String entityId) async {
    final data = await _api.get<List<dynamic>>('/audit/entity/$entityType/$entityId');
    return data.whereType<Map>().map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static String? _d(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The filter bag every report shares; each report reads the keys it uses.
@immutable
class ReportFilters {
  const ReportFilters({
    this.from,
    this.to,
    this.status,
    this.type,
    this.approvalStatus,
    this.lifeStage,
    this.categoryId,
    this.locationId,
    this.departmentId,
    this.vendorId,
    this.toolId,
    this.userId,
    this.module,
    this.dueBefore,
  });

  final DateTime? from;
  final DateTime? to;
  final String? status;
  final String? type;
  final String? approvalStatus;
  final String? lifeStage;
  final int? categoryId;
  final int? locationId;
  final int? departmentId;
  final int? vendorId;
  final int? toolId;
  final int? userId;
  final String? module;
  final DateTime? dueBefore;

  Map<String, dynamic> toQuery() => {
        if (from != null) 'from': ReportsRepository._d(from),
        if (to != null) 'to': ReportsRepository._d(to),
        if (status != null) 'status': status,
        if (type != null) 'type': type,
        if (approvalStatus != null) 'approvalStatus': approvalStatus,
        if (lifeStage != null) 'lifeStage': lifeStage,
        if (categoryId != null) 'categoryId': categoryId,
        if (locationId != null) 'locationId': locationId,
        if (departmentId != null) 'departmentId': departmentId,
        if (vendorId != null) 'vendorId': vendorId,
        if (toolId != null) 'toolId': toolId,
        if (userId != null) 'userId': userId,
        if (module != null) 'module': module,
        if (dueBefore != null) 'dueBefore': ReportsRepository._d(dueBefore),
      };

  ReportFilters copyWith({
    DateTime? from,
    DateTime? to,
    String? status,
    String? type,
    String? approvalStatus,
    String? lifeStage,
    int? categoryId,
    int? locationId,
    int? departmentId,
    int? vendorId,
    bool clearDates = false,
    bool clearStatus = false,
    bool clearType = false,
    bool clearCategory = false,
  }) =>
      ReportFilters(
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        status: clearStatus ? null : (status ?? this.status),
        type: clearType ? null : (type ?? this.type),
        approvalStatus: approvalStatus ?? this.approvalStatus,
        lifeStage: lifeStage ?? this.lifeStage,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        locationId: locationId ?? this.locationId,
        departmentId: departmentId ?? this.departmentId,
        vendorId: vendorId ?? this.vendorId,
        toolId: toolId,
        userId: userId,
        module: module,
        dueBefore: dueBefore,
      );

  bool get isEmpty => toQuery().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReportFilters &&
      other.from == from &&
      other.to == to &&
      other.status == status &&
      other.type == type &&
      other.approvalStatus == approvalStatus &&
      other.lifeStage == lifeStage &&
      other.categoryId == categoryId &&
      other.locationId == locationId &&
      other.departmentId == departmentId &&
      other.vendorId == vendorId &&
      other.toolId == toolId &&
      other.userId == userId &&
      other.module == module &&
      other.dueBefore == dueBefore;

  @override
  int get hashCode => Object.hash(from, to, status, type, approvalStatus, lifeStage, categoryId,
      locationId, departmentId, vendorId, toolId, userId, module, dueBefore);
}

/// Key + filters, so the provider re-runs when either changes.
@immutable
class ReportRequest {
  const ReportRequest(this.key, [this.filters = const ReportFilters()]);

  final String key;
  final ReportFilters filters;

  @override
  bool operator ==(Object other) =>
      other is ReportRequest && other.key == key && other.filters == filters;

  @override
  int get hashCode => Object.hash(key, filters);
}

final reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(apiClientProvider)));

final reportCatalogueProvider = FutureProvider<List<ReportDefinition>>(
  (ref) => ref.watch(reportsRepositoryProvider).catalogue(),
);

final reportResultProvider = FutureProvider.autoDispose.family<ReportResult, ReportRequest>(
  (ref, request) => ref.watch(reportsRepositoryProvider).run(request.key, request.filters),
);

final auditFiltersProvider = FutureProvider.autoDispose<AuditFilters>(
  (ref) => ref.watch(reportsRepositoryProvider).auditFilters(),
);
