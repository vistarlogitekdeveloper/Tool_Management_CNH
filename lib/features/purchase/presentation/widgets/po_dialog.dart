import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../models/purchase.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../data/purchase_repository.dart';

/// Raise a purchase order. Multi-line, with live totals; pre-fillable from a
/// reorder suggestion so a low-stock list becomes a PO in two clicks.
Future<bool> showPoDialog(
  BuildContext context,
  WidgetRef ref, {
  ReorderSuggestion? fromSuggestion,
}) async {
  final result = await showAppDialog<bool>(context, _PoDialog(suggestion: fromSuggestion));
  return result ?? false;
}

class _PoDialog extends ConsumerStatefulWidget {
  const _PoDialog({this.suggestion});

  final ReorderSuggestion? suggestion;

  @override
  ConsumerState<_PoDialog> createState() => _PoDialogState();
}

class _PoDialogState extends ConsumerState<_PoDialog> {
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();
  final List<PoDraftLine> _lines = [];

  int? _vendorId;
  DateTime _poDate = DateTime.now();
  DateTime? _expectedDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _expectedDate = DateTime.now().add(const Duration(days: 10));

    final suggestion = widget.suggestion;
    if (suggestion != null) {
      _vendorId = suggestion.vendorId;
      for (final line in suggestion.lines) {
        _lines.add(PoDraftLine(
          toolId: line.toolId,
          toolCode: line.toolCode,
          toolName: line.name,
          qty: line.suggestedQty,
          rate: line.rate,
        ));
      }
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.net);
  double get _tax => _lines.fold(0, (s, l) => s + l.tax);
  double get _total => _subtotal + _tax;

  @override
  Widget build(BuildContext context) {
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;
    final tools = ref.watch(toolOptionsProvider).valueOrNull ?? const [];
    final approvalThreshold = ref.watch(settingValueProvider('purchase.require_approval_above'));
    final threshold = approvalThreshold is num ? approvalThreshold.toDouble() : 50000.0;

    return AppDialog(
      title: 'New Purchase Order',
      subtitle: 'Receiving the goods updates stock automatically',
      icon: Icons.shopping_cart_outlined,
      width: 760,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: _submitting || _lines.isEmpty ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Raise PO'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FieldRow(
            children: [
              LabeledField(
                label: 'Supplier',
                required: true,
                child: AppDropdown<int>(
                  value: _vendorId,
                  hint: 'Select a supplier',
                  items: [
                    for (final v in masters?.suppliers ?? [])
                      DropdownMenuItem<int>(
                        value: v.id,
                        child: Text(v.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
              ),
              LabeledField(
                label: 'Reference / indent no.',
                child: AppTextField(controller: _referenceController, hintText: 'Optional'),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'PO date',
                child: DateField(
                  value: _poDate,
                  onChanged: (d) => setState(() => _poDate = d ?? DateTime.now()),
                ),
              ),
              LabeledField(
                label: 'Expected delivery',
                hint: _expectedDate == null ? null : Fmt.relativeDays(_expectedDate),
                child: DateField(
                  value: _expectedDate,
                  firstDate: _poDate,
                  onChanged: (d) => setState(() => _expectedDate = d),
                ),
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),
          Row(
            children: [
              const Text(
                'LINE ITEMS',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addLine(tools),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add line'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: Insets.xl),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(Insets.radiusSm),
                border: Border.all(color: AppColors.line),
              ),
              child: const Center(
                child: Text(
                  'Add at least one tool to order.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Insets.radiusSm),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _lines.length; i++) _lineRow(i, tools),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
                    color: AppColors.zebra,
                    child: Column(
                      children: [
                        _totalRow('Subtotal', _subtotal),
                        const SizedBox(height: 5),
                        _totalRow('Tax', _tax),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: Insets.sm),
                          child: Divider(height: 1, color: AppColors.line),
                        ),
                        _totalRow('Total', _total, bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_total > threshold) ...[
            const SizedBox(height: Insets.md),
            NoticeBar(
              tone: NoticeTone.info,
              icon: Icons.gavel_rounded,
              message: 'Above ${Fmt.money(threshold)}, this PO needs approval before goods '
                  'can be received.',
            ),
          ],

          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Remarks',
            child: AppTextField(
              controller: _remarksController,
              hintText: 'Delivery instructions, quality requirements…',
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(int index, List tools) {
    final line = _lines[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TwoLineCell(primary: line.toolName, secondary: line.toolCode),
              ),
              IconButton(
                onPressed: () => setState(() => _lines.removeAt(index)),
                icon: const Icon(Icons.close_rounded, size: 16),
                color: AppColors.muted,
                tooltip: 'Remove line',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              SizedBox(
                width: 118,
                child: QuantityField(
                  value: line.qty,
                  onChanged: (v) => setState(() => line.qty = v),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: TextFormField(
                  key: ValueKey('rate-${line.toolId}'),
                  initialValue: line.rate.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Rate',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => line.rate = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: Insets.sm),
              SizedBox(
                width: 92,
                child: TextFormField(
                  key: ValueKey('tax-${line.toolId}'),
                  initialValue: line.taxPercent.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    suffixText: '%',
                    labelText: 'Tax',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => line.taxPercent = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: Insets.md),
              SizedBox(
                width: 106,
                child: Text(
                  Fmt.money(line.total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(width: Insets.lg),
          SizedBox(
            width: 120,
            child: Text(
              Fmt.money(value, precise: true),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppColors.brand : AppColors.ink,
              ),
            ),
          ),
        ],
      );

  Future<void> _addLine(List tools) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add a tool to the order', style: TextStyle(fontSize: 15)),
        children: [
          SizedBox(
            width: 420,
            height: 400,
            child: ListView(
              children: [
                for (final tool in tools)
                  if (!_lines.any((l) => l.toolId == tool.id))
                    ListTile(
                      dense: true,
                      title: Text(tool.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${tool.toolCode} · ${tool.availableQty} in stock · '
                        '${Fmt.money(tool.unitCost)}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => Navigator.of(context).pop(tool.id as int),
                    ),
              ],
            ),
          ),
        ],
      ),
    );

    if (selected == null) return;
    final tool = tools.firstWhere((t) => t.id == selected);
    setState(() {
      _lines.add(PoDraftLine(
        toolId: tool.id as int,
        toolCode: tool.toolCode as String,
        toolName: tool.name as String,
        qty: (tool.minStock as int) > 0 ? tool.minStock as int : 1,
        rate: (tool.unitCost as num).toDouble(),
      ));
    });
  }

  Future<void> _submit() async {
    if (_vendorId == null) {
      context.toast('Select a supplier', kind: ToastKind.warning);
      return;
    }
    if (_lines.any((l) => l.qty <= 0)) {
      context.toast('Every line needs a quantity of at least 1', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final po = await ref.read(purchaseRepositoryProvider).create(
            vendorId: _vendorId!,
            lines: _lines,
            poDate: _poDate,
            expectedDate: _expectedDate,
            referenceNo: _referenceController.text.trim(),
            remarks: _remarksController.text.trim(),
          );

      ref
        ..invalidate(purchaseListProvider)
        ..invalidate(purchaseSummaryProvider)
        ..invalidate(reorderSuggestionsProvider);
      invalidateStockViews(ref);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        '${po.poNo} raised on ${po.vendor.name} · ${Fmt.money(po.totalValue)}'
        '${po.status == 'PENDING' ? ' — awaiting approval' : ''}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}
