import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../models/enums.dart';
import '../../../models/purchase.dart';
import '../../auth/data/auth_controller.dart';
import '../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../reports/presentation/widgets/export_menu.dart';
import '../data/purchase_repository.dart';
import 'widgets/po_detail_sheet.dart';
import 'widgets/po_dialog.dart';
import 'widgets/reorder_panel.dart';

/// Purchase & Procurement — PO to receipt, with the stock update the RFQ calls
/// out happening on receipt.
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _searchController = TextEditingController();
  bool _showReorder = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final query = ref.watch(purchaseQueryProvider);
    final list = ref.watch(purchaseListProvider);
    final summary = ref.watch(purchaseSummaryProvider);
    final suggestions = ref.watch(reorderSuggestionsProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Purchase',
          title: 'Purchase & Procurement',
          subtitle: 'New orders, supplier details, and automatic stock update on receipt',
          actions: [
            if ((suggestions?.isNotEmpty ?? false) && (user?.can(P.purchaseCreate) ?? false))
              OutlinedButton.icon(
                onPressed: () => setState(() => _showReorder = !_showReorder),
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(
                  _showReorder
                      ? 'Hide suggestions'
                      : 'Reorder suggestions (${suggestions!.length})',
                ),
              ),
            if (user?.can(P.reportsExport) ?? false)
              ExportButton(reportKey: 'purchase', label: 'Export'),
            if (user?.can(P.purchaseCreate) ?? false)
              FilledButton.icon(
                onPressed: () => showPoDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('New Purchase Order'),
              ),
          ],
        ),

        AsyncView<PurchaseSummary>(
          value: summary,
          showRefreshLine: false,
          loading: const SizedBox(height: 118, child: BlockSkeleton()),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.delayed > 0)
                NoticeBar(
                  tone: NoticeTone.warning,
                  icon: Icons.local_shipping_outlined,
                  message: '${s.delayed} purchase order(s) are past their expected delivery date.',
                ),
              KpiStrip(
                cards: [
                  KpiCard(
                    label: 'Open Orders',
                    value: Fmt.int_(s.pending + s.approved + s.inTransit + s.partiallyReceived),
                    icon: Icons.shopping_cart_outlined,
                    tone: KpiTone.blue,
                    caption: 'Value ${Fmt.moneyCompact(s.openValue)}',
                  ),
                  KpiCard(
                    label: 'In Transit',
                    value: Fmt.int_(s.inTransit + s.partiallyReceived),
                    icon: Icons.local_shipping_outlined,
                    tone: KpiTone.amber,
                    caption: s.delayed > 0 ? '${s.delayed} delayed' : 'On schedule',
                    captionTone: s.delayed > 0 ? KpiTone.red : KpiTone.green,
                  ),
                  KpiCard(
                    label: 'Awaiting Approval',
                    value: Fmt.int_(s.pending),
                    icon: Icons.gavel_rounded,
                    tone: s.pending > 0 ? KpiTone.amber : KpiTone.green,
                    caption: s.pending > 0 ? 'Blocked until approved' : 'Nothing pending',
                    captionTone: s.pending > 0 ? KpiTone.amber : KpiTone.green,
                  ),
                  KpiCard(
                    label: 'Received',
                    value: Fmt.int_(s.received),
                    icon: Icons.check_circle_outline_rounded,
                    tone: KpiTone.green,
                    caption: 'YTD spend ${Fmt.moneyCompact(s.ytdValue)}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        if (_showReorder) ...[
          const ReorderPanel(),
          const SizedBox(height: Insets.lg),
        ],

        FilterBar(
          controls: [
            SearchField(
              controller: _searchController,
              hintText: 'PO number or supplier…',
              width: 250,
              onChanged: (value) =>
                  ref.read(purchaseQueryProvider.notifier).update((q) => q.copyWith(q: value)),
            ),
            SegmentedFilter<String?>(
              value: query.status,
              onChanged: (value) => ref.read(purchaseQueryProvider.notifier).update(
                    (q) => value == null ? q.copyWith(clearStatus: true) : q.copyWith(status: value),
                  ),
              segments: [
                (value: null, label: 'All', count: null),
                (value: 'PENDING', label: 'Pending', count: summary.valueOrNull?.pending),
                (value: 'APPROVED', label: 'Approved', count: summary.valueOrNull?.approved),
                (value: 'IN_TRANSIT', label: 'In transit', count: summary.valueOrNull?.inTransit),
                (value: 'RECEIVED', label: 'Received', count: null),
              ],
            ),
          ],
        ),

        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<PurchaseOrder>>(
            value: list,
            onRetry: () => ref.invalidate(purchaseListProvider),
            loading: const GridSkeleton(),
            data: (paged) => Column(
              children: [
                DataGrid<PurchaseOrder>(
                  rows: paged.items,
                  minWidth: 1180,
                  sortKey: query.sort,
                  sortAscending: query.order == 'asc',
                  onSort: (key) =>
                      ref.read(purchaseQueryProvider.notifier).update((q) => q.copyWith(sort: key,
                          order: q.sort == key && q.order == 'asc' ? 'desc' : 'asc')),
                  onRowTap: (row) => showPoDetail(context, ref, row.id),
                  emptyMessage: 'No purchase orders match your filters.',
                  emptyIcon: Icons.shopping_cart_outlined,
                  mobileCardBuilder: _mobileCard,
                  columns: _columns(user),
                ),
                PaginationBar(
                  meta: paged.meta,
                  unit: 'purchase orders',
                  onPage: (page) => ref
                      .read(purchaseQueryProvider.notifier)
                      .update((q) => q.copyWith(page: page)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<GridColumn<PurchaseOrder>> _columns(user) {
    final canApprove = user?.can(P.purchaseApprove) ?? false;
    final canReceive = user?.can(P.purchaseReceive) ?? false;

    return [
      GridColumn<PurchaseOrder>(
        label: 'PO No.',
        width: 132,
        sortKey: 'poNo',
        cell: (row) => MonoText(row.poNo, size: 12),
      ),
      GridColumn<PurchaseOrder>(
        label: 'Supplier',
        flex: 3,
        sortKey: 'vendor',
        cell: (row) => TwoLineCell(primary: row.vendor.name, secondary: row.primaryToolLabel),
      ),
      GridColumn<PurchaseOrder>(
        label: 'PO Date',
        width: 104,
        sortKey: 'poDate',
        hideBelow: ScreenSize.tablet,
        cell: (row) => Text(
          Fmt.date(row.poDate),
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
      GridColumn<PurchaseOrder>(
        label: 'Expected',
        width: 116,
        sortKey: 'expectedDate',
        cell: (row) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Fmt.date(row.expectedDate),
              style: TextStyle(
                fontSize: 12.5,
                color: row.isDelayed ? AppColors.redInk : AppColors.ink,
                fontWeight: row.isDelayed ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (row.isDelayed)
              const Text('delayed', style: TextStyle(fontSize: 10.5, color: AppColors.redInk)),
          ],
        ),
      ),
      GridColumn<PurchaseOrder>(
        label: 'Qty',
        width: 96,
        numeric: true,
        align: Alignment.centerRight,
        cell: (row) => Text(
          row.receivedQty > 0 && row.receivedQty < row.totalQty
              ? '${row.receivedQty}/${row.totalQty}'
              : '${row.totalQty}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      GridColumn<PurchaseOrder>(
        label: 'Value',
        width: 118,
        numeric: true,
        align: Alignment.centerRight,
        sortKey: 'value',
        cell: (row) => Text(
          Fmt.money(row.totalValue),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
      GridColumn<PurchaseOrder>(
        label: 'Status',
        width: 142,
        sortKey: 'status',
        cell: (row) => StatusChip(row.status),
      ),
      GridColumn<PurchaseOrder>(
        label: '',
        width: 172,
        align: Alignment.centerRight,
        cell: (row) => _actions(row, canApprove: canApprove, canReceive: canReceive),
      ),
    ];
  }

  Widget _actions(PurchaseOrder row, {required bool canApprove, required bool canReceive}) {
    if (row.canApprove && canApprove) {
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
            child: const Text('Cancel'),
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

    if (row.canReceive && canReceive) {
      return FilledButton.icon(
        onPressed: () => _receive(row),
        icon: const Icon(Icons.inventory_rounded, size: 15),
        label: const Text('Receive'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (row.status == 'RECEIVED') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: AppColors.green),
          SizedBox(width: 4),
          Text('Received', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _decide(PurchaseOrder row, {required bool approve}) async {
    final ok = await confirm(
      context,
      title: approve ? 'Approve ${row.poNo}?' : 'Cancel ${row.poNo}?',
      message: approve
          ? 'Approving releases the order to ${row.vendor.name} for '
              '${Fmt.money(row.totalValue, precise: true)}.'
          : 'Cancelling closes the order. Goods can no longer be received against it.',
      confirmLabel: approve ? 'Approve' : 'Cancel PO',
      cancelLabel: 'Back',
      destructive: !approve,
    );
    if (!ok || !mounted) return;

    final result = await runWithProgress(
      context,
      () => ref.read(purchaseRepositoryProvider).approve(row.id, approve: approve),
      successMessage: '${row.poNo} ${approve ? 'approved' : 'cancelled'}',
    );
    if (result != null) {
      ref
        ..invalidate(purchaseListProvider)
        ..invalidate(purchaseSummaryProvider);
    }
  }

  Future<void> _receive(PurchaseOrder row) async {
    final ok = await confirm(
      context,
      title: 'Receive ${row.poNo}?',
      message: 'This records a goods receipt for the ${row.pendingQty} outstanding unit(s) and '
          'adds them to available stock immediately.',
      confirmLabel: 'Receive all outstanding',
    );
    if (!ok || !mounted) return;

    final result = await runWithProgress(
      context,
      () => ref.read(purchaseRepositoryProvider).receive(row.id),
    );
    if (result != null) {
      invalidateStockViews(ref);
      ref
        ..invalidate(purchaseListProvider)
        ..invalidate(purchaseSummaryProvider)
        ..invalidate(reorderSuggestionsProvider)
        ..invalidate(purchaseDetailProvider(row.id));
      if (mounted) {
        context.toast('${result.grnNo ?? 'Receipt'} recorded — stock updated for ${row.poNo}');
      }
    }
  }

  Widget _mobileCard(PurchaseOrder row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MonoText(row.poNo, size: 12)),
              StatusChip(row.status, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.vendor.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          Text(
            row.primaryToolLabel,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.totalQty} unit(s) · ${Fmt.money(row.totalValue)} · '
                  'expected ${Fmt.dateShort(row.expectedDate)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: row.isDelayed ? AppColors.redInk : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
