import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../models/maintenance.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../../../core/widgets/attachment_field.dart';
import '../../../files/data/files_repository.dart';
import '../../data/maintenance_repository.dart';

/// Raise a repair, scrap, damage or loss record. The quantity leaves available
/// stock immediately — a tool at the vendor must not be issuable while the
/// approval is pending.
Future<bool> showMaintenanceDialog(
  BuildContext context,
  WidgetRef ref, {
  int? toolId,
  String initialType = 'REPAIR',
}) async {
  final result = await showAppDialog<bool>(
    context,
    _MaintenanceDialog(toolId: toolId, initialType: initialType),
  );
  return result ?? false;
}

class _MaintenanceDialog extends ConsumerStatefulWidget {
  const _MaintenanceDialog({this.toolId, this.initialType = 'REPAIR'});

  final int? toolId;
  final String initialType;

  @override
  ConsumerState<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends ConsumerState<_MaintenanceDialog> {
  final _reasonController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  // Quotation, vendor report or scrap authorisation — maintenance_records carries
  // an attachment_id, and the create endpoint has always accepted it.
  String? _attachmentId;

  int? _toolId;
  int? _vendorId;
  int? _reportedById;
  late String _type;
  int _qty = 1;
  DateTime _recordDate = DateTime.now();
  DateTime? _expectedReturn;
  bool _submitting = false;

  bool get _isRepair => _type == 'REPAIR';

  @override
  void initState() {
    super.initState();
    _toolId = widget.toolId;
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _costController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  static const _typeLabels = <String, ({String label, String help})>{
    'REPAIR': (
      label: 'Repair — send to a vendor',
      help: 'The quantity moves to the repair bucket until it comes back.',
    ),
    'SCRAP': (
      label: 'Scrap — remove from the fleet',
      help: 'The quantity leaves the fleet permanently and is counted as scrapped.',
    ),
    'DAMAGE': (
      label: 'Damage — report a damaged tool',
      help: 'The quantity leaves available stock and is held as damaged pending a decision.',
    ),
    'LOST': (
      label: 'Lost — write the tool off',
      help: 'The quantity is written off the fleet and recorded as a loss.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(toolOptionsProvider).valueOrNull ?? const [];
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;
    final selected = tools.where((t) => t.id == _toolId).firstOrNull;

    return AppDialog(
      title: 'Repair / Scrap Record',
      subtitle: 'Raised for approval and reflected in stock immediately',
      icon: Icons.handyman_outlined,
      width: 600,
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
              : const Text('Save Record'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledField(
            label: 'Tool',
            required: true,
            hint: selected == null ? null : '${selected.availableQty} available to move',
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
                label: 'Action',
                required: true,
                child: AppDropdown<String>(
                  value: _type,
                  items: [
                    for (final entry in _typeLabels.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value.label)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'REPAIR'),
                ),
              ),
              LabeledField(
                label: 'Quantity',
                required: true,
                child: QuantityField(
                  value: _qty,
                  max: selected?.availableQty,
                  onChanged: (v) => setState(() => _qty = v),
                  helper: selected == null ? null : 'Maximum ${selected.availableQty}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          NoticeBar(
            tone: _type == 'REPAIR' ? NoticeTone.info : NoticeTone.warning,
            icon: Icons.info_outline_rounded,
            message: _typeLabels[_type]!.help,
          ),
          const SizedBox(height: Insets.sm),
          FieldRow(
            children: [
              LabeledField(
                label: 'Date',
                child: DateField(
                  value: _recordDate,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _recordDate = d ?? DateTime.now()),
                ),
              ),
              if (masters != null)
                LabeledField(
                  label: 'Reported by',
                  child: AppDropdown<int>(
                    value: _reportedById,
                    hint: 'Optional',
                    items: [
                      for (final e in masters.employees)
                        DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _reportedById = v),
                  ),
                ),
            ],
          ),
          if (_isRepair) ...[
            const SizedBox(height: Insets.lg),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Repair vendor',
                  child: AppDropdown<int>(
                    value: _vendorId,
                    hint: 'Who is repairing it?',
                    items: [
                      for (final v in masters?.repairVendors ?? [])
                        DropdownMenuItem<int>(
                          value: v.id,
                          child: Text(v.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _vendorId = v),
                  ),
                ),
                LabeledField(
                  label: 'Estimated cost (₹)',
                  child: AppTextField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Expected back on',
              hint: 'Used to flag repairs that are running late',
              child: DateField(
                value: _expectedReturn,
                clearable: true,
                firstDate: _recordDate,
                onChanged: (d) => setState(() => _expectedReturn = d),
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Reason',
            required: true,
            hint: 'Becomes the reason on the record and in the cost report',
            child: AppTextField(
              controller: _reasonController,
              hintText: switch (_type) {
                'REPAIR' => 'e.g. Jaw wear / measurement drift',
                'SCRAP' => 'e.g. Cutting edge chipped beyond regrind',
                'DAMAGE' => 'e.g. Dropped during setup, body cracked',
                _ => 'e.g. Not returned after shift, search unsuccessful',
              },
              maxLines: 2,
            ),
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Remarks',
            child: AppTextField(
              controller: _remarksController,
              hintText: 'Optional',
              maxLines: 2,
            ),
          ),
          const SizedBox(height: Insets.lg),
          AttachmentField(
            category: AttachmentCategory.document,
            label: 'Supporting document',
            attachmentId: _attachmentId,
            enabled: !_submitting,
            onChanged: (id) => setState(() => _attachmentId = id),
          ),
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
      context.toast('A reason is required', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final MaintenanceRecord saved = await ref.read(maintenanceRepositoryProvider).create(
            toolId: _toolId!,
            type: _type,
            qty: _qty,
            reason: _reasonController.text.trim(),
            recordDate: _recordDate,
            vendorId: _isRepair ? _vendorId : null,
            cost: _isRepair ? double.tryParse(_costController.text.trim()) ?? 0 : 0,
            reportedByEmployeeId: _reportedById,
            expectedReturnDate: _isRepair ? _expectedReturn : null,
            attachmentId: _attachmentId,
            remarks: _remarksController.text.trim(),
          );

      invalidateStockViews(ref);
      ref
        ..invalidate(maintenanceListProvider)
        ..invalidate(maintenanceSummaryProvider)
        ..invalidate(maintenanceCostProvider)
        ..invalidate(toolDetailProvider(_toolId!));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        '${saved.recordNo}: ${_type.toLowerCase()} logged for $_qty × ${saved.tool.toolCode}'
        '${saved.isPending ? ' — awaiting approval' : ''}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}
