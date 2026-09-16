import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../data/inventory_repository.dart';

/// Manual stock correction — physical counts, found items, write-offs. The
/// reason is mandatory: an unexplained quantity change is exactly what the
/// audit trail exists to prevent.
Future<bool> showStockAdjustDialog(BuildContext context, WidgetRef ref, {int? toolId}) async {
  final result = await showAppDialog<bool>(context, _StockAdjustDialog(toolId: toolId));
  return result ?? false;
}

class _StockAdjustDialog extends ConsumerStatefulWidget {
  const _StockAdjustDialog({this.toolId});

  final int? toolId;

  @override
  ConsumerState<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<_StockAdjustDialog> {
  final _reasonController = TextEditingController();

  int? _toolId;
  int? _locationId;
  String _direction = 'IN';
  int _qty = 1;
  bool _submitting = false;

  static const _reasonPresets = <String>[
    'Physical count correction',
    'Opening balance migrated from register',
    'Found in the shop',
    'Consumed / written off',
    'Data entry correction',
  ];

  @override
  void initState() {
    super.initState();
    _toolId = widget.toolId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(toolOptionsProvider).valueOrNull ?? const [];
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;
    final selected = tools.where((t) => t.id == _toolId).firstOrNull;

    return AppDialog(
      title: 'Stock Adjustment',
      subtitle: 'Recorded in the ledger with your name and reason',
      icon: Icons.tune_rounded,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Apply Adjustment'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledField(
            label: 'Tool',
            required: true,
            hint: selected == null
                ? null
                : 'Currently ${selected.availableQty} available in store',
            child: AppDropdown<int>(
              value: _toolId,
              hint: 'Select a tool',
              items: [
                for (final tool in tools)
                  DropdownMenuItem(
                    value: tool.id,
                    child: Text(tool.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _toolId = v),
            ),
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'Adjustment',
                required: true,
                child: AppDropdown<String>(
                  value: _direction,
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('Add to stock  (+)')),
                    DropdownMenuItem(value: 'OUT', child: Text('Remove from stock  (−)')),
                  ],
                  onChanged: (v) => setState(() => _direction = v ?? 'IN'),
                ),
              ),
              LabeledField(
                label: 'Quantity',
                required: true,
                child: QuantityField(
                  value: _qty,
                  max: _direction == 'OUT' ? selected?.availableQty : null,
                  onChanged: (v) => setState(() => _qty = v),
                  helper: _direction == 'OUT' && selected != null
                      ? 'Maximum ${selected.availableQty} can be removed'
                      : null,
                ),
              ),
            ],
          ),
          if (masters != null) ...[
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Location',
              child: AppDropdown<int>(
                value: _locationId,
                hint: 'Optional — where the correction applies',
                items: [
                  for (final l in masters.locations)
                    DropdownMenuItem(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Reason',
            required: true,
            hint: 'Appears on the ledger entry and in the audit trail',
            child: AppTextField(
              controller: _reasonController,
              hintText: 'e.g. Physical count correction — shelf B2',
              maxLines: 2,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in _reasonPresets)
                ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => setState(() => _reasonController.text = preset),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.bg,
                  side: const BorderSide(color: AppColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                ),
            ],
          ),
          if (selected != null && _direction == 'OUT' && _qty > selected.availableQty) ...[
            const SizedBox(height: Insets.md),
            NoticeBar(
              tone: NoticeTone.danger,
              message: 'Only ${selected.availableQty} available — the server will reject this.',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_toolId == null) {
      context.toast('Select a tool first', kind: ToastKind.warning);
      return;
    }
    if (_reasonController.text.trim().length < 3) {
      context.toast('A reason is required for every stock adjustment', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(inventoryRepositoryProvider).adjust(
            toolId: _toolId!,
            direction: _direction,
            qty: _qty,
            reason: _reasonController.text.trim(),
            locationId: _locationId,
          );

      invalidateStockViews(ref);
      ref.invalidate(toolDetailProvider(_toolId!));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        'Stock ${_direction == 'IN' ? 'increased' : 'reduced'} by $_qty · '
        '${result['available']} now available',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}
