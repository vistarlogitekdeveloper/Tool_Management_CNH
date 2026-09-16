import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/dashboard.dart';

/// "Recent Tool Activity" — the last few issues, each carrying a name.
class ActivityList extends StatelessWidget {
  const ActivityList({super.key, required this.items, this.onTap});

  final List<ActivityItem> items;
  final void Function(ActivityItem item)? onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.history_rounded,
        message: 'No tool movements recorded yet.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(items[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 11),
              decoration: BoxDecoration(
                border: i == items.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.line2)),
              ),
              child: Row(
                children: [
                  InitialsAvatar(items[i].initials, size: 30),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    flex: 3,
                    child: TwoLineCell(
                      primary: items[i].employeeName,
                      secondary: items[i].locationName,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    flex: 4,
                    child: TwoLineCell(
                      primary: items[i].toolName,
                      secondary: '${items[i].toolCode} · qty ${items[i].qty}',
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(items[i].status, dense: true),
                      const SizedBox(height: 3),
                      Text(
                        Fmt.dateShort(items[i].issueDate),
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
