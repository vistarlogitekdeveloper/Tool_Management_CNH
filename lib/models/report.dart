import 'json.dart';

/// A report in the catalogue, as shown on the Reports landing tiles.
class ReportDefinition {
  const ReportDefinition({
    required this.key,
    required this.title,
    required this.description,
    this.formats = const ['json', 'xlsx', 'pdf', 'csv'],
  });

  final String key;
  final String title;
  final String description;
  final List<String> formats;

  factory ReportDefinition.fromJson(Json j) => ReportDefinition(
        key: str(j['key']),
        title: str(j['title']),
        description: str(j['description']),
        formats: asStringList(j['formats']),
      );
}

/// Column descriptor — the same one the Excel and PDF writers use, so the
/// on-screen grid and the exported file always agree.
class ReportColumn {
  const ReportColumn({
    required this.key,
    required this.label,
    this.type = 'text',
    this.width = 16,
    this.align,
  });

  final String key;
  final String label;
  final String type;
  final double width;
  final String? align;

  bool get isNumeric => type == 'number' || type == 'currency';
  bool get isStatus => type == 'status';
  bool get isDate => type == 'date' || type == 'datetime';

  factory ReportColumn.fromJson(Json j) => ReportColumn(
        key: str(j['key']),
        label: str(j['label']),
        type: str(j['type'], 'text'),
        width: asDouble(j['width'], 16),
        align: strOrNull(j['align']),
      );
}

/// A generated report: definition, rows and totals.
class ReportResult {
  const ReportResult({
    required this.key,
    required this.title,
    this.subtitle,
    this.generatedAt,
    this.generatedOn,
    this.columns = const [],
    this.rows = const [],
    this.rowCount = 0,
    this.totals = const {},
    this.filters = const {},
    this.charts,
  });

  final String key;
  final String title;
  final String? subtitle;
  final DateTime? generatedAt;
  final String? generatedOn;
  final List<ReportColumn> columns;
  final List<Json> rows;
  final int rowCount;
  final Json totals;
  final Json filters;
  final Json? charts;

  factory ReportResult.fromJson(Json j) => ReportResult(
        key: str(j['key']),
        title: str(j['title']),
        subtitle: strOrNull(j['subtitle']),
        generatedAt: asDate(j['generatedAt']),
        generatedOn: strOrNull(j['generatedOn']),
        columns: asList(j['columns'], ReportColumn.fromJson),
        rows: (j['rows'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        rowCount: asInt(j['rowCount']),
        totals: asMap(j['totals']),
        filters: asMap(j['filters']),
        charts: asMapOrNull(j['charts']),
      );

  /// Named counts the backend attaches under `totals._counts`.
  Json get counts => asMap(totals['_counts']);

  /// Numeric totals, excluding the internal `_counts` key.
  Map<String, num> get numericTotals {
    final out = <String, num>{};
    totals.forEach((k, v) {
      if (k.startsWith('_')) return;
      final n = asDoubleOrNull(v);
      if (n != null) out[k] = n;
    });
    return out;
  }

  bool get isEmpty => rows.isEmpty;
}

/// One row in the audit-trail viewer.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    this.userId,
    this.username,
    this.roleCode,
    this.module,
    this.entityType,
    this.entityId,
    this.summary,
    this.ipAddress,
    this.at,
    this.before,
    this.after,
  });

  final int id;
  final int? userId;
  final String? username;
  final String? roleCode;
  final String action;
  final String? module;
  final String? entityType;
  final String? entityId;
  final String? summary;
  final String? ipAddress;
  final DateTime? at;
  final Json? before;
  final Json? after;

  factory AuditEntry.fromJson(Json j) => AuditEntry(
        id: asInt(j['id']),
        userId: asIntOrNull(j['userId']),
        username: strOrNull(j['username']),
        roleCode: strOrNull(j['roleCode']),
        action: str(j['action']),
        module: strOrNull(j['module']),
        entityType: strOrNull(j['entityType']),
        entityId: strOrNull(j['entityId']),
        summary: strOrNull(j['summary']),
        ipAddress: strOrNull(j['ipAddress']),
        at: asDate(j['at']),
        before: asMapOrNull(j['before']),
        after: asMapOrNull(j['after']),
      );
}

class AuditFilters {
  const AuditFilters({
    this.actions = const [],
    this.modules = const [],
    this.entityTypes = const [],
    this.users = const [],
  });

  final List<String> actions;
  final List<String> modules;
  final List<String> entityTypes;
  final List<AuditUserRef> users;

  factory AuditFilters.fromJson(Json j) => AuditFilters(
        actions: asStringList(j['actions']),
        modules: asStringList(j['modules']),
        entityTypes: asStringList(j['entityTypes']),
        users: asList(j['users'], AuditUserRef.fromJson),
      );
}

class AuditUserRef {
  const AuditUserRef({required this.id, required this.username, this.fullName});

  final int id;
  final String username;
  final String? fullName;

  factory AuditUserRef.fromJson(Json j) => AuditUserRef(
        id: asInt(j['id']),
        username: str(j['username']),
        fullName: strOrNull(j['fullName']),
      );

  String get label => fullName ?? username;
}
