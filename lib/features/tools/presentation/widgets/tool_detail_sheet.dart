import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/attachment_field.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/tool.dart';
import '../../../../models/user.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../files/data/files_repository.dart';
import '../../../inventory/presentation/widgets/stock_adjust_dialog.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart';
import '../../../maintenance/presentation/widgets/maintenance_dialog.dart';
import '../../../tracking/presentation/widgets/transfer_dialog.dart';
import '../../data/tools_repository.dart';
import 'tool_form_dialog.dart';

/// The full record behind a tool: master data, live stock, calibration status,
/// who is holding it, its attachments and its complete movement history.
Future<void> showToolDetail(BuildContext context, WidgetRef ref, int toolId) =>
    showDetailSheet<void>(context, _ToolDetailSheet(toolId: toolId));

class _ToolDetailSheet extends ConsumerWidget {
  const _ToolDetailSheet({required this.toolId});

  final int toolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(toolDetailProvider(toolId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: context.isMobile
          ? AppBar(
              title: Text(detail.valueOrNull?.name ?? 'Tool'),
              backgroundColor: Colors.white,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      body: AsyncView<Tool>(
        value: detail,
        onRetry: () => ref.invalidate(toolDetailProvider(toolId)),
        data: (tool) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!context.isMobile) _header(context, ref, tool, user),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(context, ref, tool, user),
                    const SizedBox(height: Insets.xl),
                    _stockPanel(tool),
                    if (tool.calibration.required) ...[
                      const SizedBox(height: Insets.xl),
                      _calibrationPanel(tool),
                    ],
                    if (tool.openIssues.isNotEmpty) ...[
                      const SizedBox(height: Insets.xl),
                      _holdersPanel(tool),
                    ],
                    const SizedBox(height: Insets.xl),
                    _historyPanel(tool),
                  ],
                ),
              ),
            ),
            _footer(context, ref, tool, user),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, Tool tool, user) => Container(
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
                      Flexible(
                        child: Text(
                          tool.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      MonoText(tool.toolCode, size: 13),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      CategoryChip(name: tool.category.name, colour: tool.category.colour, dense: true),
                      const SizedBox(width: 6),
                      StatusChip(tool.stock.statusCode, dense: true),
                      if (tool.calibration.required) ...[
                        const SizedBox(width: 6),
                        StatusChip(tool.calibration.status, dense: true),
                      ],
                      if (tool.status != 'ACTIVE') ...[
                        const SizedBox(width: 6),
                        StatusChip(tool.status, dense: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (user?.can(P.toolUpdate) ?? false)
              IconButton(
                onPressed: () async {
                  final saved = await showToolFormDialog(context, ref, existing: tool);
                  if (saved) ref.invalidate(toolDetailProvider(toolId));
                },
                icon: const Icon(Icons.edit_outlined, size: 19),
                tooltip: 'Edit tool',
                color: AppColors.slate,
              ),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.muted,
              tooltip: 'Close',
            ),
          ],
        ),
      );

  Widget _summary(BuildContext context, WidgetRef ref, Tool tool, AuthUser? user) => SplitRow(
        leftFlex: 1,
        rightFlex: 1,
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyValueRow(label: 'Part number', value: tool.partNumber ?? '—'),
            KeyValueRow(label: 'Specification', value: tool.specification ?? '—'),
            KeyValueRow(label: 'Manufacturer', value: tool.manufacturer ?? '—'),
            KeyValueRow(label: 'Location', value: tool.displayLocation),
            KeyValueRow(label: 'Unit cost', value: Fmt.money(tool.unitCost, precise: true)),
            KeyValueRow(label: 'Minimum stock', value: '${tool.stock.minStock} ${tool.uom}'),
            if (tool.barcode != null) KeyValueRow(label: 'Barcode', value: tool.barcode!),
          ],
        ),
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyValueRow(label: 'Purchase date', value: Fmt.date(tool.purchaseDate)),
            KeyValueRow(label: 'Warranty expiry', value: Fmt.date(tool.warrantyExpiry)),
            KeyValueRow(
              label: 'Inventory value',
              value: Fmt.money(tool.stock.inventoryValue, precise: true),
            ),
            if (tool.lifecycle.expectedCycles != null)
              KeyValueRow(
                label: 'Life consumed',
                value: '',
                valueWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(tool.lifecycle.stage, dense: true),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${tool.lifecycle.consumedPercent?.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            KeyValueRow(
              label: 'Drawing',
              value: '',
              valueWidget: AttachmentField(
                category: AttachmentCategory.drawing,
                attachmentId: tool.drawingAttachmentId,
                fileName: tool.attachments.byId(tool.drawingAttachmentId)?.fileName,
                dense: true,
                enabled: user?.can(P.toolUpdate) ?? false,
                entityType: 'tool',
                entityId: tool.id.toString(),
                onChanged: (id) => _saveAttachment(context, ref, tool,
                    field: 'drawingAttachmentId', id: id, noun: 'Drawing'),
              ),
            ),
            KeyValueRow(
              label: 'Tool photo',
              value: '',
              valueWidget: AttachmentField(
                category: AttachmentCategory.image,
                label: 'Tool photo',
                attachmentId: tool.imageAttachmentId,
                fileName: tool.attachments.byId(tool.imageAttachmentId)?.fileName,
                dense: true,
                enabled: user?.can(P.toolUpdate) ?? false,
                entityType: 'tool',
                entityId: tool.id.toString(),
                onChanged: (id) => _saveAttachment(context, ref, tool,
                    field: 'imageAttachmentId', id: id, noun: 'Photo'),
              ),
            ),
            KeyValueRow(
              label: 'All attachments',
              value: tool.attachments.isEmpty ? 'None' : '${tool.attachments.length} file(s)',
            ),
          ],
        ),
      );

  /// Attach or detach a document on the tool record.
  ///
  /// AttachmentField has already uploaded the file and holds its id; all that is
  /// left is to point the tool at it. Passing null clears the field, which is how
  /// "Remove" works — the file itself stays in the attachment archive.
  Future<void> _saveAttachment(
    BuildContext context,
    WidgetRef ref,
    Tool tool, {
    required String field,
    required String? id,
    required String noun,
  }) async {
    try {
      await ref.read(toolsRepositoryProvider).update(tool.id, {field: id});
      ref
        ..invalidate(toolDetailProvider(tool.id))
        ..invalidate(toolsListProvider);
      if (context.mounted) {
        context.toast(
          id == null ? '$noun removed from ${tool.toolCode}' : '$noun saved on ${tool.toolCode}',
        );
      }
    } catch (error) {
      if (context.mounted) context.showApiError(error);
    }
  }

  Widget _stockPanel(Tool tool) => SectionCard(
        title: 'Stock position',
        subtitle: '${tool.stock.stockPercent.toStringAsFixed(0)}% of the fleet available in store',
        child: Column(
          children: [
            LevelBar(
              percent: tool.stock.stockPercent,
              height: 9,
              colour: LevelBar.colourFor(
                percent: tool.stock.stockPercent,
                isLow: tool.stock.isLowStock,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.xl,
              runSpacing: Insets.md,
              children: [
                _stat('Total', tool.stock.total, AppColors.ink),
                _stat('Available', tool.stock.available, AppColors.green),
                _stat('Issued', tool.stock.issued, AppColors.brand),
                _stat('Reserved', tool.stock.reserved, AppColors.violet),
                _stat('In repair', tool.stock.repair, AppColors.amber),
                _stat('Scrapped', tool.stock.scrap, AppColors.red),
                if (tool.stock.damaged > 0) _stat('Damaged', tool.stock.damaged, AppColors.red),
                if (tool.stock.lost > 0) _stat('Lost', tool.stock.lost, AppColors.red),
              ],
            ),
          ],
        ),
      );

  Widget _stat(String label, int value, Color colour) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.int_(value),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colour, height: 1.1),
          ),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      );

  Widget _calibrationPanel(Tool tool) {
    final c = tool.calibration;
    return SectionCard(
      title: 'Calibration',
      trailing: StatusChip(c.status),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyValueRow(label: 'Frequency', value: '${c.frequencyMonths ?? '—'} months'),
          KeyValueRow(label: 'Last calibrated', value: Fmt.date(c.lastCalibrationDate)),
          KeyValueRow(
            label: 'Next due',
            value: c.nextDueDate == null
                ? 'Never calibrated'
                : '${Fmt.date(c.nextDueDate)} (${Fmt.relativeDays(c.nextDueDate)})',
          ),
          KeyValueRow(label: 'Certificate', value: c.certificateNo ?? '—'),
          KeyValueRow(label: 'Laboratory', value: c.vendorName ?? '—'),
          if (c.plannedDate != null)
            KeyValueRow(label: 'Next planned', value: Fmt.date(c.plannedDate)),
          if (c.isBlocking) ...[
            const SizedBox(height: Insets.md),
            const NoticeBar(
              tone: NoticeTone.danger,
              icon: Icons.block_rounded,
              message: 'This instrument cannot be issued until a calibration is recorded.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _holdersPanel(Tool tool) => SectionCard(
        title: 'Currently held by',
        subtitle: '${tool.openIssues.length} open issue(s)',
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final issue in tool.openIssues)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line2)),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(Fmt.initials(issue.employeeName), size: 30),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: TwoLineCell(
                        primary: issue.employeeName,
                        secondary: '${issue.department ?? '—'} · ${issue.location ?? '—'}',
                      ),
                    ),
                    Text(
                      'Qty ${issue.qtyOutstanding}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: Insets.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusChip(issue.isOverdue ? 'OVERDUE' : issue.status, dense: true),
                        const SizedBox(height: 2),
                        Text(
                          'Due ${Fmt.dateShort(issue.dueDate)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _historyPanel(Tool tool) => SectionCard(
        title: 'Recent movements',
        subtitle: 'Every quantity change, with who made it',
        padding: EdgeInsets.zero,
        child: tool.recentTransactions.isEmpty
            ? const EmptyState(
                compact: true,
                icon: Icons.history_rounded,
                message: 'No movements recorded yet.',
              )
            : Column(
                children: [
                  for (final txn in tool.recentTransactions)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.line2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TxnLabels.isInbound(txn.type)
                                  ? AppColors.greenSoft
                                  : AppColors.amberSoft,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              TxnLabels.isInbound(txn.type)
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              size: 15,
                              color: TxnLabels.isInbound(txn.type)
                                  ? AppColors.green
                                  : AppColors.amber,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: TwoLineCell(
                              primary: TxnLabels.of(txn.type),
                              secondary: txn.remarks ?? txn.employeeName,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${TxnLabels.isInbound(txn.type) ? '+' : '−'}${txn.qty}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: TxnLabels.isInbound(txn.type)
                                      ? AppColors.greenInk
                                      : AppColors.amberInk,
                                ),
                              ),
                              Text(
                                '${Fmt.dateShort(txn.at)} · ${txn.byUser ?? 'system'}',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );

  Widget _footer(BuildContext context, WidgetRef ref, Tool tool, user) => Container(
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
            if (user?.can(P.trackingTransfer) ?? false)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await showTransferDialog(context, ref, toolId: tool.id);
                },
                icon: const Icon(Icons.moving_rounded, size: 16),
                label: const Text('Transfer'),
              ),
            if (user?.can(P.inventoryAdjust) ?? false)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await showStockAdjustDialog(context, ref, toolId: tool.id);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Adjust Stock'),
              ),
            if (user?.can(P.maintenanceCreate) ?? false)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await showMaintenanceDialog(context, ref, toolId: tool.id);
                },
                icon: const Icon(Icons.handyman_outlined, size: 16),
                label: const Text('Repair / Scrap'),
              ),
            if (user?.can(P.issueCreate) ?? false)
              FilledButton.icon(
                onPressed: tool.stock.available == 0
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await showIssueDialog(context, ref, toolId: tool.id);
                      },
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: const Text('Issue this tool'),
              ),
          ],
        ),
      );
}
