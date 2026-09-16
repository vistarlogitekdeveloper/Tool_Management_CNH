import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/master_data.dart';
import '../../../shell/data/masters_repository.dart';

/// Master data behind every dropdown: categories, locations, departments,
/// employees and vendors. Records are deactivated, never deleted, so historical
/// transactions keep resolving.
class MastersTab extends ConsumerStatefulWidget {
  const MastersTab({super.key});

  @override
  ConsumerState<MastersTab> createState() => _MastersTabState();
}

class _MastersTabState extends ConsumerState<MastersTab> {
  String _entity = 'categories';

  static const _entities = <String, String>{
    'categories': 'Tool categories',
    'locations': 'Locations',
    'departments': 'Departments',
    'employees': 'Employees',
    'vendors': 'Vendors & suppliers',
  };

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(masterBootstrapProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            controls: [
              SegmentedFilter<String>(
                value: _entity,
                onChanged: (v) => setState(() => _entity = v),
                segments: [
                  for (final entry in _entities.entries)
                    (value: entry.key, label: entry.value, count: null),
                ],
              ),
            ],
          ),
          SectionCard(
            title: _entities[_entity]!,
            trailing: FilledButton.icon(
              onPressed: () => _showForm(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
            ),
            padding: EdgeInsets.zero,
            child: AsyncView<MasterBootstrap>(
              value: bootstrap,
              onRetry: () => ref.invalidate(masterBootstrapProvider),
              loading: const GridSkeleton(),
              data: (data) => switch (_entity) {
                'categories' => _categories(data.categories),
                'locations' => _locations(data.locations),
                'departments' => _departments(data.departments),
                'employees' => _employees(data.employees),
                _ => _vendors(data.vendors),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categories(List<ToolCategory> rows) => DataGrid<ToolCategory>(
        rows: rows,
        minWidth: 700,
        emptyMessage: 'No categories yet.',
        mobileCardBuilder: (row) => TwoLineCell(
          primary: row.name,
          secondary: '${row.code} · ${row.toolCount ?? 0} tool(s)',
        ),
        columns: [
          GridColumn<ToolCategory>(
            label: 'Colour',
            width: 78,
            cell: (row) => Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: row.colour, borderRadius: BorderRadius.circular(5)),
            ),
          ),
          GridColumn<ToolCategory>(label: 'Code', width: 110, cell: (row) => MonoText(row.code)),
          GridColumn<ToolCategory>(
            label: 'Name',
            flex: 2,
            cell: (row) => TwoLineCell(primary: row.name, secondary: row.description),
          ),
          GridColumn<ToolCategory>(
            label: 'Tools',
            width: 88,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text('${row.toolCount ?? 0}', style: const TextStyle(fontSize: 13)),
          ),
          GridColumn<ToolCategory>(
            label: 'Status',
            width: 106,
            cell: (row) => StatusChip(row.isActive ? 'ACTIVE' : 'INACTIVE', dense: true),
          ),
        ],
      );

  Widget _locations(List<PlantLocation> rows) => DataGrid<PlantLocation>(
        rows: rows,
        minWidth: 800,
        emptyMessage: 'No locations yet.',
        mobileCardBuilder: (row) => TwoLineCell(primary: row.name, secondary: row.path),
        columns: [
          GridColumn<PlantLocation>(label: 'Code', width: 110, cell: (row) => MonoText(row.code)),
          GridColumn<PlantLocation>(
            label: 'Name',
            flex: 2,
            cell: (row) => Text(row.name, style: const TextStyle(fontSize: 13)),
          ),
          GridColumn<PlantLocation>(
            label: 'Shop / line / station',
            flex: 3,
            cell: (row) => Text(
              row.path.isEmpty ? '—' : row.path,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          GridColumn<PlantLocation>(
            label: 'Tools',
            width: 84,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text('${row.toolCount ?? 0}', style: const TextStyle(fontSize: 13)),
          ),
          GridColumn<PlantLocation>(
            label: 'Type',
            width: 104,
            cell: (row) => row.isStore
                ? const StatusChip('ACTIVE', label: 'Store', dense: true)
                : const Text('Station', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ],
      );

  Widget _departments(List<Department> rows) => DataGrid<Department>(
        rows: rows,
        minWidth: 600,
        emptyMessage: 'No departments yet.',
        mobileCardBuilder: (row) => TwoLineCell(primary: row.name, secondary: row.code),
        columns: [
          GridColumn<Department>(label: 'Code', width: 110, cell: (row) => MonoText(row.code)),
          GridColumn<Department>(
            label: 'Name',
            flex: 2,
            cell: (row) => Text(row.name, style: const TextStyle(fontSize: 13)),
          ),
          GridColumn<Department>(
            label: 'Cost centre',
            flex: 1,
            cell: (row) => Text(
              row.costCentre ?? '—',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          GridColumn<Department>(
            label: 'Employees',
            width: 106,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text('${row.employeeCount ?? 0}', style: const TextStyle(fontSize: 13)),
          ),
        ],
      );

  Widget _employees(List<Employee> rows) => DataGrid<Employee>(
        rows: rows,
        minWidth: 820,
        emptyMessage: 'No employees yet.',
        mobileCardBuilder: (row) => TwoLineCell(
          primary: row.name,
          secondary: '${row.empCode} · ${row.departmentName ?? '—'}',
          leading: InitialsAvatar(row.initials, size: 30),
        ),
        columns: [
          GridColumn<Employee>(label: 'Code', width: 118, cell: (row) => MonoText(row.empCode)),
          GridColumn<Employee>(
            label: 'Name',
            flex: 3,
            cell: (row) => TwoLineCell(
              primary: row.name,
              secondary: row.designation,
              leading: InitialsAvatar(row.initials, size: 28),
            ),
          ),
          GridColumn<Employee>(
            label: 'Department',
            flex: 2,
            cell: (row) => Text(
              row.departmentName ?? '—',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          GridColumn<Employee>(
            label: 'Default station',
            flex: 2,
            cell: (row) => Text(
              row.defaultLocationName ?? '—',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          GridColumn<Employee>(
            label: 'Open issues',
            width: 110,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text(
              '${row.openIssues ?? 0}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (row.openIssues ?? 0) > 0 ? AppColors.brand : AppColors.muted,
              ),
            ),
          ),
        ],
      );

  Widget _vendors(List<Vendor> rows) => DataGrid<Vendor>(
        rows: rows,
        minWidth: 900,
        emptyMessage: 'No vendors yet.',
        mobileCardBuilder: (row) => TwoLineCell(
          primary: row.name,
          secondary: '${row.code} · ${row.roles.join(', ')}',
        ),
        columns: [
          GridColumn<Vendor>(label: 'Code', width: 128, cell: (row) => MonoText(row.code)),
          GridColumn<Vendor>(
            label: 'Name',
            flex: 3,
            cell: (row) => TwoLineCell(primary: row.name, secondary: row.contactPerson),
          ),
          GridColumn<Vendor>(
            label: 'Roles',
            flex: 2,
            cell: (row) => Wrap(
              spacing: 4,
              children: [
                for (final role in row.roles)
                  StatusChip(role, dense: true, palette: StatusPalette.slate),
              ],
            ),
          ),
          GridColumn<Vendor>(
            label: 'Contact',
            flex: 2,
            cell: (row) => Text(
              row.phone ?? row.email ?? '—',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GridColumn<Vendor>(
            label: 'Lead time',
            width: 100,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text(
              row.leadTimeDays == null ? '—' : '${row.leadTimeDays} d',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          GridColumn<Vendor>(
            label: 'POs',
            width: 76,
            numeric: true,
            align: Alignment.centerRight,
            cell: (row) => Text('${row.poCount ?? 0}', style: const TextStyle(fontSize: 13)),
          ),
        ],
      );

  /// One generic create form per entity — enough fields to add a record, with
  /// full editing available through the same endpoint.
  Future<void> _showForm(BuildContext context) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final extraController = TextEditingController();

    final saved = await showAppDialog<bool>(
      context,
      AppDialog(
        title: 'Add ${_entities[_entity]!.toLowerCase()}',
        icon: Icons.add_circle_outline_rounded,
        width: 480,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty || nameController.text.trim().length < 2) {
                context.toast('A code and a name are required', kind: ToastKind.warning);
                return;
              }

              final payload = <String, dynamic>{
                if (_entity == 'employees')
                  'empCode': codeController.text.trim()
                else
                  'code': codeController.text.trim(),
                'name': nameController.text.trim(),
                if (_entity == 'categories' && extraController.text.trim().isNotEmpty)
                  'colour': extraController.text.trim(),
                if (_entity == 'locations' && extraController.text.trim().isNotEmpty)
                  'shop': extraController.text.trim(),
                if (_entity == 'departments' && extraController.text.trim().isNotEmpty)
                  'costCentre': extraController.text.trim(),
                if (_entity == 'employees' && extraController.text.trim().isNotEmpty)
                  'designation': extraController.text.trim(),
                if (_entity == 'vendors') ...{
                  'isSupplier': true,
                  if (extraController.text.trim().isNotEmpty)
                    'contactPerson': extraController.text.trim(),
                },
              };

              final result = await runWithProgress(
                context,
                () => ref.read(mastersRepositoryProvider).create(_entity, payload),
                successMessage: 'Added ${nameController.text.trim()}',
              );
              if (result != null && context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: _entity == 'employees' ? 'Employee code' : 'Code',
              required: true,
              child: AppTextField(
                controller: codeController,
                hintText: switch (_entity) {
                  'categories' => 'e.g. CUT',
                  'locations' => 'e.g. LA-05',
                  'departments' => 'e.g. MACH',
                  'employees' => 'e.g. EMP-1010',
                  _ => 'e.g. V-SANDVIK',
                },
                autofocus: true,
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: 'Name',
              required: true,
              child: AppTextField(controller: nameController),
            ),
            const SizedBox(height: Insets.lg),
            LabeledField(
              label: switch (_entity) {
                'categories' => 'Colour (hex)',
                'locations' => 'Shop',
                'departments' => 'Cost centre',
                'employees' => 'Designation',
                _ => 'Contact person',
              },
              child: AppTextField(
                controller: extraController,
                hintText: _entity == 'categories' ? '#0b4da2' : 'Optional',
              ),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    nameController.dispose();
    extraController.dispose();

    if (saved ?? false) ref.invalidate(masterBootstrapProvider);
  }
}
