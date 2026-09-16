import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/calibration.dart';
import '../../../tools/presentation/widgets/tool_detail_sheet.dart';
import '../../data/calibration_repository.dart';

/// The RFQ's "Monthly Calibration Schedule": what Quality has to get through
/// this month, grouped by planned date.
class MonthlyPlanView extends ConsumerWidget {
  const MonthlyPlanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(calibrationMonthProvider);
    final plan = ref.watch(monthlyPlanProvider);

    return SectionCard(
      title: 'Monthly calibration plan',
      subtitle: Fmt.monthKey(month),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _shiftMonth(ref, month, -1),
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            tooltip: 'Previous month',
            visualDensity: VisualDensity.compact,
          ),
          TextButton(
            onPressed: () => ref.read(calibrationMonthProvider.notifier).state = _thisMonth(),
            child: const Text('This month'),
          ),
          IconButton(
            onPressed: () => _shiftMonth(ref, month, 1),
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            tooltip: 'Next month',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      child: AsyncView<MonthlyCalibrationPlan>(
        value: plan,
        onRetry: () => ref.invalidate(monthlyPlanProvider),
        loading: const GridSkeleton(rows: 4),
        data: (data) => data.days.isEmpty
            ? EmptyState(
                icon: Icons.event_available_outlined,
                message: 'Nothing is planned for ${Fmt.monthKey(month)}.\n'
                    'Calibrations are scheduled automatically when the previous one is recorded.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final day in data.days) _dayGroup(context, ref, day),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg, vertical: Insets.md),
                    decoration: const BoxDecoration(
                      color: AppColors.zebra,
                      border: Border(top: BorderSide(color: AppColors.line2)),
                    ),
                    child: Text(
                      '${data.total} instrument(s) planned across ${data.days.length} day(s)',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _dayGroup(BuildContext context, WidgetRef ref, CalibrationDay day) {
    final isPast = day.date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
          color: AppColors.zebra,
          child: Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 14,
                color: isPast ? AppColors.red : AppColors.brand,
              ),
              const SizedBox(width: 7),
              Text(
                Fmt.date(day.date),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isPast ? AppColors.redInk : AppColors.ink,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                Fmt.relativeDays(day.date),
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                '${day.items.length} instrument(s)',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        for (final item in day.items)
          InkWell(
            onTap: () => showToolDetail(context, ref, item.toolId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 11),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line2)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 108, child: MonoText(item.toolCode)),
                  Expanded(
                    child: TwoLineCell(
                      primary: item.toolName,
                      secondary: item.vendorName == null
                          ? item.remarks
                          : 'Laboratory: ${item.vendorName}',
                    ),
                  ),
                  if (item.calibrationStatus != null) ...[
                    StatusChip(item.calibrationStatus, dense: true),
                    const SizedBox(width: Insets.sm),
                  ],
                  StatusChip(
                    item.status,
                    dense: true,
                    palette: item.status == 'COMPLETED' ? StatusPalette.green : StatusPalette.slate,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _thisMonth() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  void _shiftMonth(WidgetRef ref, String current, int delta) {
    final parts = current.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final shifted = DateTime(year, month + delta);
    ref.read(calibrationMonthProvider.notifier).state =
        '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}';
  }
}
