/// Defensive JSON readers.
///
/// The API is ours, but a nullable column, a `numeric` that arrives as a string
/// or an added field should never crash a shop-floor tablet mid-shift. Every
/// model parses through these.
typedef Json = Map<String, dynamic>;

String str(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();

String? strOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}

double? asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().toLowerCase();
  if (s == null) return fallback;
  return s == 'true' || s == '1' || s == 'yes';
}

/// Calendar dates come back as 'YYYY-MM-DD'; timestamps as ISO-8601.
DateTime? asDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.length == 10 ? '${s}T00:00:00' : s);
}

Json asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Json? asMapOrNull(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<T> asList<T>(Object? v, T Function(Json) parse) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList();
}

List<String> asStringList(Object? v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}
