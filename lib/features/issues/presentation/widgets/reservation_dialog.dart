import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../shell/data/masters_repository.dart';
import '../../../tools/data/tools_repository.dart';
import '../../data/issues_repository.dart';
import 'issue_dialog.dart';

/// Hold stock for a job that has not started yet — the RFQ's "Tool Reservation".
///
/// A reservation moves the quantity out of `available` into `reserved`, so it
/// cannot be issued to somebody else in the meantime, without pretending the
/// tool has left the store. Issuing against the reservation later releases the
/// hold and consumes it in one transaction.
Future<bool> showReservationDialog(BuildContext context, WidgetRef ref, {int? toolId}) async {
  final result = await showAppDialog<bool>(context, _ReservationDialog(preselectedToolId: toolId));
  return result ?? false;
}

class _ReservationDialog extends ConsumerStatefulWidget {
  const _ReservationDialog({this.preselectedToolId});

  final int? preselectedToolId;

  @override
  ConsumerState<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends ConsumerState<_ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  int? _toolId;
  int? _employeeId;
  int? _locationId;
  int _qty = 1;
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _toolId = widget.preselectedToolId;
    final today = DateTime.now();
    _fromDate = today;
    // A week is the usual shift-planning horizon; the store keeper can shorten it.
    _toDate = today.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(toolOptionsProvider);
    final masters = ref.watch(masterBootstrapProvider);
    final selectedTool = findTool(tools.valueOrNull, _toolId);

    return AppDialog(
      title: 'Reserve Tool',
      subtitle: 'Hold stock for an upcoming job without issuing it',
      icon: Icons.event_available_outlined,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Reserve'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Tool',
              required: true,
              hint: selectedTool?.availabilityHint,
              child: tools.when(
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
                            Expanded(child: Text(tool.label, overflow: TextOverflow.ellipsis)),
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

            if (selectedTool != null && selectedTool.availableQty == 0) ...[
              const SizedBox(height: Insets.md),
              const NoticeBar(
                tone: NoticeTone.danger,
                icon: Icons.block_rounded,
                message: 'Nothing is available in store to hold. Receive a purchase or collect '
                    'an outstanding issue first.',
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
                  LabeledField(
                    label: 'Reserved for',
                    required: true,
                    child: AppDropdown<int>(
                      value: _employeeId,
                      hint: 'Select an employee',
                      items: [
                        for (final e in data.employees)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.name}${e.empCode.isEmpty ? '' : ' · ${e.empCode}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _employeeId = value;
                        // Default the station to where this employee normally works.
                        final employee =
                            data.employees.where((e) => e.id == value).firstOrNull;
                        _locationId ??= employee?.defaultLocationId;
                      }),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  FieldRow(
                    children: [
                      LabeledField(
                        label: 'Station',
                        hint: 'Where the job will run',
                        child: AppDropdown<int>(
                          value: _locationId,
                          hint: 'Optional',
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
                          min: 1,
                          max: selectedTool?.availableQty,
                          onChanged: (value) => setState(() => _qty = value),
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
                  label: 'Needed from',
                  required: true,
                  child: DateField(
                    value: _fromDate,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _fromDate = value;
                        // Keep the window valid: the API refuses toDate < fromDate.
                        if (_toDate.isBefore(value)) _toDate = value;
                      });
                    },
                  ),
                ),
                LabeledField(
                  label: 'Needed until',
                  required: true,
                  hint: 'Released automatically the day after this',
                  child: DateField(
                    value: _toDate,
                    firstDate: _fromDate,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _toDate = value);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Purpose',
              child: AppTextField(
                controller: _purposeController,
                hintText: 'e.g. Line B changeover, week 37',
                maxLines: 2,
              ),
            ),

            const SizedBox(height: Insets.md),
            NoticeBar(
              tone: NoticeTone.info,
              icon: Icons.info_outline_rounded,
              message: 'The quantity leaves available stock straight away and is held under '
                  '${Fmt.date(_fromDate)} — ${Fmt.date(_toDate)}. Issuing against the '
                  'reservation consumes the hold; cancelling or letting it expire returns it '
                  'to store.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_toolId == null) {
      context.toast('Select a tool', kind: ToastKind.warning);
      return;
    }
    if (_employeeId == null) {
      context.toast('Select who the tool is reserved for', kind: ToastKind.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      final saved = await ref.read(issuesRepositoryProvider).reserve(
            toolId: _toolId!,
            employeeId: _employeeId!,
            qty: _qty,
            fromDate: _fromDate,
            toDate: _toDate,
            locationId: _locationId,
            purpose: _purposeController.text.trim(),
          );

      // A reservation moves stock, so every view that shows a quantity is stale.
      invalidateStockViews(ref);
      ref
        ..invalidate(reservationsProvider)
        ..invalidate(activeReservationsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        '${saved.reservationNo}: ${saved.qty} × ${saved.tool.name} held for '
        '${saved.employeeName ?? 'the job'}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }
}
