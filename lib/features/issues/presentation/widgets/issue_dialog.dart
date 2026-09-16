import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../models/issue.dart';
import '../../../../models/master_data.dart';
import '../../../../models/tool.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../data/issues_repository.dart';

/// "Issue in one dialog" — pick tool, employee, station and due date. The
/// system blocks an issue larger than the stock on hand, and refuses an
/// instrument whose calibration is overdue.
/// Pass [reservation] to issue against a held quantity: the reservation is
/// consumed rather than the issue being charged again to available stock. That
/// is the whole point of the reserve → issue flow, and it was previously
/// reachable only by posting `reservationId` to the API by hand.
Future<bool> showIssueDialog(
  BuildContext context,
  WidgetRef ref, {
  int? toolId,
  Reservation? reservation,
}) async {
  final result = await showAppDialog<bool>(
    context,
    _IssueDialog(preselectedToolId: toolId ?? reservation?.tool.id, reservation: reservation),
  );
  return result ?? false;
}

class _IssueDialog extends ConsumerStatefulWidget {
  const _IssueDialog({this.preselectedToolId, this.reservation});

  final int? preselectedToolId;
  final Reservation? reservation;

  @override
  ConsumerState<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends ConsumerState<_IssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _workOrderController = TextEditingController();

  int? _toolId;
  int? _employeeId;
  int? _departmentId;
  int? _locationId;
  int _qty = 1;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _toolId = widget.preselectedToolId;

    // Default the return date from the configured policy, falling back to 2 days.
    final configured = ref.read(settingValueProvider('issue.default_return_days'));
    final days = configured is num ? configured.toInt() : 2;
    _dueDate = DateTime.now().add(Duration(days: days));

