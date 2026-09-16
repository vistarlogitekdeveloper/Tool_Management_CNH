import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/charts/bar_chart.dart';
import '../../../core/charts/donut_chart.dart';
import '../../../core/charts/spark_area.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/dashboard.dart';
import '../../../models/enums.dart';
import '../../auth/data/auth_controller.dart';
import '../../issues/presentation/widgets/issue_dialog.dart';
import '../data/dashboard_repository.dart';
import 'widgets/activity_list.dart';

/// "Everything the plant lead needs on one screen" — the landing page for every
/// role, with every number computed live.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final overview = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Overview / Dashboard',
          title: 'Plant Tool Dashboard',
          subtitle: 'Live snapshot · ${AppConfig.plantName} · ${Fmt.weekday(DateTime.now())}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(dashboardProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
            if (user?.can(P.issueCreate) ?? false)
              FilledButton.icon(
                onPressed: () => showIssueDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Issue Tool'),
              ),
          ],
        ),
        AsyncView<DashboardOverview>(
          value: overview,
          onRetry: () => ref.invalidate(dashboardProvider),
          loading: const _DashboardSkeleton(),
          data: (data) => _content(context, ref, data),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, DashboardOverview data) {
    final k = data.kpis;
    final user = ref.read(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiStrip(
          cards: [
            KpiCard(
              label: 'Total Tools',
              value: Fmt.int_(k.totalTools),
              icon: Icons.inventory_2_outlined,
              tone: KpiTone.blue,
              caption: '${k.toolTypes} tool types on the master',
              onTap: () => context.go(Routes.tools),
            ),
            KpiCard(
              label: 'Available Now',
              value: Fmt.int_(k.available),
              icon: Icons.check_circle_outline_rounded,
              tone: KpiTone.green,
              caption: '${k.availablePercent}% of the fleet in store',
              onTap: () => context.go(Routes.inventory),
            ),
            KpiCard(
              label: 'Issued / In Use',
              value: Fmt.int_(k.issued),
              icon: Icons.swap_horiz_rounded,
              tone: KpiTone.amber,
              caption: k.overdueReturns > 0
                  ? '${k.overdueReturns} overdue return(s)'
                  : '${k.openIssues} open issue(s)',
              captionTone: k.overdueReturns > 0 ? KpiTone.red : null,
              onTap: () => context.go(Routes.issues),
            ),
            KpiCard(
              label: 'Low Stock Alerts',
              value: Fmt.int_(k.lowStockCount),
              icon: Icons.warning_amber_rounded,
              tone: k.lowStockCount > 0 ? KpiTone.red : KpiTone.green,
              caption: k.lowStockCount > 0 ? 'Reorder needed' : 'All stock healthy',
              captionTone: k.lowStockCount > 0 ? KpiTone.red : KpiTone.green,
              onTap: () => context.go('${Routes.inventory}?low=1'),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),

        // Second KPI row: the numbers a supervisor acts on, not just observes.
        KpiStrip(
          cards: [
            KpiCard(
              label: 'Calibration Due',
              value: Fmt.int_(k.calibrationDueTotal),
              icon: Icons.schedule_rounded,
              tone: k.calibrationOverdue > 0 ? KpiTone.red : KpiTone.amber,
              caption: k.calibrationOverdue > 0
                  ? '${k.calibrationOverdue} already overdue'
                  : 'None overdue',
              captionTone: k.calibrationOverdue > 0 ? KpiTone.red : KpiTone.green,
              onTap: () => context.go(Routes.calibration),
            ),
            KpiCard(
              label: 'In Repair',
              value: Fmt.int_(k.inRepair),
              icon: Icons.handyman_outlined,
              tone: KpiTone.amber,
              caption: k.pendingApprovals > 0
                  ? '${k.pendingApprovals} awaiting approval'
                  : 'No pending approvals',
              captionTone: k.pendingApprovals > 0 ? KpiTone.amber : null,
              onTap: () => context.go(Routes.maintenance),
            ),
            KpiCard(
              label: 'Issued Today',
              value: Fmt.int_(k.issuedToday),
              icon: Icons.today_rounded,
              tone: KpiTone.violet,
              caption: 'Utilisation ${k.utilisationPercent}%',
              onTap: () => context.go(Routes.issues),
            ),
            KpiCard(
              label: 'Inventory Value',
              value: Fmt.moneyCompact(k.inventoryValue),
              icon: Icons.account_balance_wallet_outlined,
              tone: KpiTone.slate,
              caption: '${Fmt.int_(k.scrapped)} scrapped, ${Fmt.int_(k.lost)} lost',
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),

        SplitRow(
          left: SectionCard(
            title: 'Tool Issues — Last 7 Days',
            subtitle: 'Issues raised against returns received',
            trailing: const _TrendLegend(),
            child: SparkAreaChart(points: data.issueTrend),
          ),
          right: SectionCard(
            title: 'Fleet by Status',
            child: context.isMobile
                ? Column(
                    children: [
                      DonutChart(slices: data.fleetByStatus),
                      const SizedBox(height: Insets.lg),
                      ChartLegend(slices: data.fleetByStatus, showPercent: true),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DonutChart(slices: data.fleetByStatus),
                      const SizedBox(width: 18),
                      Expanded(child: ChartLegend(slices: data.fleetByStatus, showPercent: true)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: Insets.lg),

        SplitRow(
          leftFlex: 1,
          rightFlex: 1,
          left: SectionCard(
            title: 'Tools by Category',
            subtitle: 'Total quantity held, by category',
            child: SimpleBarChart(slices: data.byCategory),
          ),
          right: SectionCard(
            title: 'Calibration Due',
            trailing: TextButton(
              onPressed: () => context.go(Routes.calibration),
              child: const Text('View all →'),
            ),
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
            child: data.calibrationDue.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.verified_outlined,
                    message: 'Every instrument is within its calibration window.',
                  )
                : Column(
                    children: [
                      for (final item in data.calibrationDue)
                        _CalibrationRow(
                          item: item,
                          onTap: () => context.go(Routes.calibration),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: Insets.lg),

        SplitRow(
          leftFlex: 1,
          rightFlex: 1,
          left: SectionCard(
            title: 'Recent Tool Activity',
            trailing: (user?.can(P.issueView) ?? false)
                ? TextButton(
                    onPressed: () => context.go(Routes.issues),
                    child: const Text('Issue log →'),
                  )
                : null,
            padding: EdgeInsets.zero,
            child: ActivityList(items: data.recentActivity),
          ),
          right: SectionCard(
            title: 'Low Stock — Reorder',
            trailing: TextButton(
              onPressed: () => context.go('${Routes.inventory}?low=1'),
              child: const Text('Inventory →'),
            ),
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
            child: data.lowStock.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.check_circle_outline_rounded,
                    message: 'All stock healthy — nothing at or below its minimum.',
                  )
                : Column(
                    children: [
                      for (final item in data.lowStock)
                        _LowStockRow(
                          item: item,
                          onTap: () => context.go('${Routes.inventory}?low=1'),
                        ),
                    ],
                  ),
          ),
        ),

        if (data.utilisationByShop.isNotEmpty) ...[
          const SizedBox(height: Insets.lg),
          SectionCard(
            title: 'Utilisation by Shop',
            subtitle: 'Share of each shop\'s fleet currently in use',
            child: HorizontalBarChart(
              maxValue: 100,
              valueFormatter: (v) => '${v.toStringAsFixed(0)}%',
              slices: [
                for (final shop in data.utilisationByShop)
                  ChartSlice(
                    label: '${shop.shop}  ·  ${shop.issuedQty}/${shop.totalQty}',
                    value: shop.utilisationPercent,
                    colour: shop.utilisationPercent >= 75
                        ? AppColors.brand
                        : shop.utilisationPercent >= 50
                            ? AppColors.green
                            : AppColors.amber,
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: Insets.md),
        Center(
          child: Text(
            'Last updated ${Fmt.ago(data.generatedAt)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(AppColors.brand, 'Issued'),
          const SizedBox(width: Insets.md),
          _dot(AppColors.green, 'Returned'),
        ],
      );

  Widget _dot(Color colour, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      );
}

class _CalibrationRow extends StatelessWidget {
  const _CalibrationRow({required this.item, required this.onTap});

  final CalibrationDueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue =
        item.status == 'OVERDUE' || item.status == 'NEVER_CALIBRATED' || item.status == 'FAILED';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line2)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: overdue ? AppColors.redSoft : AppColors.amberSoft,
                borderRadius: BorderRadius.circular(Insets.radiusSm),
              ),
              child: Icon(
                Icons.schedule_rounded,
                size: 17,
                color: overdue ? AppColors.red : AppColors.amber,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: TwoLineCell(
                primary: item.toolName,
                secondary: '${item.toolCode}${item.locationName != null ? ' · ${item.locationName}' : ''}',
              ),
            ),
            const SizedBox(width: Insets.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusChip(item.status, dense: true),
                const SizedBox(height: 3),
                Text(
                  Fmt.date(item.nextDueDate),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item, required this.onTap});

  final LowStockPreview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line2)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(Insets.radiusSm),
                ),
                child: const Icon(Icons.trending_down_rounded, size: 17, color: AppColors.red),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TwoLineCell(
                  primary: item.name,
                  secondary: '${item.toolCode} · minimum ${item.minStock}',
                ),
              ),
              const SizedBox(width: Insets.sm),
              SizedBox(
                width: 116,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LevelBar(percent: item.stockPercent, colour: AppColors.red),
                    const SizedBox(height: 4),
                    Text(
                      '${item.available}/${item.total} in stock',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ResponsiveGrid(
            columns: context.kpiColumns,
            children: const [
              BlockSkeleton(height: 118),
              BlockSkeleton(height: 118),
              BlockSkeleton(height: 118),
              BlockSkeleton(height: 118),
            ],
          ),
          const SizedBox(height: Insets.lg),
          const SplitRow(
            left: BlockSkeleton(height: 260),
            right: BlockSkeleton(height: 260),
          ),
          const SizedBox(height: Insets.lg),
          const SplitRow(
            leftFlex: 1,
            rightFlex: 1,
            left: BlockSkeleton(height: 240),
            right: BlockSkeleton(height: 240),
          ),
        ],
      );
}
