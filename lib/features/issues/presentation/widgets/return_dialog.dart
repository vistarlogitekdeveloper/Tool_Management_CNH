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
import '../../../../models/issue.dart';
import '../../data/issues_repository.dart';
import 'issue_dialog.dart';

/// Accept a tool back into store. Supports partial returns and records the
/// condition — anything but GOOD routes the units out of available stock and
/// raises a maintenance record automatically.
Future<bool> showReturnDialog(BuildContext context, WidgetRef ref, ToolIssue issue) async {
  final result = await showAppDialog<bool>(context, _ReturnDialog(issue: issue));
  return result ?? false;
}

class _ReturnDialog extends ConsumerStatefulWidget {
  const _ReturnDialog({required this.issue});

  final ToolIssue issue;

  @override
  ConsumerState<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<_ReturnDialog> {
  final _remarksController = TextEditingController();
  late int _qty;
  String _condition = 'GOOD';
  DateTime _returnDate = DateTime.now();
  bool _submitting = false;

  int get _outstanding => widget.issue.qtyOutstanding > 0
      ? widget.issue.qtyOutstanding
      : widget.issue.qtyIssued - widget.issue.qtyReturned;

  @override
  void initState() {
    super.initState();
    _qty = _outstanding;
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  static const _conditions = <String, String>{
    'GOOD': 'Good — back into store',
    'NEEDS_CALIBRATION': 'Needs calibration — flag to Quality',
    'DAMAGED': 'Damaged — raise a damage record',
    'LOST': 'Lost — write the quantity off',
  };

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final isPartial = _qty < _outstanding;

    return AppDialog(
      title: 'Return Tool',
      subtitle: '${issue.issueNo} · ${issue.employee.name}',
      icon: Icons.assignment_return_outlined,
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
              : Text(isPartial ? 'Record Partial Return' : 'Confirm Return'),
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
                KeyValueRow(label: 'Tool', value: '${issue.tool.name} (${issue.tool.toolCode})'),
                KeyValueRow(label: 'Issued to', value: issue.employee.name),
                KeyValueRow(label: 'Station', value: issue.location ?? '—'),
                KeyValueRow(label: 'Issued on', value: Fmt.date(issue.issueDate)),
                KeyValueRow(
                  label: 'Due back',
                  value: Fmt.date(issue.dueDate),
                  valueWidget: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (issue.isOverdue) ...[
                        StatusChip('OVERDUE', label: '${issue.daysOverdue}d late', dense: true),
                        const SizedBox(width: Insets.sm),
                      ],
                      Text(
                        Fmt.date(issue.dueDate),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                KeyValueRow(
                  label: 'Outstanding',
                  value: '$_outstanding of ${issue.qtyIssued}',
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          FieldRow(
            children: [
              LabeledField(
                label: 'Quantity returned',
                required: true,
                child: QuantityField(
                  value: _qty,
                  max: _outstanding,
                  onChanged: (v) => setState(() => _qty = v),
                  helper: isPartial
                      ? '${_outstanding - _qty} will stay outstanding'
                      : 'Closes the issue',
                ),
              ),
              LabeledField(
                label: 'Return date',
                child: DateField(
                  value: _returnDate,
                  firstDate: issue.issueDate,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _returnDate = d ?? DateTime.now()),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          LabeledField(
            label: 'Condition on return',
            required: true,
            child: AppDropdown<String>(
              value: _condition,
              items: [
                for (final entry in _conditions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => _condition = v ?? 'GOOD'),
            ),
          ),
          if (_condition != 'GOOD') ...[
            const SizedBox(height: Insets.md),
            NoticeBar(
              tone: _condition == 'NEEDS_CALIBRATION' ? NoticeTone.warning : NoticeTone.danger,
              icon: _condition == 'NEEDS_CALIBRATION'
                  ? Icons.schedule_rounded
                  : Icons.report_problem_outlined,
              message: switch (_condition) {
                'NEEDS_CALIBRATION' =>
                  'The tool goes back into store and is added to the calibration schedule for today.',
                'DAMAGED' =>
                  'The quantity leaves available stock and a damage record is raised for approval.',
                _ =>
                  'The quantity is written off the fleet and a loss record is raised for approval.',
              },
            ),
          ],
          const SizedBox(height: Insets.md),
          LabeledField(
            label: 'Remarks',
            required: _condition != 'GOOD',
            hint: _condition == 'GOOD'
                ? 'Optional'
                : 'Describe what happened — this becomes the reason on the record',
            child: AppTextField(
              controller: _remarksController,
              hintText: _condition == 'DAMAGED'
                  ? 'e.g. Insert seat chipped during setup'
                  : 'Optional note',
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_condition != 'GOOD' && _remarksController.text.trim().length < 3) {
      context.toast('Describe the condition so the record has a reason', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final updated = await ref.read(issuesRepositoryProvider).returnTool(
            widget.issue.id,
            qty: _qty,
            returnDate: _returnDate,
            condition: _condition,
            remarks: _remarksController.text.trim(),
          );

      invalidateStockViews(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);

      final extra = updated.maintenanceRecordNo != null
          ? ' · ${updated.maintenanceRecordNo} raised'
          : '';
      context.toast(
        'Returned $_qty × ${widget.issue.tool.toolCode} from ${widget.issue.employee.name}$extra',
        kind: _condition == 'GOOD' ? ToastKind.success : ToastKind.warning,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}

/// Push a due date out, with a mandatory reason for the audit trail.
Future<bool> showExtendDialog(BuildContext context, WidgetRef ref, ToolIssue issue) async {
  final reasonController = TextEditingController();
  DateTime? newDate = (issue.dueDate ?? DateTime.now()).add(const Duration(days: 2));

  final result = await showAppDialog<bool>(
    context,
    StatefulBuilder(
      builder: (context, setState) => AppDialog(
        title: 'Extend Due Date',
        subtitle: '${issue.issueNo} · currently due ${Fmt.date(issue.dueDate)}',
        icon: Icons.event_repeat_rounded,
        width: 460,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () async {
              if (newDate == null) return;
              if (reasonController.text.trim().length < 3) {
                context.toast('A reason is required to extend a due date',
                    kind: ToastKind.warning);
                return;
              }
              final ok = await runWithProgress(
                context,
                () => ref.read(issuesRepositoryProvider).extend(
                      issue.id,
                      dueDate: newDate!,
                      reason: reasonController.text.trim(),
                    ),
                successMessage: 'Due date moved to ${Fmt.date(newDate)}',
              );
              if (ok != null) {
                invalidateStockViews(ref);
                if (context.mounted) Navigator.of(context).pop(true);
              }
            },
            child: const Text('Extend'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'New due date',
              required: true,
              child: DateField(
                value: newDate,
                firstDate: (issue.dueDate ?? DateTime.now()).add(const Duration(days: 1)),
                onChanged: (d) => setState(() => newDate = d),
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Reason',
              required: true,
              hint: 'Recorded against the issue and in the audit trail',
              child: AppTextField(
                controller: reasonController,
                hintText: 'e.g. Job extended to second shift',
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  reasonController.dispose();
  return result ?? false;
}