    // Issuing against a reservation: carry across everything the reservation
    // already decided, and let the due date follow the reservation window when it
    // ends later than the default.
    final held = widget.reservation;
    if (held != null) {
      _qty = held.qty;
      _employeeId = held.employeeId;
      _locationId = held.locationId;
      if (held.toDate != null && held.toDate!.isAfter(_dueDate!)) _dueDate = held.toDate;
      if (held.purpose != null && held.purpose!.isNotEmpty) {
        _purposeController.text = held.purpose!;
      }
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _workOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(toolOptionsProvider);
    final masters = ref.watch(masterBootstrapProvider);
    final selectedTool = tools.valueOrNull?.where((t) => t.id == _toolId).firstOrNull;

    return AppDialog(
      title: 'Issue Tool',
      subtitle: 'Stock updates the moment you confirm',
      icon: Icons.swap_horiz_rounded,
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
              : const Text('Confirm Issue'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.reservation != null) ...[
              NoticeBar(
                tone: NoticeTone.info,
                icon: Icons.event_available_outlined,
                message: 'Issuing against ${widget.reservation!.reservationNo} — '
                    '${widget.reservation!.qty} unit(s) already held'
                    '${widget.reservation!.employeeName == null ? '' : ' for ${widget.reservation!.employeeName}'}'
                    '. The hold is consumed rather than charged to available stock again.',
              ),
            ],
            LabeledField(
              label: 'Tool',
              required: true,
              hint: widget.reservation != null
                  ? 'Fixed by the reservation'
                  : selectedTool?.availabilityHint,
              child: widget.reservation != null
                  ? _lockedTool(selectedTool, widget.reservation!)
                  : tools.when(
                loading: () => const LinearProgressIndicator(minHeight: 44),
                error: (e, _) => Text('Could not load tools: $e',
                    style: const TextStyle(color: AppColors.red, fontSize: 12)),
                data: (options) => AppDropdown<int>(
                  value: _toolId,
                  hint: 'Select a tool',
                  items: [
                    for (final tool in options)
                      DropdownMenuItem(
                        value: tool.id,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tool.label, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: Insets.sm),
                            Text(
                              '${tool.availableQty} avl',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: tool.availableQty <= tool.minStock
                                    ? AppColors.red
                                    : AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _toolId = value;
                    final tool = options.where((t) => t.id == value).firstOrNull;
                    if (tool != null && _qty > tool.availableQty) {
                      _qty = tool.availableQty > 0 ? tool.availableQty : 1;
                    }
                  }),
                ),
              ),
            ),
            if (widget.reservation == null &&
                selectedTool != null &&
                selectedTool.availableQty == 0) ...[
              const SizedBox(height: Insets.md),
              const NoticeBar(
                tone: NoticeTone.danger,
                icon: Icons.block_rounded,
                message: 'This tool has nothing available in store. Receive a purchase or '
                    'collect an outstanding issue before issuing it again.',
              ),
            ],
            const SizedBox(height: Insets.lg),
            masters.when(
              loading: () => const LinearProgressIndicator(minHeight: 44),
              error: (e, _) => Text('Could not load master data: $e',
                  style: const TextStyle(color: AppColors.red, fontSize: 12)),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FieldRow(
                    children: [
                      LabeledField(
                        label: 'Employee',
                        required: true,
                        child: AppDropdown<int>(
                          value: _employeeId,
                          hint: 'Who is taking it?',
                          items: [
                            for (final e in data.employees)
                              DropdownMenuItem(
                                value: e.id,
                                child: Text(e.label, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _employeeId = value;
                            // Default the department and station from the employee
                            // record, so the storekeeper types nothing extra.
                            final emp = data.employees.where((e) => e.id == value).firstOrNull;
                            _departmentId ??= emp?.departmentId;
                            _locationId ??= emp?.defaultLocationId;
                          }),
                        ),
                      ),
                      LabeledField(
                        label: 'Department',
                        child: AppDropdown<int>(
                          value: _departmentId,
                          hint: 'Department',
                          items: [
                            for (final d in data.departments)
                              DropdownMenuItem(value: d.id, child: Text(d.name)),
                          ],
                          onChanged: (value) => setState(() => _departmentId = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  FieldRow(
                    children: [
                      LabeledField(
                        label: 'Station',
                        child: AppDropdown<int>(
                          value: _locationId,
                          hint: 'Where will it be used?',
                          items: [
                            for (final l in data.locations)
                              DropdownMenuItem(
                                value: l.id,
                                child: Text(l.name, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (value) => setState(() => _locationId = value),
                        ),
                      ),
                      LabeledField(
                        label: 'Quantity',
                        required: true,
                        child: QuantityField(
                          value: _qty,
                          max: _maxIssuable(selectedTool),
                          onChanged: (v) => setState(() => _qty = v),
                          helper: _quantityHelper(selectedTool),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Issue date',
                  child: DateField(
                    value: _issueDate,
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _issueDate = d ?? DateTime.now()),
                  ),
                ),
                LabeledField(
                  label: 'Due back on',
                  required: true,
                  hint: _dueDate == null ? null : 'Returns ${Fmt.relativeDays(_dueDate)}',
                  child: DateField(
                    value: _dueDate,
                    firstDate: _issueDate,
                    onChanged: (d) => setState(() => _dueDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Purpose',
              child: AppTextField(
                controller: _purposeController,
                hintText: 'e.g. Slot milling — bracket line',
                maxLines: 2,
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Work order / job number',
              child: AppTextField(
                controller: _workOrderController,
                hintText: 'Optional',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_toolId == null) {
      context.toast('Select a tool first', kind: ToastKind.warning);
      return;
    }
    if (_employeeId == null) {
      context.toast('Select the employee taking the tool', kind: ToastKind.warning);
      return;
    }
    if (_dueDate == null) {
      context.toast('Set a due date so the return can be tracked', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final issue = await ref.read(issuesRepositoryProvider).issue(
            IssueRequest(
              toolId: _toolId!,
              employeeId: _employeeId!,
              qty: _qty,
              departmentId: _departmentId,
              locationId: _locationId,
              issueDate: _issueDate,
              dueDate: _dueDate,
              purpose: _purposeController.text.trim(),
              workOrderNo: _workOrderController.text.trim(),
              reservationId: widget.reservation?.id,
            ),
          );

      _invalidate(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        '${issue.issueNo}: issued $_qty × ${issue.tool.name} to ${issue.employee.name}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }

  /// Anything that shows stock or issue counts is now stale.
  /// A reservation has already moved its quantity out of `available` into
  /// `reserved`, so the ceiling for this issue is what is on the shelf *plus*
  /// what is being held for it. Capping at availableQty alone would block the
  /// issue the reservation was created to allow.
  int? _maxIssuable(ToolOption? tool) {
    if (tool == null) return null;
    final held = widget.reservation?.qty ?? 0;
    return tool.availableQty + held;
  }

  String? _quantityHelper(ToolOption? tool) {
    if (tool == null) return null;
    final held = widget.reservation?.qty;
    if (held == null) return 'Maximum ${tool.availableQty} available';
    return '$held held on this reservation'
        '${tool.availableQty > 0 ? ', plus ${tool.availableQty} in store' : ''}';
  }

  /// The tool cannot be swapped while issuing against a reservation — the hold
  /// is for this tool, and changing it here would leave the reservation
  /// stranded in the reserved bucket.
  Widget _lockedTool(ToolOption? tool, Reservation held) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.hover,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(Insets.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.muted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                tool?.label ?? '${held.tool.toolCode} — ${held.tool.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  static void _invalidate(WidgetRef ref) {
    ref
      ..invalidate(reservationsProvider)
      ..invalidate(activeReservationsProvider)
      ..invalidate(dashboardProvider)
      ..invalidate(issuesListProvider)
      ..invalidate(issueSummaryProvider)
      ..invalidate(inventoryListProvider)
      ..invalidate(inventorySummaryProvider)
      ..invalidate(lowStockProvider)
      ..invalidate(toolsListProvider)
      ..invalidate(toolOptionsProvider);
  }
}

/// Extension point used by other screens that need the same invalidation.
void invalidateStockViews(WidgetRef ref) {
  ref
    ..invalidate(reservationsProvider)
    ..invalidate(activeReservationsProvider)
    ..invalidate(dashboardProvider)
    ..invalidate(issuesListProvider)
    ..invalidate(issueSummaryProvider)
    ..invalidate(inventoryListProvider)
    ..invalidate(inventorySummaryProvider)
    ..invalidate(lowStockProvider)
    ..invalidate(valuationProvider)
    ..invalidate(toolsListProvider)
    ..invalidate(toolOptionsProvider);
}

/// Convenience for pickers that need a tool's live availability.
ToolOption? findTool(List<ToolOption>? options, int? id) =>
    id == null ? null : options?.where((t) => t.id == id).firstOrNull;

/// Employees filtered to a department, for the pickers that need it.
List<Employee> employeesIn(MasterBootstrap masters, int? departmentId) => departmentId == null
    ? masters.employees
    : masters.employees.where((e) => e.departmentId == departmentId).toList();
