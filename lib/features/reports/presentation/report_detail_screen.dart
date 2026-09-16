import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/enums.dart';
import '../../../models/json.dart';
import '../../../models/report.dart';
import '../../auth/data/auth_controller.dart';
import '../../shell/data/masters_repository.dart';
import '../data/reports_repository.dart';
import 'widgets/export_menu.dart';

/// A generated report: filter bar, totals band, and a grid driven entirely by
/// the column descriptor the server returns — the same descriptor the Excel and
/// PDF writers use, so what you see is what you export.
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.reportKey});

  final String reportKey;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  ReportFilters _filters = const ReportFilters();

  /// Reports that read a date range; the rest ignore from/to.
  static const _dateRangeReports = {
    'issue-return', 'repair-scrap', 'lost-damaged', 'purchase', 'utilisation', 'audit',
  };

  @override
  Widget build(BuildContext context) {
    final request = ReportRequest(widget.reportKey, _filters);
    final report = ref.watch(reportResultProvider(request));
    final canExport = ref.watch(canProvider(P.reportsExport));
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Insights / Reports',
          title: report.valueOrNull?.title ?? 'Report',
          subtitle: report.valueOrNull?.subtitle,
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.reports),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('All reports'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(reportResultProvider(request)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
            if (canExport)
              ExportButton(
                reportKey: widget.reportKey,
                label: 'Export',
                filters: _filters,
                filled: true,
              ),
          ],
        ),

        FilterBar(
          controls: [
            if (_dateRangeReports.contains(widget.reportKey)) ...[
              SizedBox(
                width: 180,
                child: DateField(
                  value: _filters.from,
                  hintText: 'From date',
                  clearable: true,
                  onChanged: (d) => setState(() => _filters = _filters.copyWith(from: d)),
                ),
              ),
              SizedBox(
                width: 180,
                child: DateField(
                  value: _filters.to,
                  hintText: 'To date',
                  clearable: true,
                  firstDate: _filters.from,
                  onChanged: (d) => setState(() => _filters = _filters.copyWith(to: d)),
                ),
              ),
            ],
            if (widget.reportKey == 'inventory' && masters != null)
              FilterDropdown<int?>(
                value: _filters.categoryId,
                hint: 'All categories',
                onChanged: (v) => setState(
                  () => _filters = v == null
                      ? _filters.copyWith(clearCategory: true)
                      : _filters.copyWith(categoryId: v),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                  for (final c in masters.categories)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
              ),
            if (widget.reportKey == 'calibration')
              FilterDropdown<String?>(
                value: _filters.status,
                hint: 'All statuses',
                onChanged: (v) => setState(
                  () => _filters =
                      v == null ? _filters.copyWith(clearStatus: true) : _filters.copyWith(status: v),
                ),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
                  DropdownMenuItem<String?>(value: 'OVERDUE', child: Text('Overdue')),
                  DropdownMenuItem<String?>(value: 'DUE_SOON', child: Text('Due soon')),
                  DropdownMenuItem<String?>(value: 'VALID', child: Text('Valid')),
                ],
              ),
            if (widget.reportKey == 'repair-scrap')
              FilterDropdown<String?>(
                value: _filters.type,
                hint: 'All types',
                onChanged: (v) => setState(
                  () => _filters =
                      v == null ? _filters.copyWith(clearType: true) : _filters.copyWith(type: v),
                ),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All types')),
                  DropdownMenuItem<String?>(value: 'REPAIR', child: Text('Repair')),
                  DropdownMenuItem<String?>(value: 'SCRAP', child: Text('Scrap')),
                  DropdownMenuItem<String?>(value: 'DAMAGE', child: Text('Damage')),
                  DropdownMenuItem<String?>(value: 'LOST', child: Text('Lost')),
                ],
              ),
            if (widget.reportKey == 'lifecycle')
              FilterDropdown<String?>(
                value: _filters.lifeStage,
                hint: 'All life stages',
                width: 175,
                onChanged: (v) => setState(() => _filters = _filters.copyWith(lifeStage: v)),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All life stages')),
                  DropdownMenuItem<String?>(value: 'REPLACE_SOON', child: Text('Replace soon')),
                  DropdownMenuItem<String?>(value: 'MID_LIFE', child: Text('Mid-life')),
                  DropdownMenuItem<String?>(value: 'HEALTHY', child: Text('Healthy')),
                ],
              ),
            if (widget.reportKey == 'issue-return' && masters != null)
              FilterDropdown<int?>(
                value: _filters.departmentId,
                hint: 'All departments',
                onChanged: (v) => setState(() => _filters = _filters.copyWith(departmentId: v)),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All departments')),
                  for (final d in masters.departments)
                    DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                ],
              ),
          ],
          trailing: _filters.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: () => setState(() => _filters = const ReportFilters()),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: const Text('Clear filters'),
                ),
        ),

        AsyncView<ReportResult>(
          value: report,
          onRetry: () => ref.invalidate(reportResultProvider(request)),
          loading: const GridSkeleton(rows: 8),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.counts.isNotEmpty) ...[
                _countStrip(data.counts),
                const SizedBox(height: Insets.lg),
              ],
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _grid(data),
                    _footer(data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countStrip(Json counts) => ResponsiveGrid(
        columns: context.kpiColumns,
        children: [
          for (final entry in counts.entries)
            KpiCard(
              label: _humanise(entry.key),
              value: Fmt.int_(asInt(entry.value)),
              icon: Icons.numbers_rounded,
              tone: _toneFor(entry.key),
            ),
        ],
      );

  static KpiTone _toneFor(String key) {
    final k = key.toLowerCase();
    if (k.contains('overdue') || k.contains('pending') || k.contains('replace')) return KpiTone.red;
    if (k.contains('soon') || k.contains('mid')) return KpiTone.amber;
    if (k.contains('healthy') || k.contains('approved')) return KpiTone.green;
    return KpiTone.blue;
  }

  static String _humanise(String key) => key
      .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

  Widget _grid(ReportResult data) {
    // Wide reports get a wider minimum so columns don't crush together; the
    // grid scrolls horizontally beyond that.
    final minWidth = (data.columns.fold<double>(0, (s, c) => s + c.width) * 7.2)
        .clamp(900.0, 2600.0);

    return DataGrid<Json>(
      rows: data.rows,
      minWidth: minWidth,
      rowHeight: 42,
      emptyMessage: 'No records match the selected filters.',
      emptyIcon: Icons.assessment_outlined,
      mobileCardBuilder: (row) => _mobileCard(data, row),
      columns: [
        for (final column in data.columns)
          GridColumn<Json>(
            label: column.label,
            width: column.isStatus ? 128 : null,
            flex: (column.width / 6).round().clamp(1, 6),
            numeric: column.isNumeric,
            align: column.isNumeric ? Alignment.centerRight : Alignment.centerLeft,
            cell: (row) => column.isStatus
                ? StatusChip(row[column.key]?.toString(), dense: true)
                : Text(
                    Fmt.cell(row[column.key], column.type),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: column.isNumeric ? AppColors.ink : AppColors.ink,
                      fontWeight: column.isNumeric ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
          ),
      ],
    );
  }

  /// On a phone the grid becomes a stack of the first few meaningful fields.
  Widget _mobileCard(ReportResult data, Json row) {
    final primary = data.columns.take(2).toList();
    final rest = data.columns.skip(2).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final column in primary)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: column.isStatus
                ? StatusChip(row[column.key]?.toString(), dense: true)
                : Text(
                    Fmt.cell(row[column.key], column.type),
                    style: TextStyle(
                      fontSize: column == primary.first ? 13 : 12.5,
                      fontWeight: column == primary.first ? FontWeight.w700 : FontWeight.w500,
                      color: column == primary.first ? AppColors.ink : AppColors.muted,
                    ),
                  ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: Insets.md,
          runSpacing: 4,
          children: [
            for (final column in rest)
              column.isStatus
                  ? StatusChip(row[column.key]?.toString(), dense: true)
                  : Text(
                      '${column.label}: ${Fmt.cell(row[column.key], column.type)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
          ],
        ),
      ],
    );
  }

  Widget _footer(ReportResult data) {
    final totals = data.numericTotals;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
      decoration: const BoxDecoration(
        color: AppColors.zebra,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        spacing: Insets.xl,
        runSpacing: Insets.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${data.rowCount} row(s) · generated ${data.generatedOn ?? Fmt.date(DateTime.now())}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          for (final entry in totals.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_labelFor(data, entry.key)}: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  _isMoney(data, entry.key)
                      ? Fmt.money(entry.value, precise: true)
                      : Fmt.int_(entry.value),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _labelFor(ReportResult data, String key) {
    for (final column in data.columns) {
      if (column.key == key) return column.label;
    }
    return _humanise(key);
  }

  bool _isMoney(ReportResult data, String key) {
    for (final column in data.columns) {
      if (column.key == key) return column.type == 'currency';
    }
    return false;
  }
}
