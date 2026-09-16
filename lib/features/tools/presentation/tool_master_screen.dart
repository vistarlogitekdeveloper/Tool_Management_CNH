import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_grid.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/enums.dart';
import '../../../models/tool.dart';
import '../../auth/data/auth_controller.dart';
import '../../reports/presentation/widgets/export_menu.dart';
import '../../shell/data/masters_repository.dart';
import '../data/tools_repository.dart';
import 'widgets/tool_detail_sheet.dart';
import 'widgets/tool_form_dialog.dart';

/// Tool Master Database — the single source of truth for every tool, its
/// specification, drawing and home location.
class ToolMasterScreen extends ConsumerStatefulWidget {
  const ToolMasterScreen({super.key, this.initialToolId});

  final int? initialToolId;

  @override
  ConsumerState<ToolMasterScreen> createState() => _ToolMasterScreenState();
}

class _ToolMasterScreenState extends ConsumerState<ToolMasterScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialToolId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showToolDetail(context, ref, widget.initialToolId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final query = ref.watch(toolQueryProvider);
    final list = ref.watch(toolsListProvider);
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Tool Master Database',
          title: 'Tool Master Database',
          subtitle: 'Single source of truth — open any tool for its full record',
          actions: [
            if (user?.can(P.reportsExport) ?? false)
              ExportButton(reportKey: 'inventory', label: 'Export'),
            if (user?.can(P.toolCreate) ?? false)
              FilledButton.icon(
                onPressed: () => showToolFormDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add New Tool'),
              ),
          ],
        ),

        FilterBar(
          controls: [
            SearchField(
              controller: _searchController,
              hintText: 'Search name, part no or tool ID…',
              width: 280,
              onChanged: (value) =>
                  ref.read(toolQueryProvider.notifier).update((q) => q.copyWith(q: value)),
            ),
            if (masters != null) ...[
              FilterDropdown<int?>(
                value: query.categoryId,
                hint: 'All categories',
                onChanged: (value) => ref.read(toolQueryProvider.notifier).update(
                      (q) => value == null
                          ? q.copyWith(clearCategory: true)
                          : q.copyWith(categoryId: value),
                    ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                  for (final c in masters.categories)
                    DropdownMenuItem<int?>(
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
              ),
              FilterDropdown<int?>(
                value: query.locationId,
                hint: 'All locations',
                width: 190,
                onChanged: (value) => ref.read(toolQueryProvider.notifier).update(
                      (q) => value == null
                          ? q.copyWith(clearLocation: true)
                          : q.copyWith(locationId: value),
                    ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All locations')),
                  for (final l in masters.locations)
                    DropdownMenuItem<int?>(
                      value: l.id,
                      child: Text(l.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ],
            FilterDropdown<bool?>(
              value: query.lowStock,
              hint: 'All stock levels',
              width: 165,
              onChanged: (value) => ref.read(toolQueryProvider.notifier).update(
                    (q) => value == null ? q.copyWith(clearLowStock: true) : q.copyWith(lowStock: value),
                  ),
              items: const [
                DropdownMenuItem<bool?>(value: null, child: Text('All stock levels')),
                DropdownMenuItem<bool?>(value: true, child: Text('Low stock only')),
                DropdownMenuItem<bool?>(value: false, child: Text('Healthy stock')),
              ],
            ),
          ],
          trailing: query.hasFilters
              ? TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(toolQueryProvider.notifier).state = const ToolQuery();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: const Text('Clear'),
                )
              : null,
        ),

        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<Tool>>(
            value: list,
            onRetry: () => ref.invalidate(toolsListProvider),
            loading: const GridSkeleton(),
            data: (paged) => Column(
              children: [
                DataGrid<Tool>(
                  rows: paged.items,
                  minWidth: 1140,
                  sortKey: query.sort,
                  sortAscending: query.order == 'asc',
                  onSort: (key) =>
                      ref.read(toolQueryProvider.notifier).update((q) => q.withSort(key)),
                  onRowTap: (row) => showToolDetail(context, ref, row.id),
                  emptyMessage: query.hasFilters
                      ? 'No tools match your filters.'
                      : 'The tool master is empty. Add the first tool to get started.',
                  emptyIcon: Icons.inventory_2_outlined,
                  mobileCardBuilder: _mobileCard,
                  columns: _columns(),
                ),
                PaginationBar(
                  meta: paged.meta,
                  unit: 'tools',
                  onPage: (page) =>
                      ref.read(toolQueryProvider.notifier).update((q) => q.copyWith(page: page)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<GridColumn<Tool>> _columns() => [
        GridColumn<Tool>(
          label: 'Tool ID',
          width: 110,
          sortKey: 'toolCode',
          cell: (row) => MonoText(row.toolCode),
        ),
        GridColumn<Tool>(
          label: 'Tool Name',
          flex: 4,
          sortKey: 'name',
          cell: (row) => TwoLineCell(primary: row.name, secondary: row.manufacturer),
        ),
        GridColumn<Tool>(
          label: 'Category',
          width: 130,
          sortKey: 'category',
          cell: (row) => CategoryChip(name: row.category.name, colour: row.category.colour, dense: true),
        ),
        GridColumn<Tool>(
          label: 'Part No.',
          flex: 2,
          sortKey: 'partNumber',
          hideBelow: ScreenSize.desktop,
          cell: (row) => Text(
            row.partNumber ?? '—',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<Tool>(
          label: 'Specification',
          flex: 3,
          hideBelow: ScreenSize.wide,
          cell: (row) => Text(
            row.specification ?? '—',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<Tool>(
          label: 'Drawing',
          width: 92,
          hideBelow: ScreenSize.desktop,
          cell: (row) => row.drawingAttachmentId == null
              ? const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.muted))
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 14, color: AppColors.brand),
                    SizedBox(width: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
        GridColumn<Tool>(
          label: 'Location',
          flex: 2,
          sortKey: 'location',
          hideBelow: ScreenSize.tablet,
          cell: (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  row.displayLocation,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        GridColumn<Tool>(
          label: 'Total',
          width: 82,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'totalQty',
          cell: (row) => Text(
            Fmt.int_(row.stock.total),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        GridColumn<Tool>(
          label: 'Available',
          width: 96,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'availableQty',
          cell: (row) => Text(
            Fmt.int_(row.stock.available),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: row.stock.isLowStock ? AppColors.redInk : AppColors.ink,
            ),
          ),
        ),
        GridColumn<Tool>(
          label: 'Status',
          width: 96,
          cell: (row) => StatusChip(row.stock.statusCode),
        ),
      ];

  Widget _mobileCard(Tool row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MonoText(row.toolCode)),
              CategoryChip(name: row.category.name, colour: row.category.colour, dense: true),
              const SizedBox(width: 6),
              StatusChip(row.stock.statusCode, dense: true),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            row.name,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          if (row.specification != null)
            Text(
              row.specification!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.stock.available} of ${row.stock.total} available · ${row.displayLocation}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: 74,
                child: LevelBar(
                  percent: row.stock.stockPercent,
                  colour: LevelBar.colourFor(
                    percent: row.stock.stockPercent,
                    isLow: row.stock.isLowStock,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
