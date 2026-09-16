import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/charts/bar_chart.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/dashboard.dart';
import '../../../models/enums.dart';
import '../../../models/maintenance.dart';
import '../../auth/data/auth_controller.dart';
import '../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../reports/presentation/widgets/export_menu.dart';
import '../../tools/presentation/widgets/tool_detail_sheet.dart';
import '../data/maintenance_repository.dart';
import 'widgets/maintenance_dialog.dart';

/// Repair & Scrap Management — vendor, cost, reason and the approval workflow,
/// plus the damaged and lost registers the RFQ asks for.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key, this.initialApproval});

  final String? initialApproval;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  final _searchController = TextEditingController();
  bool _showCostAnalysis = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialApproval != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(maintenanceQueryProvider.notifier).update(
              (q) => q.copyWith(approvalStatus: widget.initialApproval!.toUpperCase()),
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
    final query = ref.watch(maintenanceQueryProvider);
    final list = ref.watch(maintenanceListProvider);
    final summary = ref.watch(maintenanceSummaryProvider);
    final canApprove = user?.can(P.maintenanceApprove) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Repair & Scrap',
          title: 'Repair & Scrap Management',
          subtitle: 'Vendor, cost, scrap reason and the approval workflow',
          actions: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _showCostAnalysis = !_showCostAnalysis),
              icon: const Icon(Icons.stacked_bar_chart_rounded, size: 16),
              label: Text(_showCostAnalysis ? 'Hide cost analysis' : 'Cost analysis'),
            ),
            if (user?.can(P.reportsExport) ?? false)
              ExportButton(reportKey: 'repair-scrap', label: 'Export'),
            if (user?.can(P.maintenanceCreate) ?? false)
              FilledButton.icon(
                onPressed: () => showMaintenanceDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('New Record'),
              ),
          ],
        ),

        AsyncView<MaintenanceSummary>(
          value: summary,
          showRefreshLine: false,
          loading: const SizedBox(height: 118, child: BlockSkeleton()),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.pendingApprovals > 0 && canApprove)
                NoticeBar(
                  tone: NoticeTone.warning,
                  icon: Icons.pending_actions_rounded,
                  message: '${s.pendingApprovals} record(s) waiting for your approval. '
                      'The stock is already held out of circulation.',
                  action: TextButton(
                    onPressed: () => ref
                        .read(maintenanceQueryProvider.notifier)
                        .update((q) => q.copyWith(approvalStatus: 'PENDING')),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Review now →',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF8A5E0E)),
                    ),
                  ),
                ),
              KpiStrip(
                cards: [
                  KpiCard(
                    label: 'In Repair',
                    value: Fmt.int_(s.inRepairQty),
                    icon: Icons.build_outlined,
                    tone: KpiTone.amber,
                    caption: '${s.openRepairs} repair(s) still open',
                  ),
                  KpiCard(
                    label: 'Scrapped',
                    value: Fmt.int_(s.scrappedQty),
                    icon: Icons.delete_outline_rounded,
                    tone: KpiTone.red,
                    caption: '${s.damagedQty} damaged, ${s.lostQty} lost',
                  ),
                  KpiCard(
                    label: 'Pending Approval',
                    value: Fmt.int_(s.pendingApprovals),
                    icon: Icons.pending_actions_rounded,
                    tone: s.pendingApprovals > 0 ? KpiTone.amber : KpiTone.green,
                    caption: s.pendingApprovals > 0 ? 'Awaiting a decision' : 'Nothing pending',
                    captionTone: s.pendingApprovals > 0 ? KpiTone.amber : KpiTone.green,
                  ),
                  KpiCard(
                    label: 'Repair Cost (MTD)',
                    value: Fmt.moneyCompact(s.repairCostMtd),
                    icon: Icons.currency_rupee_rounded,
                    tone: KpiTone.blue,
                    caption: 'YTD ${Fmt.moneyCompact(s.repairCostYtd)}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        if (_showCostAnalysis) ...[
          _costAnalysis(),
          const SizedBox(height: Insets.lg),
        ],

        FilterBar(
          controls: [
            SearchField(
              controller: _searchController,
              hintText: 'Record no, tool or reason…',
              width: 250,
              onChanged: (value) => ref
                  .read(maintenanceQueryProvider.notifier)
                  .update((q) => q.copyWith(q: value)),
            ),
            SegmentedFilter<String?>(
              value: query.type,
              onChanged: (value) => ref.read(maintenanceQueryProvider.notifier).update(
                    (q) => value == null ? q.copyWith(clearType: true) : q.copyWith(type: value),
                  ),
              segments: const [
                (value: null, label: 'All', count: null),
                (value: 'REPAIR', label: 'Repair', count: null),
                (value: 'SCRAP', label: 'Scrap', count: null),
                (value: 'DAMAGE', label: 'Damaged', count: null),
                (value: 'LOST', label: 'Lost', count: null),
              ],
            ),
            FilterDropdown<String?>(
              value: query.approvalStatus,
              hint: 'All approvals',
              width: 165,
              onChanged: (value) => ref.read(maintenanceQueryProvider.notifier).update(
                    (q) => value == null
                        ? q.copyWith(clearApproval: true)
                        : q.copyWith(approvalStatus: value),
                  ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All approvals')),
                DropdownMenuItem<String?>(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem<String?>(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem<String?>(value: 'REJECTED', child: Text('Rejected')),
              ],
            ),
          ],
        ),

        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<MaintenanceRecord>>(
            value: list,
            onRetry: () => ref.invalidate(maintenanceListProvider),
            loading: const GridSkeleton(),
            data: (paged) => Column(
              children: [
                DataGrid<MaintenanceRecord>(
                  rows: paged.items,
                  minWidth: 1240,
                  onRowTap: (row) => showToolDetail(context, ref, row.tool.id),
                  emptyMessage: 'No maintenance records match your filters.',
                  emptyIcon: Icons.handyman_outlined,
                  mobileCardBuilder: (row) => _mobileCard(row, canApprove),
                  columns: _columns(canApprove),
                ),
                PaginationBar(
                  meta: paged.meta,
                  unit: 'records',
                  onPage: (page) => ref
                      .read(maintenanceQueryProvider.notifier)
                      .update((q) => q.copyWith(page: page)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _costAnalysis() {
    final analysis = ref.watch(maintenanceCostProvider);

    return AsyncView<MaintenanceCostAnalysis>(
      value: analysis,
      onRetry: () => ref.invalidate(maintenanceCostProvider),
      loading: const BlockSkeleton(height: 240),
      data: (data) => SplitRow(
        leftFlex: 1,
        rightFlex: 1,
        left: SectionCard(
          title: 'Repair spend by vendor',
          subtitle: 'Approved repairs only',
          child: HorizontalBarChart(
            showRank: true,
            valueFormatter: Fmt.moneyCompact,
            slices: [
              for (final v in data.byVendor.take(6))
                ChartSlice(
                  label: '${v.vendorName}  ·  ${v.recordCount} job(s)',
                  value: v.totalCost,
                  colour: AppColors.amber,
                ),
            ],
          ),
        ),
        right: SectionCard(
          title: 'Most expensive tools to maintain',
          subtitle: 'Repair, scrap, damage and loss combined',
          child: HorizontalBarChart(
            showRank: true,
            valueFormatter: Fmt.moneyCompact,
            slices: [
              for (final t in data.topTools.take(6))
                ChartSlice(
                  label: '${t.name}  ·  ${t.toolCode}',
                  value: t.totalCost,
                  colour: AppColors.red,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<GridColumn<MaintenanceRecord>> _columns(bool canApprove) => [
        GridColumn<MaintenanceRecord>(
          label: 'Record No.',
          width: 128,
          sortKey: 'recordNo',
          cell: (row) => MonoText(row.recordNo, size: 12),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Type',
          width: 104,
          sortKey: 'type',
          cell: (row) => StatusChip(row.type, dense: true),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Tool',
          flex: 3,
          sortKey: 'tool',
          cell: (row) => TwoLineCell(primary: row.tool.name, secondary: row.tool.toolCode),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Qty',
          width: 62,
          numeric: true,
          align: Alignment.centerRight,
          cell: (row) => Text(
            '${row.qty}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Date',
          width: 104,
          sortKey: 'date',
          hideBelow: ScreenSize.tablet,
          cell: (row) => Text(
            Fmt.date(row.recordDate),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Vendor',
          flex: 2,
          hideBelow: ScreenSize.desktop,
          cell: (row) => Text(
            row.vendorName ?? '—',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Cost',
          width: 104,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'cost',
          cell: (row) => Text(
            row.cost > 0 ? Fmt.money(row.cost) : '—',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Reason',
          flex: 3,
          hideBelow: ScreenSize.wide,
          cell: (row) => Text(
            row.reason,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<MaintenanceRecord>(
          label: 'Approval',
          width: 116,
          sortKey: 'approval',
          cell: (row) => StatusChip(row.approvalStatus),
        ),
        GridColumn<MaintenanceRecord>(
          label: '',
          width: canApprove ? 176 : 118,
          align: Alignment.centerRight,
          cell: (row) => _actions(row, canApprove),
        ),
      ];

  Widget _actions(MaintenanceRecord row, bool canApprove) {
    if (row.isPending && canApprove) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => _decide(row, approve: false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              minimumSize: Size.zero,
              foregroundColor: AppColors.red,
              side: const BorderSide(color: Color(0xFFF0C4C4)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => _decide(row, approve: true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              backgroundColor: AppColors.green,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Approve'),
          ),
        ],
      );
    }

    if (row.isOpenRepair) {
      return OutlinedButton(
        onPressed: () => _complete(row),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('Close repair'),
      );
    }

    if (row.completionStatus != null) {
      return StatusChip(row.completionStatus, dense: true);
    }
    return const SizedBox.shrink();
  }

  Future<void> _decide(MaintenanceRecord row, {required bool approve}) async {
    final remarksController = TextEditingController();
    final confirmed = await confirm(
      context,
      title: approve ? 'Approve ${row.recordNo}?' : 'Reject ${row.recordNo}?',
      message: approve
          ? '${row.qty} × ${row.tool.toolCode} will stay out of available stock as a '
              '${row.type.toLowerCase()}.'
          : 'Rejecting returns ${row.qty} × ${row.tool.toolCode} to available stock.',
      confirmLabel: approve ? 'Approve' : 'Reject',
      destructive: !approve,
      extra: TextField(
        controller: remarksController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Approval remarks (optional)',
          isDense: true,
        ),
        maxLines: 2,
      ),
    );

    if (!confirmed || !mounted) {
      remarksController.dispose();
      return;
    }

    final result = await runWithProgress(
      context,
      () => ref.read(maintenanceRepositoryProvider).decide(
            row.id,
            approve: approve,
            remarks: remarksController.text.trim(),
          ),
      successMessage: '${row.recordNo} ${approve ? 'approved' : 'rejected'}',
    );
    remarksController.dispose();

    if (result != null) {
      invalidateStockViews(ref);
      ref
        ..invalidate(maintenanceListProvider)
        ..invalidate(maintenanceSummaryProvider)
        ..invalidate(maintenanceCostProvider);
    }
  }

  Future<void> _complete(MaintenanceRecord row) async {
    var outcome = 'REPAIRED';
    final costController = TextEditingController(text: row.cost.toStringAsFixed(0));

    final confirmed = await confirm(
      context,
      title: 'Close ${row.recordNo}',
      message: '${row.qty} × ${row.tool.toolCode} is back from ${row.vendorName ?? 'the vendor'}.',
      confirmLabel: 'Close repair',
      extra: StatefulBuilder(
        builder: (context, setInner) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDropdown<String>(
              value: outcome,
              items: const [
                DropdownMenuItem(value: 'REPAIRED', child: Text('Repaired — back into store')),
                DropdownMenuItem(value: 'RETURNED_AS_IS', child: Text('Returned as-is')),
                DropdownMenuItem(value: 'UNREPAIRABLE', child: Text('Unrepairable — scrap it')),
              ],
              onChanged: (v) => setInner(() => outcome = v ?? 'REPAIRED'),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(labelText: 'Final cost (₹)', isDense: true),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !mounted) {
      costController.dispose();
      return;
    }

    final result = await runWithProgress(
      context,
      () => ref.read(maintenanceRepositoryProvider).complete(
            row.id,
            completionStatus: outcome,
            finalCost: double.tryParse(costController.text.trim()),
          ),
      successMessage: '${row.recordNo} closed as ${StatusStyles.label(outcome)}',
    );
    costController.dispose();

    if (result != null) {
      invalidateStockViews(ref);
      ref
        ..invalidate(maintenanceListProvider)
        ..invalidate(maintenanceSummaryProvider);
    }
  }

  Widget _mobileCard(MaintenanceRecord row, bool canApprove) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MonoText(row.recordNo, size: 12)),
              StatusChip(row.type, dense: true),
              const SizedBox(width: 5),
              StatusChip(row.approvalStatus, dense: true),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${row.tool.name} · ${row.tool.toolCode} · qty ${row.qty}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            row.reason,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                '${Fmt.dateShort(row.recordDate)}${row.cost > 0 ? ' · ${Fmt.money(row.cost)}' : ''}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const Spacer(),
              _actions(row, canApprove),
            ],
          ),
        ],
      );
}
