import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../data/tracking_repository.dart';

/// Move a tool's home location — the RFQ's "Tool Transfer". Quantity-neutral:
/// it records where, not how many.
Future<bool> showTransferDialog(BuildContext context, WidgetRef ref, {int? toolId}) async {
  final result = await showAppDialog<bool>(context, _TransferDialog(toolId: toolId));
  return result ?? false;
}

class _TransferDialog extends ConsumerStatefulWidget {
  const _TransferDialog({this.toolId});

  final int? toolId;

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  final _reasonController = TextEditingController();

  int? _toolId;
  int? _toLocationId;
  int _qty = 1;
  bool _submitting = false;

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
      title: 'Transfer Tool',
      subtitle: 'Updates the tool\'s home location and writes a movement record',
      icon: Icons.moving_rounded,
      width: 500,
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
              : const Text('Transfer'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledField(
            label: 'Tool',
            required: true,
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
          LabeledField(
            label: 'Current location',
            child: AppTextField(
              key: ValueKey('from-${selected?.id}'),
              initialValue: selected?.locationName ?? '—',
              enabled: false,
            ),
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'New location',
                required: true,
                child: AppDropdown<int>(
                  value: _toLocationId,
                  hint: 'Where is it moving to?',
                  items: [
                    for (final l in masters?.locations ?? [])
                      DropdownMenuItem<int>(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _toLocationId = v),
                ),
              ),
              LabeledField(
                label: 'Quantity',
                child: QuantityField(
                  value: _qty,
                  onChanged: (v) => setState(() => _qty = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Reason',
            hint: 'Recorded on the transfer note and in the audit trail',
            child: AppTextField(
              controller: _reasonController,
              hintText: 'e.g. Line B changeover — moved to St-04',
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_toolId == null || _toLocationId == null) {
      context.toast('Select the tool and its destination', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final transfer = await ref.read(trackingRepositoryProvider).transfer(
            toolId: _toolId!,
            toLocationId: _toLocationId!,
            qty: _qty,
            reason: _reasonController.text.trim(),
          );

      invalidateStockViews(ref);
      ref
        ..invalidate(trackingLiveProvider)
        ..invalidate(trackingZonesProvider)
        ..invalidate(transferHistoryProvider)
        ..invalidate(toolDetailProvider(_toolId!));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        '${transfer.transferNo}: ${transfer.toolCode} moved '
        '${transfer.from ?? '—'} → ${transfer.to ?? '—'}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}
