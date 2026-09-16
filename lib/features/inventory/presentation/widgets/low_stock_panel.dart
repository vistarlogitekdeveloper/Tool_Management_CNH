import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/inventory.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/inventory_repository.dart';

/// The reorder list: every tool at or below its minimum, with the quantity the
/// system suggests ordering and whether a PO is already open for it.
class LowStockPanel extends ConsumerWidget {
  const LowStockPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider);
    final canPurchase = ref.watch(canProvider(P.purchaseCreate));

    return SectionCard(
      title: 'Reorder list',
      subtitle: 'Suggested order quantities, grouped by urgency',
      trailing: canPurchase
          ? TextButton.icon(
              onPressed: () => context.go(Routes.purchase),
              icon: const Icon(Icons.shopping_cart_outlined, size: 15),
              label: const Text('Raise purchase orders'),
            )
          : null,
      padding: EdgeInsets.zero,
      child: AsyncView<List<LowStockItem>>(
        value: lowStock,
        onRetry: () => ref.invalidate(lowStockProvider),
        loading: const GridSkeleton(rows: 3),
        data: (items) => DataGrid<LowStockItem>(
          rows: items,
          minWidth: 960,
          rowHeight: 44,
          emptyMessage: 'Every tool is above its minimum stock.',
          emptyIcon: Icons.check_circle_outline_rounded,
          mobileCardBuilder: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: MonoText(row.toolCode)),
                  if (row.hasOpenPo)
                    const StatusChip('IN_TRANSIT', label: 'PO open', dense: true)
                  else
                    const StatusChip('LOW', label: 'Reorder', dense: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(row.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${row.available} left (min ${row.minStock}) · order ${row.suggestedOrderQty} '
                '≈ ${Fmt.moneyCompact(row.estimatedCost)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
          columns: [
            GridColumn<LowStockItem>(
              label: 'Tool ID',
              width: 106,
              cell: (row) => MonoText(row.toolCode),
            ),
            GridColumn<LowStockItem>(
              label: 'Tool Name',
              flex: 4,
              cell: (row) => TwoLineCell(primary: row.name, secondary: row.categoryName),
            ),
            GridColumn<LowStockItem>(
              label: 'Available',
              width: 92,
              numeric: true,
              align: Alignment.centerRight,
              cell: (row) => Text(
                '${row.available}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.redInk,
                ),
              ),
            ),
            GridColumn<LowStockItem>(
              label: 'Minimum',
              width: 86,
              numeric: true,
              align: Alignment.centerRight,
              cell: (row) => Text('${row.minStock}', style: const TextStyle(fontSize: 13)),
            ),
            GridColumn<LowStockItem>(
              label: 'Shortfall',
              width: 86,
              numeric: true,
              align: Alignment.centerRight,
              hideBelow: ScreenSize.desktop,
              cell: (row) => Text(
                '${row.shortfall}',
                style: const TextStyle(fontSize: 13, color: AppColors.amberInk),
              ),
            ),
            GridColumn<LowStockItem>(
              label: 'Suggested Order',
              width: 128,
              numeric: true,
              align: Alignment.centerRight,
              cell: (row) => Text(
                '${row.suggestedOrderQty}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            GridColumn<LowStockItem>(
              label: 'Est. Cost',
              width: 110,
              numeric: true,
              align: Alignment.centerRight,
              hideBelow: ScreenSize.tablet,
              cell: (row) => Text(
                Fmt.money(row.estimatedCost),
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            GridColumn<LowStockItem>(
              label: 'Status',
              width: 120,
              cell: (row) => row.hasOpenPo
                  ? StatusChip('IN_TRANSIT', label: '${row.openPoCount} PO open', dense: true)
                  : const StatusChip('LOW', label: 'Reorder', dense: true),
            ),
          ],
        ),
      ),
    );
  }
}
