import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/calibration.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../../../core/widgets/attachment_field.dart';
import '../../../files/data/files_repository.dart';
import '../../data/calibration_repository.dart';

/// Log a completed calibration: date, certificate, laboratory and result.
/// The next due date follows the frequency unless the certificate says otherwise;
/// a FAIL keeps the due date and raises a repair record automatically.
Future<bool> showCalibrationDialog(
  BuildContext context,
  WidgetRef ref, {
  required CalibrationStatus instrument,
}) async {
  final result = await showAppDialog<bool>(context, _CalibrationDialog(instrument: instrument));
  return result ?? false;
}

class _CalibrationDialog extends ConsumerStatefulWidget {
  const _CalibrationDialog({required this.instrument});

  final CalibrationStatus instrument;

  @override
  ConsumerState<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends ConsumerState<_CalibrationDialog> {
  final _certificateController = TextEditingController();

  // The signed certificate is uploaded before the record is saved and passed by
  // id; calibration.service then re-tags the attachment onto the new row.
  String? _certificateAttachmentId;
  final _performedByController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  DateTime _calibrationDate = DateTime.now();
  DateTime? _nextDueDate;
  late int _frequency;
  int? _vendorId;
  String _result = 'PASS';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _frequency = widget.instrument.frequencyMonths ?? 6;
    _recomputeNextDue();
  }

  @override
  void dispose() {
    _certificateController.dispose();
    _performedByController.dispose();
    _costController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  /// Keep the next due date in step with the frequency until the user overrides it.
  void _recomputeNextDue() {
    final base = _calibrationDate;
    final targetMonth = base.month + _frequency;
    final year = base.year + (targetMonth - 1) ~/ 12;
    final month = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    _nextDueDate = DateTime(year, month, base.day > lastDay ? lastDay : base.day);
  }

  @override
  Widget build(BuildContext context) {
    final labs = ref.watch(masterBootstrapProvider).valueOrNull?.calibrationLabs ?? const [];
    final instrument = widget.instrument;

    return AppDialog(
      title: 'Record Calibration',
      subtitle: '${instrument.toolName} · ${instrument.toolCode}',
      icon: Icons.verified_outlined,
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
              : const Text('Save Calibration'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(Insets.radiusSm),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyValueRow(
                  label: 'Current status',
                  value: '',
                  valueWidget: Align(
                    alignment: Alignment.centerRight,
                    child: StatusChipWrapper(status: instrument.status),
                  ),
                ),
                KeyValueRow(
                  label: 'Last calibrated',
                  value: Fmt.date(instrument.lastCalibrationDate),
                ),
                KeyValueRow(
                  label: 'Was due',
                  value: instrument.nextDueDate == null
                      ? 'Never calibrated'
                      : '${Fmt.date(instrument.nextDueDate)} (${instrument.dueHint})',
                ),
                KeyValueRow(
                  label: 'Previous certificate',
                  value: instrument.certificateNo ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'Calibration date',
                required: true,
                child: DateField(
                  value: _calibrationDate,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() {
                    _calibrationDate = d ?? DateTime.now();
                    _recomputeNextDue();
                  }),
                ),
              ),
              LabeledField(
                label: 'Frequency',
                required: true,
                child: AppDropdown<int>(
                  value: _frequency,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 months')),
                    DropdownMenuItem(value: 6, child: Text('6 months')),
                    DropdownMenuItem(value: 12, child: Text('12 months')),
                    DropdownMenuItem(value: 24, child: Text('24 months')),
                  ],
                  onChanged: (v) => setState(() {
                    _frequency = v ?? 6;
                    _recomputeNextDue();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Next due date',
            required: true,
            hint: 'Derived from the frequency — override if the certificate states another date',
            child: DateField(
              value: _nextDueDate,
              firstDate: _calibrationDate,
              onChanged: (d) => setState(() => _nextDueDate = d),
            ),
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'Certificate number',
                hint: 'Leave blank to auto-generate',
                child: AppTextField(
                  controller: _certificateController,
                  hintText: 'e.g. CAL-2026-0272',
                ),
              ),
              LabeledField(
                label: 'Result',
                required: true,
                child: AppDropdown<String>(
                  value: _result,
                  items: const [
                    DropdownMenuItem(value: 'PASS', child: Text('Pass — within tolerance')),
                    DropdownMenuItem(value: 'CONDITIONAL', child: Text('Conditional — use with limits')),
                    DropdownMenuItem(value: 'FAIL', child: Text('Fail — out of tolerance')),
                  ],
                  onChanged: (v) => setState(() => _result = v ?? 'PASS'),
                ),
              ),
            ],
          ),
          if (_result == 'FAIL') ...[
            const SizedBox(height: Insets.md),
            const NoticeBar(
              tone: NoticeTone.danger,
              icon: Icons.report_problem_outlined,
              message: 'A failed calibration raises a repair record for approval and leaves the '
                  'instrument blocked from issue until it passes.',
            ),
          ],
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'Laboratory / vendor',
                child: AppDropdown<int>(
                  value: _vendorId,
                  hint: 'Who performed it?',
                  items: [
                    for (final lab in labs)
                      DropdownMenuItem(value: lab.id, child: Text(lab.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
              ),
              LabeledField(
                label: 'Cost (₹)',
                child: AppTextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Performed by',
            child: AppTextField(
              controller: _performedByController,
              hintText: 'Lab technician name',
            ),
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Remarks',
            child: AppTextField(
              controller: _remarksController,
              hintText: 'Observations, deviations, adjustment made…',
              maxLines: 2,
            ),
          ),
          const SizedBox(height: Insets.lg),
          AttachmentField(
            category: AttachmentCategory.certificate,
            label: 'Signed certificate',
            attachmentId: _certificateAttachmentId,
            enabled: !_submitting,
            onChanged: (id) => setState(() => _certificateAttachmentId = id),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_nextDueDate == null) {
      context.toast('Set the next due date', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final saved = await ref.read(calibrationRepositoryProvider).record(
            toolId: widget.instrument.toolId,
            calibrationDate: _calibrationDate,
            nextDueDate: _nextDueDate,
            frequencyMonths: _frequency,
            certificateNo: _certificateController.text.trim(),
            certificateAttachmentId: _certificateAttachmentId,
            vendorId: _vendorId,
            cost: double.tryParse(_costController.text.trim()) ?? 0,
            result: _result,
            performedBy: _performedByController.text.trim(),
            remarks: _remarksController.text.trim(),
          );

      ref
        ..invalidate(calibrationScheduleProvider)
        ..invalidate(calibrationSummaryProvider)
        ..invalidate(monthlyPlanProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(maintenanceListProvider)
        ..invalidate(maintenanceSummaryProvider)
        ..invalidate(toolDetailProvider(widget.instrument.toolId))
        ..invalidate(toolCalibrationHistoryProvider(widget.instrument.toolId));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        'Calibration logged for ${widget.instrument.toolCode} · '
        'certificate ${saved.certificateNo ?? '—'}'
        '${saved.maintenanceRecordNo != null ? ' · repair ${saved.maintenanceRecordNo} raised' : ''}',
        kind: _result == 'FAIL' ? ToastKind.warning : ToastKind.success,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}

/// Small adaptor so the KeyValueRow can host a chip without importing the
/// status widget into every caller.
class StatusChipWrapper extends StatelessWidget {
  const StatusChipWrapper({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(status, dense: true);
}
