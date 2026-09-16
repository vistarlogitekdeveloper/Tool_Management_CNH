import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/tracking.dart';
import '../../../tools/presentation/widgets/tool_detail_sheet.dart';
import '../../data/tracking_repository.dart';

/// "Where is TL-1002 right now?" — the split between store, hands and vendor,
/// with every holder named.
Future<void> showLocateSheet(BuildContext context, WidgetRef ref, int toolId) =>
    showDetailSheet<void>(context, _LocateSheet(toolId: toolId), width: 620);

class _LocateSheet extends ConsumerWidget {
  const _LocateSheet({required this.toolId});

  final int toolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final located = ref.watch(locateToolProvider(toolId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: context.isMobile
          ? AppBar(
              title: Text(located.valueOrNull?.name ?? 'Locate tool'),
              backgroundColor: Colors.white,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      body: AsyncView<ToolLocation>(
        value: located,
        onRetry: () => ref.invalidate(locateToolProvider(toolId)),
        data: (loc) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!context.isMobile)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, Insets.md, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  loc.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: Insets.sm),
                              MonoText(loc.toolCode, size: 13),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Home location: ${loc.homeLocation ?? '—'}'
                            '${loc.shop != null ? '  ·  ${loc.shop}' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResponsiveGrid(
                      columns: context.isMobile ? 2 : 4,
                      spacing: Insets.md,
                      children: [
                        _tile('In store', loc.inStore, AppColors.green, Icons.warehouse_outlined),
                        _tile('In use', loc.inUse, AppColors.brand, Icons.pan_tool_alt_outlined),
                        _tile('At vendor', loc.inRepair, AppColors.amber, Icons.build_outlined),
                        _tile('Reserved', loc.reserved, AppColors.violet, Icons.event_available_outlined),
                      ],
                    ),
                    const SizedBox(height: Insets.xl),
                    SectionCard(
                      title: 'Who is holding it',
                      subtitle: loc.holders.isEmpty
                          ? 'Every unit is accounted for in store'
                          : '${loc.holders.length} open issue(s)',
                      padding: EdgeInsets.zero,
                      child: loc.holders.isEmpty
                          ? const EmptyState(
                              compact: true,
                              icon: Icons.check_circle_outline_rounded,
                              message: 'Nothing is currently issued.',
                            )
                          : Column(
                              children: [
                                for (final holder in loc.holders)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Insets.lg, vertical: Insets.md),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: AppColors.line2)),
                                    ),
                                    child: Row(
                                      children: [
                                        InitialsAvatar(Fmt.initials(holder.employeeName), size: 32),
                                        const SizedBox(width: Insets.md),
                                        Expanded(
                                          child: TwoLineCell(
                                            primary: holder.employeeName,
                                            secondary:
                                                '${holder.department ?? '—'} · ${holder.location ?? '—'}',
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Qty ${holder.qty}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (holder.isOverdue) ...[
                                                  const StatusChip('OVERDUE', dense: true),
                                                  const SizedBox(width: 5),
                                                ],
                                                Text(
                                                  'due ${Fmt.dateShort(holder.dueDate)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: Insets.xl),
                    SectionCard(
                      title: 'Recent movements',
                      padding: EdgeInsets.zero,
                      child: loc.recentMovements.isEmpty
                          ? const EmptyState(
                              compact: true,
                              icon: Icons.history_rounded,
                              message: 'No movements recorded.',
                            )
                          : Column(
                              children: [
                                for (final m in loc.recentMovements)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Insets.lg, vertical: 11),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: AppColors.line2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TwoLineCell(
                                            primary: TxnLabels.of(m.type),
                                            secondary: [
                                              if (m.from != null) 'from ${m.from}',
                                              if (m.to != null) 'to ${m.to}',
                                              if (m.employeeName != null) m.employeeName!,
                                            ].join(' · '),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${m.qty}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              Fmt.ago(m.at),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.zebra,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showToolDetail(context, ref, toolId);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Open tool record'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int value, Color colour, IconData icon) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(Insets.radiusSm),
          border: Border.all(color: colour.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: colour),
            const SizedBox(height: Insets.sm),
            Text(
              '$value',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: colour, height: 1.1),
            ),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      );
}
