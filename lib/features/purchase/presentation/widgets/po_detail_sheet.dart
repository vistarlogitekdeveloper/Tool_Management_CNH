import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/purchase.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../data/purchase_repository.dart';

/// Full PO record: lines, receipt history and the actions available at its
/// current status.
Future<void> showPoDetail(BuildContext context, WidgetRef ref, int poId) =>
    showDetailSheet<void>(context, _PoDetailSheet(poId: poId), width: 780);

class _PoDetailSheet extends ConsumerWidget {
  const _PoDetailSheet({required this.poId});

  final int poId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseDetailProvider(poId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: context.isMobile
          ? AppBar(
              title: Text(detail.valueOrNull?.poNo ?? 'Purchase order'),
              backgroundColor: Colors.white,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      body: AsyncView<PurchaseOrder>(
        value: detail,
        onRetry: () => ref.invalidate(purchaseDetailProvider(poId)),
        data: (po) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!context.isMobile)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, Insets.md, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              MonoText(po.poNo, size: 15),
                              const SizedBox(width: Insets.md),
                              StatusChip(po.status, dense: true),
                              if (po.isDelayed) ...[
                                const SizedBox(width: 6),
                                const StatusChip('OVERDUE', label: 'Delayed', dense: true),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${po.vendor.name} · raised ${Fmt.date(po.poDate)}'
                            '${po.createdByName != null ? ' by ${po.createdByName}' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SplitRow(
                      leftFlex: 1,
                      rightFlex: 1,
                      left: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KeyValueRow(label: 'Supplier', value: po.vendor.name),
                          KeyValueRow(label: 'PO date', value: Fmt.date(po.poDate)),
                          KeyValueRow(
                            label: 'Expected delivery',
                            value: po.expectedDate == null
                                ? '—'
                                : '${Fmt.date(po.expectedDate)} (${Fmt.relativeDays(po.expectedDate)})',
                          ),
                          KeyValueRow(label: 'Reference', value: po.referenceNo ?? '—'),
                        ],
                      ),
                      right: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KeyValueRow(label: 'Subtotal', value: Fmt.money(po.subtotal, precise: true)),
                          KeyValueRow(label: 'Tax', value: Fmt.money(po.taxAmount, precise: true)),
                          KeyValueRow(
                            label: 'Total value',
                            value: Fmt.money(po.totalValue, precise: true),
                          ),
                          KeyValueRow(
                            label: 'Approved by',
                            value: po.approvedByName ?? 'Not yet approved',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    SectionCard(
                      title: 'Line items',
                      subtitle: '${po.receivedQty} of ${po.totalQty} unit(s) received',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final item in po.items)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Insets.lg, vertical: Insets.md),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.line2)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 100, child: MonoText(item.toolCode)),
                                  Expanded(
                                    child: TwoLineCell(
                                      primary: item.toolName,
                                      secondary: item.remarks,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      item.isFullyReceived
                                          ? '${item.qty} received'
                                          : '${item.receivedQty}/${item.qty}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: item.isFullyReceived
                                            ? AppColors.greenInk
                                            : AppColors.amberInk,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Insets.md),
                                  SizedBox(
                                    width: 92,
                                    child: Text(
                                      Fmt.money(item.rate),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                    ),
                                  ),
                                  const SizedBox(width: Insets.md),
                                  SizedBox(
                                    width: 104,
                                    child: Text(
                                      Fmt.money(item.amount),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (po.receipts.isNotEmpty) ...[
                      const SizedBox(height: Insets.xl),
                      SectionCard(
                        title: 'Goods receipts',
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final grn in po.receipts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.lg, vertical: Insets.md),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: AppColors.line2)),
                                ),
                                child: Row(
                                  children: [
                                    MonoText(grn.grnNo, size: 12),
                                    const SizedBox(width: Insets.lg),
                                    Expanded(
                                      child: Text(
                                        '${grn.qty} unit(s)'
                                        '${grn.invoiceNo != null ? ' · invoice ${grn.invoiceNo}' : ''}'
                                        '${grn.receivedByName != null ? ' · ${grn.receivedByName}' : ''}',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                      ),
                                    ),
                                    Text(
                                      Fmt.date(grn.receiptDate),
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (po.remarks != null && po.remarks!.trim().isNotEmpty) ...[
                      const SizedBox(height: Insets.xl),
                      SectionCard(
                        title: 'Remarks',
                        child: Text(
                          po.remarks!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _footer(context, ref, po, user),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, WidgetRef ref, PurchaseOrder po, user) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.zebra,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (po.canMarkInTransit && (user?.can(P.purchaseCreate) ?? false))
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await runWithProgress(
                    context,
                    () => ref.read(purchaseRepositoryProvider).markInTransit(po.id),
                    successMessage: '${po.poNo} marked in transit',
                  );
                  if (result != null) {
                    ref
                      ..invalidate(purchaseDetailProvider(po.id))
                      ..invalidate(purchaseListProvider)
                      ..invalidate(purchaseSummaryProvider);
                  }
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Mark in transit'),
              ),
            if (po.canApprove && (user?.can(P.purchaseApprove) ?? false))
              FilledButton.icon(
                onPressed: () async {
                  final result = await runWithProgress(
                    context,
                    () => ref.read(purchaseRepositoryProvider).approve(po.id, approve: true),
                    successMessage: '${po.poNo} approved',
                  );
                  if (result != null) {
                    ref
                      ..invalidate(purchaseDetailProvider(po.id))
                      ..invalidate(purchaseListProvider)
                      ..invalidate(purchaseSummaryProvider);
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              ),
            if (po.canReceive && (user?.can(P.purchaseReceive) ?? false))
              FilledButton.icon(
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Receive ${po.poNo}?',
                    message: '${po.pendingQty} unit(s) will be added to available stock now.',
                    confirmLabel: 'Receive all outstanding',
                  );
                  if (!ok || !context.mounted) return;

                  final result = await runWithProgress(
                    context,
                    () => ref.read(purchaseRepositoryProvider).receive(po.id),
                  );
                  if (result != null) {
                    invalidateStockViews(ref);
                    ref
                      ..invalidate(purchaseDetailProvider(po.id))
                      ..invalidate(purchaseListProvider)
                      ..invalidate(purchaseSummaryProvider)
                      ..invalidate(reorderSuggestionsProvider);
                    if (context.mounted) {
                      context.toast('${result.grnNo ?? 'Receipt'} recorded — stock updated');
                    }
                  }
                },
                icon: const Icon(Icons.inventory_rounded, size: 17),
                label: const Text('Receive goods'),
              ),
          ],
        ),
      );
}
