import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/alert.dart';
import '../../../models/enums.dart';
import '../data/alerts_repository.dart';

/// Every open alert in one place: low stock, calibration, overdue returns,
/// pending approvals and delayed purchases.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsListProvider(_status));
    final summary = ref.watch(alertSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Insights / Alerts',
          title: 'Automated Alerts',
          subtitle: 'The system raises the flag before someone has to ask',
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final result = await runWithProgress(
                  context,
                  () => ref.read(alertsRepositoryProvider).sweep(),
                );
                if (result != null) {
                  ref
                    ..invalidate(alertsListProvider)
                    ..invalidate(alertSummaryProvider)
                    ..invalidate(notificationFeedProvider);
                  final totals = result['totals'];
                  if (context.mounted && totals is Map) {
                    context.toast(
                      'Alert sweep complete — ${totals['raised']} raised, '
                      '${totals['resolved']} auto-resolved',
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Re-evaluate now'),
            ),
          ],
        ),

        AsyncView<AlertSummary>(
          value: summary,
          showRefreshLine: false,
          loading: const SizedBox(height: 118, child: BlockSkeleton()),
          data: (s) => KpiStrip(
            cards: [
              KpiCard(
                label: 'Open Alerts',
                value: Fmt.int_(s.open),
                icon: Icons.notifications_active_outlined,
                tone: s.open > 0 ? KpiTone.red : KpiTone.green,
                caption: '${s.critical} critical',
                captionTone: s.critical > 0 ? KpiTone.red : null,
              ),
              KpiCard(
                label: 'Low Stock',
                value: Fmt.int_(s.lowStock),
                icon: Icons.trending_down_rounded,
                tone: s.lowStock > 0 ? KpiTone.amber : KpiTone.green,
                caption: 'Reorder suggested',
                onTap: () => context.go('/inventory?low=1'),
              ),
              KpiCard(
                label: 'Calibration',
                value: Fmt.int_(s.calibration),
                icon: Icons.schedule_rounded,
                tone: s.calibration > 0 ? KpiTone.amber : KpiTone.green,
                caption: 'Due or overdue',
                onTap: () => context.go('/calibration'),
              ),
              KpiCard(
                label: 'Overdue Returns',
                value: Fmt.int_(s.overdueReturns),
                icon: Icons.running_with_errors_rounded,
                tone: s.overdueReturns > 0 ? KpiTone.red : KpiTone.green,
                caption: 'Flagged to supervisors',
                onTap: () => context.go('/issues?status=OVERDUE'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        FilterBar(
          controls: [
            SegmentedFilter<String?>(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
              segments: [
                (value: null, label: 'Active', count: summary.valueOrNull?.total),
                (value: 'OPEN', label: 'Open', count: summary.valueOrNull?.open),
                (
                  value: 'ACKNOWLEDGED',
                  label: 'Acknowledged',
                  count: summary.valueOrNull?.acknowledged
                ),
                (value: 'RESOLVED', label: 'Resolved', count: null),
              ],
            ),
          ],
        ),

        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<AlertItem>>(
            value: alerts,
            onRetry: () => ref.invalidate(alertsListProvider(_status)),
            loading: const GridSkeleton(),
            data: (paged) => DataGrid<AlertItem>(
              rows: paged.items,
              minWidth: 900,
              emptyMessage: _status == 'RESOLVED'
                  ? 'No alerts have been resolved yet.'
                  : 'Nothing needs attention. Every threshold is being met.',
              emptyIcon: Icons.check_circle_outline_rounded,
              onRowTap: (row) {
                final link = row.deepLink;
                if (link != null) context.go(link);
              },
              mobileCardBuilder: _mobileCard,
              columns: [
                GridColumn<AlertItem>(
                  label: 'Severity',
                  width: 112,
                  cell: (row) => StatusChip(row.severity, dense: true),
                ),
                GridColumn<AlertItem>(
                  label: 'Alert',
                  flex: 5,
                  cell: (row) => TwoLineCell(primary: row.title, secondary: row.message),
                ),
                GridColumn<AlertItem>(
                  label: 'Type',
                  width: 168,
                  cell: (row) => Text(
                    StatusStyles.label(row.type),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ),
                GridColumn<AlertItem>(
                  label: 'Raised',
                  width: 122,
                  cell: (row) => Text(
                    Fmt.ago(row.raisedAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                GridColumn<AlertItem>(
                  label: 'Status',
                  width: 132,
                  cell: (row) => StatusChip(row.status),
                ),
                GridColumn<AlertItem>(
                  label: '',
                  width: 138,
                  align: Alignment.centerRight,
                  cell: (row) => row.isOpen
                      ? OutlinedButton(
                          onPressed: () async {
                            await ref.read(alertsRepositoryProvider).acknowledge(row.id);
                            ref
                              ..invalidate(alertsListProvider)
                              ..invalidate(alertSummaryProvider);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            minimumSize: Size.zero,
                            textStyle:
                                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Acknowledge'),
                        )
                      : Text(
                          row.acknowledgedByName ?? '',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileCard(AlertItem row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StatusChip(row.severity, dense: true),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  StatusStyles.label(row.type),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
              Text(
                Fmt.ago(row.raisedAt),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(row.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (row.message != null) ...[
            const SizedBox(height: 2),
            Text(
              row.message!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
            ),
          ],
        ],
      );
}
