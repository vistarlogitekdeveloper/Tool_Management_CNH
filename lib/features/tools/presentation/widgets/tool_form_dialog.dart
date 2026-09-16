import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../models/json.dart';
import '../../../../models/tool.dart';
import '../../../issues/presentation/widgets/issue_dialog.dart' show invalidateStockViews;
import '../../../shell/data/masters_repository.dart';
import '../../../../core/widgets/attachment_field.dart';
import '../../../files/data/files_repository.dart';
import '../../data/tools_repository.dart';

/// Register a new tool, or edit an existing one. Covers every field the RFQ's
/// Tool Master Database row lists, plus the calibration and life-cycle control
/// the later modules depend on.
Future<bool> showToolFormDialog(BuildContext context, WidgetRef ref, {Tool? existing}) async {
  final result = await showAppDialog<bool>(context, _ToolFormDialog(existing: existing));
  return result ?? false;
}

class _ToolFormDialog extends ConsumerStatefulWidget {
  const _ToolFormDialog({this.existing});

  final Tool? existing;

  @override
  ConsumerState<_ToolFormDialog> createState() => _ToolFormDialogState();
}

class _ToolFormDialogState extends ConsumerState<_ToolFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _partNumber;
  late final TextEditingController _specification;
  late final TextEditingController _manufacturer;
  late final TextEditingController _unitCost;
  late final TextEditingController _minStock;
  late final TextEditingController _reorderLevel;
  late final TextEditingController _reorderQty;
  late final TextEditingController _openingQty;
  late final TextEditingController _expectedLife;
  late final TextEditingController _remarks;

  int? _categoryId;
  int? _locationId;
  bool _calibrationRequired = false;
  int _calibrationMonths = 6;
  DateTime? _purchaseDate;
  bool _submitting = false;

  // The RFQ asks for a drawing (PDF/DWG) and a tool image on the master record.
  // Both are uploaded up front and referenced by id: POST /tools and PATCH
  // /tools/:id each accept drawingAttachmentId / imageAttachmentId, and the
  // service re-tags the attachment onto the tool once it is saved.
  String? _drawingAttachmentId;
  String? _imageAttachmentId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _drawingAttachmentId = t?.drawingAttachmentId;
    _imageAttachmentId = t?.imageAttachmentId;
    _name = TextEditingController(text: t?.name ?? '');
    _partNumber = TextEditingController(text: t?.partNumber ?? '');
    _specification = TextEditingController(text: t?.specification ?? '');
    _manufacturer = TextEditingController(text: t?.manufacturer ?? '');
    _unitCost = TextEditingController(text: t == null ? '' : t.unitCost.toStringAsFixed(0));
    _minStock = TextEditingController(text: '${t?.stock.minStock ?? 0}');
    _reorderLevel = TextEditingController(text: '${t?.stock.reorderLevel ?? 0}');
    _reorderQty = TextEditingController(text: '${t?.stock.reorderQty ?? 0}');
    _openingQty = TextEditingController(text: '0');
    _expectedLife = TextEditingController(
      text: t?.lifecycle.expectedCycles == null ? '' : '${t!.lifecycle.expectedCycles}',
    );
    _remarks = TextEditingController();
    _categoryId = t?.category.id;
    _locationId = t?.location?.id;
    _calibrationRequired = t?.calibration.required ?? false;
    _calibrationMonths = t?.calibration.frequencyMonths ?? 6;
    _purchaseDate = t?.purchaseDate;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _partNumber, _specification, _manufacturer, _unitCost, _minStock,
      _reorderLevel, _reorderQty, _openingQty, _expectedLife, _remarks,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;

    return AppDialog(
      title: _isEdit ? 'Edit Tool' : 'Add New Tool',
      subtitle: _isEdit ? widget.existing!.toolCode : 'A tool ID is generated automatically',
      icon: Icons.inventory_2_outlined,
      width: 660,
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
              : Text(_isEdit ? 'Save Changes' : 'Add Tool'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionLabel('Identification'),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Tool name',
                  required: true,
                  child: AppTextField(
                    controller: _name,
                    hintText: 'e.g. Ball End Mill 8mm',
                    autofocus: !_isEdit,
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Enter a tool name' : null,
                  ),
                ),
                LabeledField(
                  label: 'Category',
                  required: true,
                  child: AppDropdown<int>(
                    value: _categoryId,
                    hint: 'Select a category',
                    items: [
                      for (final c in masters?.categories ?? [])
                        DropdownMenuItem<int>(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(color: c.colour, shape: BoxShape.circle),
                              ),
                              Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Part number',
                  child: AppTextField(controller: _partNumber, hintText: 'e.g. BEM-08-2F'),
                ),
                LabeledField(
                  label: 'Manufacturer',
                  child: AppTextField(controller: _manufacturer, hintText: 'e.g. Kennametal'),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Specification',
              child: AppTextField(
                controller: _specification,
                hintText: 'e.g. 2 flute, TiAlN coated, 8mm dia',
                maxLines: 2,
              ),
            ),

            const SizedBox(height: Insets.xl),
            _sectionLabel('Stock control'),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Home location',
                  child: AppDropdown<int>(
                    value: _locationId,
                    hint: 'Where it lives',
                    items: [
                      for (final l in masters?.locations ?? [])
                        DropdownMenuItem<int>(
                          value: l.id,
                          child: Text(l.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _locationId = v),
                  ),
                ),
                LabeledField(
                  label: 'Unit cost (₹)',
                  child: AppTextField(
                    controller: _unitCost,
                    hintText: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Minimum stock',
                  required: true,
                  hint: 'Below this, the tool raises a low-stock alert',
                  child: AppTextField(
                    controller: _minStock,
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                  ),
                ),
                LabeledField(
                  label: 'Reorder level',
                  hint: 'Suggests a purchase order',
                  child: AppTextField(controller: _reorderLevel, keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            FieldRow(
              children: [
                LabeledField(
                  label: 'Reorder quantity',
                  hint: 'Default order size',
                  child: AppTextField(controller: _reorderQty, keyboardType: TextInputType.number),
                ),
                if (!_isEdit)
                  LabeledField(
                    label: 'Opening stock',
                    hint: 'Recorded as an opening movement in the ledger',
                    child: AppTextField(
                      controller: _openingQty,
                      keyboardType: TextInputType.number,
                    ),
                  )
                else
                  LabeledField(
                    label: 'Purchase date',
                    child: DateField(
                      value: _purchaseDate,
                      clearable: true,
                      lastDate: DateTime.now(),
                      onChanged: (d) => setState(() => _purchaseDate = d),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: Insets.xl),
            _sectionLabel('Calibration & life'),
            SwitchListTile.adaptive(
              value: _calibrationRequired,
              onChanged: (v) => setState(() => _calibrationRequired = v),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: const Text(
                'Calibration controlled',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Instruments and gauges. An overdue calibration blocks the tool from being issued.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
              ),
            ),
            if (_calibrationRequired) ...[
              const SizedBox(height: Insets.md),
              FieldRow(
                children: [
                  LabeledField(
                    label: 'Calibration frequency',
                    required: true,
                    child: AppDropdown<int>(
                      value: _calibrationMonths,
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('Every 3 months')),
                        DropdownMenuItem(value: 6, child: Text('Every 6 months')),
                        DropdownMenuItem(value: 12, child: Text('Every 12 months')),
                        DropdownMenuItem(value: 24, child: Text('Every 24 months')),
                      ],
                      onChanged: (v) => setState(() => _calibrationMonths = v ?? 6),
                    ),
                  ),
                  LabeledField(
                    label: 'Expected life (cycles)',
                    hint: 'Drives the life-cycle report',
                    child: AppTextField(
                      controller: _expectedLife,
                      keyboardType: TextInputType.number,
                      hintText: 'Optional',
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: Insets.md),
              LabeledField(
                label: 'Expected life (cycles)',
                hint: 'Used by the tool life-cycle and replacement report',
                child: AppTextField(
                  controller: _expectedLife,
                  keyboardType: TextInputType.number,
                  hintText: 'Optional',
                ),
              ),
            ],

            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Remarks',
              child: AppTextField(controller: _remarks, hintText: 'Optional', maxLines: 2),
            ),
            const SizedBox(height: Insets.xl),
            _sectionLabel('Documents'),
            const SizedBox(height: Insets.md),
            FieldRow(
              children: [
                AttachmentField(
                  category: AttachmentCategory.drawing,
                  attachmentId: _drawingAttachmentId,
                  enabled: !_submitting,
                  entityType: _isEdit ? 'tool' : null,
                  entityId: _isEdit ? widget.existing!.id.toString() : null,
                  onChanged: (id) => setState(() => _drawingAttachmentId = id),
                ),
                AttachmentField(
                  category: AttachmentCategory.image,
                  label: 'Tool photo',
                  attachmentId: _imageAttachmentId,
                  enabled: !_submitting,
                  entityType: _isEdit ? 'tool' : null,
                  entityId: _isEdit ? widget.existing!.id.toString() : null,
                  onChanged: (id) => setState(() => _imageAttachmentId = id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      context.toast('Select a category', kind: ToastKind.warning);
      return;
    }

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'categoryId': _categoryId,
      'partNumber': _nullIfBlank(_partNumber.text),
      'specification': _nullIfBlank(_specification.text),
      'manufacturer': _nullIfBlank(_manufacturer.text),
      'unitCost': double.tryParse(_unitCost.text.trim()) ?? 0,
      'locationId': _locationId,
      'minStock': int.tryParse(_minStock.text.trim()) ?? 0,
      'reorderLevel': int.tryParse(_reorderLevel.text.trim()) ?? 0,
      'reorderQty': int.tryParse(_reorderQty.text.trim()) ?? 0,
      'calibrationRequired': _calibrationRequired,
      'calibrationFrequencyMonths': _calibrationRequired ? _calibrationMonths : null,
      'expectedLifeCycles': int.tryParse(_expectedLife.text.trim()),
      'remarks': _nullIfBlank(_remarks.text),
      if (_purchaseDate != null) 'purchaseDate': _iso(_purchaseDate!),
      'drawingAttachmentId': _drawingAttachmentId,
      'imageAttachmentId': _imageAttachmentId,
      if (!_isEdit) 'openingQty': int.tryParse(_openingQty.text.trim()) ?? 0,
    };

    setState(() => _submitting = true);
    try {
      final repo = ref.read(toolsRepositoryProvider);
      final Tool saved = _isEdit
          ? await repo.update(widget.existing!.id, payload)
          : await repo.create(payload);

      invalidateStockViews(ref);
      ref.invalidate(toolDetailProvider(saved.id));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.toast(
        _isEdit
            ? 'Saved ${saved.toolCode} — ${saved.name}'
            : 'Added ${saved.name} as ${saved.toolCode}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showApiError(error);
      }
    }
  }

  static Object? _nullIfBlank(String v) => v.trim().isEmpty ? null : v.trim();

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Shared by callers that build a payload without the dialog.
Json toolPayload({required String name, required int categoryId}) =>
    {'name': name, 'categoryId': categoryId};
