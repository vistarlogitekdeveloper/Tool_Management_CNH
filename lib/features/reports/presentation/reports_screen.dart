import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/charts/bar_chart.dart';
import '../../../core/charts/donut_chart.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../models/dashboard.dart';
import '../../../models/enums.dart';
import '../../../models/report.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/reports_repository.dart';

/// Reports & Analytics — the report catalogue, plus the utilisation and
/// life-cycle charts and the automated-alerts log from the deck.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static const _icons = <String, (IconData, KpiTone)>{
    'inventory': (Icons.inventory_2_outlined, KpiTone.blue),
    'calibration': (Icons.schedule_rounded, KpiTone.amber),
    'issue-return': (Icons.swap_horiz_rounded, KpiTone.green),
    'repair-scrap': (Icons.handyman_outlined, KpiTone.red),
    'low-stock': (Icons.trending_down_rounded, KpiTone.amber),
    'lifecycle': (Icons.timeline_rounded, KpiTone.violet),
    'lost-damaged': (Icons.report_problem_outlined, KpiTone.red),
    'purchase': (Icons.shopping_cart_outlined, KpiTone.blue),
    'utilisation': (Icons.speed_rounded, KpiTone.green),
    'audit': (Icons.fact_check_outlined, KpiTone.slate),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(reportCatalogueProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          breadcrumb: 'Insights / Reports & Analytics',
          title: 'Reports & Analytics',
          subtitle: 'Every report exports to Excel and PDF, with automated alerts alongside',
        ),

        AsyncView<List<ReportDefinition>>(
          value: catalogue,
          onRetry: () => ref.invalidate(reportCatalogueProvider),
          loading: const BlockSkeleton(height: 260),
          data: (reports) => ResponsiveGrid(
            columns: context.cardColumns,
            children: [
              for (final report in reports)
                _ReportTile(
                  report: report,
                  icon: _icons[report.key]?.$1 ?? Icons.assessment_outlined,
                  tone: _icons[report.key]?.$2 ?? KpiTone.slate,
                  onOpen: () => context.go(Routes.report(report.key)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),

        AsyncView<DashboardOverview>(
          value: dashboard,
          showRefreshLine: false,
          loading: const SplitRow(
            leftFlex: 1,
            rightFlex: 1,
            left: BlockSkeleton(height: 260),
            right: BlockSkeleton(height: 260),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SplitRow(
                leftFlex: 1,
                rightFlex: 1,
                left: SectionCard(
                  title: 'Tool utilisation by shop',
                  subtitle: 'Share of each shop\'s fleet currently in use',
                  child: SimpleBarChart(
                    maxValue: 100,
                    valueSuffix: '%',
                    slices: [
                      for (final shop in data.utilisationByShop)
                        ChartSlice(
                          label: shop.shop,
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
                right: const _LifecyclePanel(),
              ),
              const SizedBox(height: Insets.lg),
              const _AlertLogPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.icon,
    required this.tone,
    required this.onOpen,
  });

  final ReportDefinition report;
  final IconData icon;
  final KpiTone tone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colours;

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(Insets.radius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Insets.radius),
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Insets.radius),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.description,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifecyclePanel extends ConsumerWidget {
  const _LifecyclePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportResultProvider(const ReportRequest('lifecycle')));

    return SectionCard(
      title: 'Tool life cycle status',
      subtitle: 'How much of each tool\'s expected life has been consumed',
      trailing: TextButton(
        onPressed: () => context.go(Routes.report('lifecycle')),
        child: const Text('Open report →'),
      ),
      child: AsyncView<ReportResult>(
        value: report,
        showRefreshLine: false,
        onRetry: () => ref.invalidate(reportResultProvider(const ReportRequest('lifecycle'))),
        loading: const SizedBox(height: 170, child: Center(child: CircularProgressIndicator())),
        data: (data) {
          final slices = [
            for (final slice in (data.charts?['lifeStages'] as List? ?? const []))
              ChartSlice.fromJson(Map<String, dynamic>.from(slice as Map)),
          ].where((s) => s.value > 0).toList();

          if (slices.isEmpty) {
            return const EmptyState(
              compact: true,
              icon: Icons.timeline_rounded,
              message: 'No tools have an expected life recorded yet.\n'
                  'Set one on the tool master to track replacement.',
            );
          }

          return context.isMobile
              ? Column(
                  children: [
                    DonutChart(slices: slices, centreLabel: 'TOOLS'),
                    const SizedBox(height: Insets.lg),
                    ChartLegend(slices: slices, showPercent: true),
                  ],
                )
              : Row(
                  children: [
                    DonutChart(slices: slices, centreLabel: 'TOOLS'),
                    const SizedBox(width: 18),
                    Expanded(child: ChartLegend(slices: slices, showPercent: true)),
                  ],
                );
        },
      ),
    );
  }
}

class _AlertLogPanel extends ConsumerWidget {
  const _AlertLogPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsListProvider(null));
    final lowStock = ref.watch(lowStockProvider).valueOrNull;

    return SectionCard(
      title: 'Automated alerts log',
      subtitle: 'Raised by the nightly sweep and by live transactions',
      trailing: TextButton(
        onPressed: () => context.go(Routes.alerts),
        child: const Text('All alerts →'),
      ),
      padding: EdgeInsets.zero,
      child: alerts.when(
        loading: () => const GridSkeleton(rows: 3, showHeader: false),
        error: (error, _) => ErrorPanel(
          error: error,
          compact: true,
          onRetry: () => ref.invalidate(alertsListProvider(null)),
        ),
        data: (paged) => paged.items.isEmpty
            ? EmptyState(
                compact: true,
                icon: Icons.check_circle_outline_rounded,
                message: lowStock == null || lowStock.isEmpty
                    ? 'No alerts are open. Everything is within its thresholds.'
                    : 'No alerts are open right now.',
              )
            : Column(
                children: [
                  for (final alert in paged.items.take(8))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Insets.lg, vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.line2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: StatusStyles.of(alert.severity).background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              switch (alert.type) {
                                'LOW_STOCK' => Icons.trending_down_rounded,
                                'CALIBRATION_DUE' ||
                                'CALIBRATION_OVERDUE' =>
                                  Icons.schedule_rounded,
                                'RETURN_OVERDUE' => Icons.running_with_errors_rounded,
                                'PO_DELAYED' => Icons.local_shipping_outlined,
                                _ => Icons.pending_actions_rounded,
                              },
                              size: 16,
                              color: StatusStyles.of(alert.severity).foreground,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: TwoLineCell(
                              primary: alert.title,
                              secondary: alert.message,
                            ),
                          ),
                          Text(
                            Fmt.ago(alert.raisedAt),
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
}
