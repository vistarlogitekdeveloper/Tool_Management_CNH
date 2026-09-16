import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/purchase.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/purchase_repository.dart';
import 'po_dialog.dart';

/// Low-stock tools grouped by their usual supplier, each group one click from
/// becoming a purchase order.
class ReorderPanel extends ConsumerWidget {
  const ReorderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(reorderSuggestionsProvider);
    final canCreate = ref.watch(canProvider(P.purchaseCreate));

    return AsyncView<List<ReorderSuggestion>>(
      value: suggestions,
      onRetry: () => ref.invalidate(reorderSuggestionsProvider),
      loading: const BlockSkeleton(height: 200),
      data: (groups) => SectionCard(
        title: 'Reorder suggestions',
        subtitle: groups.isEmpty
            ? 'Nothing is below its minimum stock'
            : '${groups.fold<int>(0, (s, g) => s + g.lines.length)} tool(s) across '
                '${groups.length} supplier(s)',
        padding: EdgeInsets.zero,
        child: groups.isEmpty
            ? const EmptyState(
                compact: true,
                icon: Icons.check_circle_outline_rounded,
                message: 'All stock is healthy. Nothing needs reordering.',
              )
            : Column(
                children: [
                  for (final group in groups) _group(context, ref, group, canCreate),
                ],
              ),
      ),
    );
  }

  Widget _group(BuildContext context, WidgetRef ref, ReorderSuggestion group, bool canCreate) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
            color: AppColors.zebra,
            child: Row(
              children: [
                const Icon(Icons.store_outlined, size: 15, color: AppColors.brand),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    group.vendorName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${group.lines.length} line(s) · ${Fmt.money(group.estimatedValue)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (canCreate) ...[
                  const SizedBox(width: Insets.md),
                  FilledButton.icon(
                    onPressed: () => showPoDialog(context, ref, fromSuggestion: group),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Raise PO'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final line in group.lines)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 11),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line2)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 106, child: MonoText(line.toolCode)),
                  Expanded(
                    child: TwoLineCell(
                      primary: line.name,
                      secondary: '${line.available} in stock · minimum ${line.minStock}',
                    ),
                  ),
                  if (line.openPoCount > 0) ...[
                    StatusChip(
                      'IN_TRANSIT',
                      label: '${line.openPoCount} PO open',
                      dense: true,
                    ),
                    const SizedBox(width: Insets.md),
                  ],
                  SizedBox(
                    width: 92,
                    child: Text(
                      'Order ${line.suggestedQty}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  SizedBox(
                    width: 96,
                    child: Text(
                      Fmt.money(line.lineValue),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
