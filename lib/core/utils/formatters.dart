import 'package:intl/intl.dart';

/// Display formatting for the whole app. The plant reads en_IN: lakh/crore
/// grouping for money, `dd MMM yyyy` for dates.
abstract final class Fmt {
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateShort = DateFormat('dd MMM');
  static final _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final _time = DateFormat('HH:mm');
  static final _month = DateFormat('MMMM yyyy');
  static final _weekday = DateFormat('EEEE, dd MMM yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');
  static final _int = NumberFormat.decimalPattern('en_IN');
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _moneyPrecise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String dateShort(DateTime? d) => d == null ? '—' : _dateShort.format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());
  static String time(DateTime? d) => d == null ? '—' : _time.format(d.toLocal());
  static String month(DateTime d) => _month.format(d);
  static String weekday(DateTime d) => _weekday.format(d);
  static String iso(DateTime d) => _iso.format(d);

  static String int_(num? n) => n == null ? '—' : _int.format(n);

  static String money(num? n, {bool precise = false}) {
    if (n == null) return '—';
    return precise ? _moneyPrecise.format(n) : _money.format(n);
  }

  /// Compact money for KPI tiles: ₹1.2L, ₹3.4Cr.
  static String moneyCompact(num? n) {
    if (n == null) return '—';
    final v = n.abs();
    final sign = n < 0 ? '-' : '';
    if (v >= 10000000) return '$sign₹${(v / 10000000).toStringAsFixed(v >= 100000000 ? 0 : 1)}Cr';
    if (v >= 100000) return '$sign₹${(v / 100000).toStringAsFixed(v >= 1000000 ? 0 : 1)}L';
    if (v >= 1000) return '$sign₹${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return '$sign₹${v.toStringAsFixed(0)}';
  }

  static String percent(num? n, {int decimals = 0}) =>
      n == null ? '—' : '${n.toStringAsFixed(decimals)}%';

  static String qty(num? n, [String? uom]) {
    if (n == null) return '—';
    final base = _int.format(n);
    return uom == null || uom.isEmpty || uom == 'NOS' ? base : '$base $uom';
  }

  /// '2 days ago', 'in 3 days', 'today'.
  static String relativeDays(DateTime? target) {
    if (target == null) return '—';
    final today = DateTime.now();
    final diff = DateTime(target.year, target.month, target.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff == -1) return 'yesterday';
    if (diff > 0) return 'in $diff days';
    return '${diff.abs()} days ago';
  }

  /// '12 sec ago', '4 min ago', '2 h ago' — for the "last updated" captions.
  static String ago(DateTime? at) {
    if (at == null) return '—';
    final seconds = DateTime.now().difference(at.toLocal()).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '$seconds sec ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours h ago';
    final days = hours ~/ 24;
    if (days < 30) return '$days d ago';
    return date(at);
  }

  /// 'YYYY-MM' -> 'August 2026'
  static String monthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return key;
    return _month.format(DateTime(y, m));
  }

  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Cell renderer shared by the report grid and any generic table.
  static String cell(Object? value, String type) {
    if (value == null || value.toString().isEmpty) return '—';
    return switch (type) {
      'currency' => money(num.tryParse(value.toString()), precise: true),
      'number' => int_(num.tryParse(value.toString())),
      'date' => date(DateTime.tryParse(value.toString().length == 10
          ? '${value}T00:00:00'
          : value.toString())),
      'datetime' => dateTime(DateTime.tryParse(value.toString())),
      _ => value.toString(),
    };
  }
}
