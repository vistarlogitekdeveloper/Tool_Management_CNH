import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// One column of a [DataGrid].
class GridColumn<T> {
  const GridColumn({
    required this.label,
    required this.cell,
    this.width,
    this.flex = 1,
    this.align = Alignment.centerLeft,
    this.sortKey,
    this.numeric = false,
    this.hideBelow,
  });

  final String label;
  final Widget Function(T row) cell;

  /// Fixed width; when null the column shares the remaining space by [flex].
  final double? width;
  final int flex;
  final Alignment align;

  /// Set to make the header clickable for server-side sorting.
  final String? sortKey;
  final bool numeric;

  /// Drop this column on narrower screens to keep the grid readable.
  final ScreenSize? hideBelow;

  bool visibleAt(ScreenSize size) {
    if (hideBelow == null) return true;
    return size.index >= hideBelow!.index;
  }
}

/// A horizontally scrollable data table with a sticky styled header, zebra
/// rows, sortable columns and an empty state — the grid every module uses.
///
/// On a phone it swaps to a stacked card list so the shop floor can still read
/// it on a handset (the RFQ's mobile-responsive requirement).
class DataGrid<T> extends StatelessWidget {
  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.sortKey,
    this.sortAscending = true,
    this.onSort,
    this.emptyMessage = 'No records match your filters.',
    this.emptyIcon = Icons.inbox_outlined,
    this.minWidth = 900,
    this.rowHeight = 46,
    this.mobileCardBuilder,
    this.isLoading = false,
  });

  final List<GridColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final String? sortKey;
  final bool sortAscending;
  final void Function(String key)? onSort;
  final String emptyMessage;
  final IconData emptyIcon;
  final double minWidth;
  final double rowHeight;

  /// Renders each row on a phone. Falls back to a generic two-line card.
  final Widget Function(T row)? mobileCardBuilder;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && !isLoading) {
      return EmptyState(message: emptyMessage, icon: emptyIcon);
    }

    if (context.isMobile && mobileCardBuilder != null) {
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
              child: Container(
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: AppColors.line2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                child: mobileCardBuilder!(rows[i]),
              ),
            ),
        ],
      );
    }

    final visible = columns.where((c) => c.visibleAt(context.screenSize)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        final table = SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(visible),
              for (var i = 0; i < rows.length; i++) _row(context, visible, rows[i], i),
            ],
          ),
        );

        return constraints.maxWidth < minWidth
            ? Scrollbar(
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
              )
            : table;
      },
    );
  }

  Widget _header(List<GridColumn<T>> visible) => Container(
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.zebra,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            for (final col in visible) _headerCell(col),
          ],
        ),
      );

  Widget _headerCell(GridColumn<T> col) {
    final isSorted = col.sortKey != null && col.sortKey == sortKey;
    final content = Row(
      mainAxisAlignment: col.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            col.label.toUpperCase(),
            style: kTableHeaderStyle.copyWith(color: isSorted ? AppColors.brand : AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (col.sortKey != null) ...[
          const SizedBox(width: 4),
          Icon(
            isSorted
                ? (sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: isSorted ? AppColors.brand : AppColors.muted.withValues(alpha: 0.45),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Align(alignment: col.align, child: content),
    );

    final cell = col.sortKey != null && onSort != null
        ? InkWell(onTap: () => onSort!(col.sortKey!), child: padded)
        : padded;

    return col.width != null
        ? SizedBox(width: col.width, child: cell)
        : Expanded(flex: col.flex, child: cell);
  }

  Widget _row(BuildContext context, List<GridColumn<T>> visible, T row, int index) {
    final content = Container(
      constraints: BoxConstraints(minHeight: rowHeight),
      decoration: BoxDecoration(
        color: index.isOdd ? AppColors.zebra.withValues(alpha: 0.55) : null,
        border: index == rows.length - 1
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final col in visible)
            col.width != null
                ? SizedBox(width: col.width, child: _bodyCell(col, row))
                : Expanded(flex: col.flex, child: _bodyCell(col, row)),
        ],
      ),
    );

    if (onRowTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onRowTap!(row),
        hoverColor: AppColors.hover,
        child: content,
      ),
    );
  }

  Widget _bodyCell(GridColumn<T> col, T row) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Align(alignment: col.align, child: col.cell(row)),
      );
}

/// Two-line primary cell: bold name over a muted secondary line.
class TwoLineCell extends StatelessWidget {
  const TwoLineCell({super.key, required this.primary, this.secondary, this.leading});

  final String primary;
  final String? secondary;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (secondary != null && secondary!.isNotEmpty)
          Text(
            secondary!,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );

    if (leading == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [leading!, const SizedBox(width: Insets.sm), Flexible(child: text)],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? Insets.xl : 44, horizontal: Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 26 : 34, color: AppColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: Insets.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: Insets.lg), action!],
          ],
        ),
      );
}

/// Row-range caption plus prev/next, shown under every paged grid.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.meta, required this.onPage, this.unit = 'records'});

  final PageMeta meta;
  final void Function(int page) onPage;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (meta.total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing ${meta.firstRow}–${meta.lastRow} of ${meta.total} $unit',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          IconButton(
            onPressed: meta.hasPrev ? () => onPage(meta.page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            iconSize: 20,
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Text(
              'Page ${meta.page} of ${meta.totalPages}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: meta.hasNext ? () => onPage(meta.page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            iconSize: 20,
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
