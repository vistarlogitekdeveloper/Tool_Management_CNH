import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/calibration.dart';
import '../../../models/enums.dart';
import '../../auth/data/auth_controller.dart';
import '../../reports/presentation/widgets/export_menu.dart';
import '../../tools/presentation/widgets/tool_detail_sheet.dart';
import '../data/calibration_repository.dart';
import 'widgets/calibration_dialog.dart';
import 'widgets/monthly_plan_view.dart';

/// Calibration Management — the due list, the monthly schedule, and the
/// certificate trail that makes an audit survivable.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  final _searchController = TextEditingController();
  bool _calendarView = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(calibrationQueryProvider.notifier).update(
              (q) => q.copyWith(status: widget.initialStatus!.toUpperCase()),
            );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final query = ref.watch(calibrationQueryProvider);
    final schedule = ref.watch(calibrationScheduleProvider);
    final summary = ref.watch(calibrationSummaryProvider);
    final canRecord = user?.can(P.calibrationRecord) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Calibration Management',
          title: 'Calibration Management',
          subtitle: 'Schedule, certificates and automated reminders',
          actions: [
            SegmentedFilter<bool>(
              value: _calendarView,
              onChanged: (v) => setState(() => _calendarView = v),
              segments: const [
                (value: false, label: 'Due list', count: null),
                (value: true, label: 'Monthly plan', count: null),
              ],
            ),
            if (user?.can(P.reportsExport) ?? false)
              ExportButton(reportKey: 'calibration', label: 'Cal. Report'),
          ],
        ),

        AsyncView<CalibrationSummary>(
          value: summary,
          showRefreshLine: false,
          loading: const SizedBox(height: 118, child: BlockSkeleton()),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.overdue > 0 || s.neverCalibrated > 0)
                NoticeBar(
                  tone: NoticeTone.danger,
                  icon: Icons.notification_important_outlined,
                  message: '${[
                    if (s.overdue > 0) '${s.overdue} instrument(s) overdue',
                    if (s.neverCalibrated > 0) '${s.neverCalibrated} never calibrated',
                    if (s.dueSoon + s.dueToday > 0) '${s.dueSoon + s.dueToday} due soon',
                  ].join(' · ')}. Overdue instruments are blocked from being issued.',
                ),
              KpiStrip(
                cards: [
                  KpiCard(
                    label: 'Overdue',
                    value: Fmt.int_(s.overdue),
                    icon: Icons.error_outline_rounded,
                    tone: s.overdue > 0 ? KpiTone.red : KpiTone.green,
                    caption: s.overdue > 0 ? 'Blocked from issue' : 'Nothing overdue',
                    captionTone: s.overdue > 0 ? KpiTone.red : KpiTone.green,
                    onTap: () => ref
                        .read(calibrationQueryProvider.notifier)
                        .update((q) => q.copyWith(status: 'OVERDUE')),
                  ),
                  KpiCard(
                    label: 'Due Soon',
                    value: Fmt.int_(s.dueToday + s.dueSoon),
                    icon: Icons.schedule_rounded,
                    tone: KpiTone.amber,
                    caption: '${s.dueToday} due today',
                    onTap: () => ref
                        .read(calibrationQueryProvider.notifier)
                        .update((q) => q.copyWith(status: 'DUE_SOON')),
                  ),
                  KpiCard(
                    label: 'Valid / Scheduled',
                    value: Fmt.int_(s.valid),
                    icon: Icons.verified_outlined,
                    tone: KpiTone.green,
                    caption: '${s.instruments} controlled instruments',
                  ),
                  KpiCard(
                    label: 'Calibrations YTD',
                    value: Fmt.int_(s.ytdCount),
                    icon: Icons.receipt_long_outlined,
                    tone: KpiTone.blue,
                    caption: 'Spend ${Fmt.moneyCompact(s.ytdCost)}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        if (_calendarView)
          const MonthlyPlanView()
        else ...[
          FilterBar(
            controls: [
              SearchField(
                controller: _searchController,
                hintText: 'Search instrument…',
                width: 250,
                onChanged: (value) => ref
                    .read(calibrationQueryProvider.notifier)
                    .update((q) => q.copyWith(q: value)),
              ),
              SegmentedFilter<String?>(
                value: query.status,
                onChanged: (value) => ref.read(calibrationQueryProvider.notifier).update(
                      (q) => value == null ? q.copyWith(clearStatus: true) : q.copyWith(status: value),
                    ),
                segments: [
                  (value: null, label: 'All', count: null),
                  (value: 'OVERDUE', label: 'Overdue', count: summary.valueOrNull?.overdue),
                  (value: 'DUE_SOON', label: 'Due soon', count: summary.valueOrNull?.dueSoon),
                  (value: 'VALID', label: 'Valid', count: null),
                ],
              ),
            ],
            trailing: query.status != null || query.q.isNotEmpty
                ? TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(calibrationQueryProvider.notifier).state = const CalibrationQuery();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                    label: const Text('Clear'),
                  )
                : null,
          ),

          SectionCard(
            padding: EdgeInsets.zero,
            child: AsyncView<PagedResult<CalibrationStatus>>(
              value: schedule,
              onRetry: () => ref.invalidate(calibrationScheduleProvider),
              loading: const GridSkeleton(),
              data: (paged) => Column(
                children: [
                  DataGrid<CalibrationStatus>(
                    rows: paged.items,
                    minWidth: 1140,
                    onRowTap: (row) => showToolDetail(context, ref, row.toolId),
                    emptyMessage: 'No calibration-controlled instruments match your filters.',
                    emptyIcon: Icons.verified_outlined,
                    mobileCardBuilder: (row) => _mobileCard(row, canRecord),
                    columns: _columns(canRecord),
                  ),
                  PaginationBar(
                    meta: paged.meta,
                    unit: 'instruments',
                    onPage: (page) => ref
                        .read(calibrationQueryProvider.notifier)
                        .update((q) => q.copyWith(page: page)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<GridColumn<CalibrationStatus>> _columns(bool canRecord) => [
        GridColumn<CalibrationStatus>(
          label: 'Tool ID',
          width: 106,
          cell: (row) => MonoText(row.toolCode),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Instrument',
          flex: 4,
          cell: (row) => TwoLineCell(primary: row.toolName, secondary: row.locationName),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Last Cal.',
          width: 110,
          hideBelow: ScreenSize.tablet,
          cell: (row) => Text(
            Fmt.date(row.lastCalibrationDate),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Next Due',
          width: 130,
          cell: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.date(row.nextDueDate),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: row.isOverdue ? AppColors.redInk : AppColors.ink,
                ),
              ),
              Text(
                row.dueHint,
                style: TextStyle(
                  fontSize: 10.5,
                  color: row.isOverdue ? AppColors.redInk : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Frequency',
          width: 92,
          numeric: true,
          align: Alignment.centerRight,
          hideBelow: ScreenSize.desktop,
          cell: (row) => Text(
            row.frequencyMonths == null ? '—' : '${row.frequencyMonths} mo',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Certificate',
          flex: 2,
          hideBelow: ScreenSize.desktop,
          cell: (row) => row.certificateNo == null
              ? const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.muted))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 13, color: AppColors.brand),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        row.certificateNo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Laboratory',
          flex: 2,
          hideBelow: ScreenSize.wide,
          cell: (row) => Text(
            row.vendorName ?? '—',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<CalibrationStatus>(
          label: 'Status',
          width: 132,
          cell: (row) => StatusChip(row.status),
        ),
        if (canRecord)
          GridColumn<CalibrationStatus>(
            label: '',
            width: 118,
            align: Alignment.centerRight,
            cell: (row) => OutlinedButton(
              onPressed: () => showCalibrationDialog(context, ref, instrument: row),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                foregroundColor: row.isDue ? AppColors.brand : AppColors.slate,
              ),
              child: const Text('Calibrate'),
            ),
          ),
      ];

  Widget _mobileCard(CalibrationStatus row, bool canRecord) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MonoText(row.toolCode)),
              StatusChip(row.status, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.toolName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Due ${Fmt.date(row.nextDueDate)} · ${row.dueHint}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: row.isOverdue ? AppColors.redInk : AppColors.muted,
                  ),
                ),
              ),
              if (canRecord)
                OutlinedButton(
                  onPressed: () => showCalibrationDialog(context, ref, instrument: row),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Calibrate'),
                ),
            ],
          ),
        ],
      );
}
