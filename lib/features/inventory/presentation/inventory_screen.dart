import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
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
import '../../../models/inventory.dart';
import '../../auth/data/auth_controller.dart';
import '../../reports/presentation/widgets/export_menu.dart';
import '../../shell/data/masters_repository.dart';
import '../../tools/presentation/widgets/tool_detail_sheet.dart';
import '../data/inventory_repository.dart';
import 'widgets/low_stock_panel.dart';
import 'widgets/stock_adjust_dialog.dart';

/// Inventory Management — stock levels, issued vs available, reorder points.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.lowStockOnly = false});

  final bool lowStockOnly;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  bool _showLowStockPanel = false;

  @override
  void initState() {
    super.initState();
    if (widget.lowStockOnly) {
      _showLowStockPanel = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inventoryQueryProvider.notifier).update((q) => q.copyWith(lowStock: true));
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
    final query = ref.watch(inventoryQueryProvider);
    final list = ref.watch(inventoryListProvider);
    final summary = ref.watch(inventorySummaryProvider);
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;
    final lowStockCount = summary.valueOrNull?.lowStockCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Inventory Management',
          title: 'Inventory Management',
          subtitle: 'Stock levels, issued versus available, and reorder points',
          actions: [
            if (user?.can(P.reportsExport) ?? false)
              ExportButton(reportKey: 'inventory', label: 'Stock Report'),
            if (user?.can(P.inventoryAdjust) ?? false)
              FilledButton.icon(
                onPressed: () => showStockAdjustDialog(context, ref),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Adjust Stock'),
              ),
          ],
        ),

        if (lowStockCount > 0)
          NoticeBar(
            tone: NoticeTone.warning,
            message: '$lowStockCount tool(s) at or below minimum stock.',
            action: TextButton(
              onPressed: () => setState(() => _showLowStockPanel = !_showLowStockPanel),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showLowStockPanel ? 'Hide reorder list' : 'View reorder list →',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A5E0E)),
              ),
            ),
          ),

        if (_showLowStockPanel) ...[
          const LowStockPanel(),
          const SizedBox(height: Insets.lg),
        ],

        AsyncView<InventorySummary>(
          value: summary,
          showRefreshLine: false,
          loading: const SizedBox(height: 118, child: BlockSkeleton()),
          data: (s) => KpiStrip(
            cards: [
              KpiCard(
                label: 'Total Quantity',
                value: Fmt.int_(s.totalQty),
                icon: Icons.inventory_2_outlined,
                tone: KpiTone.blue,
                caption: '${s.toolCount} tool types',
              ),
              KpiCard(
                label: 'Available',
                value: Fmt.int_(s.availableQty),
                icon: Icons.check_circle_outline_rounded,
                tone: KpiTone.green,
                caption: '${s.reservedQty} reserved',
              ),
              KpiCard(
                label: 'Issued / In Repair',
                value: '${Fmt.int_(s.issuedQty)} / ${Fmt.int_(s.repairQty)}',
                icon: Icons.swap_horiz_rounded,
                tone: KpiTone.amber,
                caption: '${s.scrapQty} scrapped, ${s.lostQty} lost',
              ),
              KpiCard(
                label: 'Below Minimum',
                value: Fmt.int_(s.lowStockCount),
                icon: Icons.warning_amber_rounded,
                tone: s.lowStockCount > 0 ? KpiTone.red : KpiTone.green,
                caption: 'Valued ${Fmt.moneyCompact(s.inventoryValue)}',
                onTap: () => ref
                    .read(inventoryQueryProvider.notifier)
                    .update((q) => q.copyWith(lowStock: true)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        FilterBar(
          controls: [
            SearchField(
              controller: _searchController,
              hintText: 'Search tool name or ID…',
              width: 260,
              onChanged: (value) =>
                  ref.read(inventoryQueryProvider.notifier).update((q) => q.copyWith(q: value)),
            ),
            if (masters != null)
              FilterDropdown<int?>(
                value: query.categoryId,
                hint: 'All categories',
                onChanged: (value) => ref.read(inventoryQueryProvider.notifier).update(
                      (q) => value == null
                          ? q.copyWith(clearCategory: true)
                          : q.copyWith(categoryId: value),
                    ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                  for (final c in masters.categories)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
              ),
            SegmentedFilter<bool?>(
              value: query.lowStock,
              onChanged: (value) => ref.read(inventoryQueryProvider.notifier).update(
                    (q) => value == null ? q.copyWith(clearLowStock: true) : q.copyWith(lowStock: value),
                  ),
              segments: [
                (value: null, label: 'All', count: null),
                (value: true, label: 'Low stock', count: lowStockCount),
                (value: false, label: 'Healthy', count: null),
              ],
            ),
          ],
          trailing: TextButton.icon(
            onPressed: () => context.go(Routes.report('inventory')),
            icon: const Icon(Icons.insert_chart_outlined_rounded, size: 15),
            label: const Text('Valuation'),
          ),
        ),

        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<InventoryRow>>(
            value: list,
            onRetry: () => ref.invalidate(inventoryListProvider),
            loading: const GridSkeleton(),
            data: (paged) => Column(
              children: [
                DataGrid<InventoryRow>(
                  rows: paged.items,
                  minWidth: 1180,
                  sortKey: query.sort,
                  sortAscending: query.order == 'asc',
                  onSort: (key) =>
                      ref.read(inventoryQueryProvider.notifier).update((q) => q.withSort(key)),
                  onRowTap: (row) => showToolDetail(context, ref, row.toolId),
                  emptyMessage: 'No tools match your filters.',
                  emptyIcon: Icons.widgets_outlined,
                  mobileCardBuilder: _mobileCard,
                  columns: _columns(),
                ),
                PaginationBar(
                  meta: paged.meta,
                  unit: 'tools',
                  onPage: (page) => ref
                      .read(inventoryQueryProvider.notifier)
                      .update((q) => q.copyWith(page: page)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<GridColumn<InventoryRow>> _columns() => [
        GridColumn<InventoryRow>(
          label: 'Tool ID',
          width: 108,
          sortKey: 'toolCode',
          cell: (row) => MonoText(row.toolCode),
        ),
        GridColumn<InventoryRow>(
          label: 'Tool Name',
          flex: 4,
          sortKey: 'name',
          cell: (row) => TwoLineCell(primary: row.name, secondary: row.locationName),
        ),
        GridColumn<InventoryRow>(
          label: 'Total',
          width: 78,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'totalQty',
          cell: (row) => Text(
            '${row.total}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Available',
          width: 92,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'availableQty',
          cell: (row) => Text(
            '${row.available}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: row.isLowStock ? AppColors.redInk : AppColors.greenInk,
            ),
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Issued',
          width: 78,
          numeric: true,
          align: Alignment.centerRight,
          sortKey: 'issuedQty',
          cell: (row) => Text('${row.issued}', style: const TextStyle(fontSize: 13)),
        ),
        GridColumn<InventoryRow>(
          label: 'Repair',
          width: 74,
          numeric: true,
          align: Alignment.centerRight,
          hideBelow: ScreenSize.desktop,
          cell: (row) => Text(
            '${row.repair}',
            style: TextStyle(
              fontSize: 13,
              color: row.repair > 0 ? AppColors.amberInk : AppColors.muted,
            ),
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Scrap',
          width: 70,
          numeric: true,
          align: Alignment.centerRight,
          hideBelow: ScreenSize.desktop,
          cell: (row) => Text(
            '${row.scrap}',
            style: TextStyle(
              fontSize: 13,
              color: row.scrap > 0 ? AppColors.redInk : AppColors.muted,
            ),
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Min',
          width: 64,
          numeric: true,
          align: Alignment.centerRight,
          hideBelow: ScreenSize.tablet,
          cell: (row) => Text(
            '${row.minStock}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Stock Level',
          width: 150,
          sortKey: 'stockPercent',
          cell: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LevelBar(
                percent: row.stockPercent,
                colour: LevelBar.colourFor(percent: row.stockPercent, isLow: row.isLowStock),
              ),
              const SizedBox(height: 3),
              Text(
                '${row.stockPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        GridColumn<InventoryRow>(
          label: 'Status',
          width: 92,
          cell: (row) => StatusChip(row.status),
        ),
      ];

  Widget _mobileCard(InventoryRow row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MonoText(row.toolCode)),
              StatusChip(row.status, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: Insets.sm),
          LevelBar(
            percent: row.stockPercent,
            colour: LevelBar.colourFor(percent: row.stockPercent, isLow: row.isLowStock),
          ),
          const SizedBox(height: 5),
          Text(
            '${row.available} available · ${row.issued} issued · ${row.repair} repair · min ${row.minStock}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      );
}
