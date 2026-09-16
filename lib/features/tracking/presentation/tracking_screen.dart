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
import '../../../models/tracking.dart';
import '../../auth/data/auth_controller.dart';
import '../data/tracking_repository.dart';
import 'widgets/locate_sheet.dart';
import 'widgets/transfer_dialog.dart';

/// Real-time tool tracking — where every tool is, and who is holding it.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final query = ref.watch(trackingQueryProvider);
    final zones = ref.watch(trackingZonesProvider);
    final live = ref.watch(trackingLiveProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Tool Tracking',
          title: 'Real-Time Tool Tracking',
          subtitle: 'Live location and status of every tool, shop by shop',
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                ref
                  ..invalidate(trackingZonesProvider)
                  ..invalidate(trackingLiveProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
            if (user?.can(P.trackingTransfer) ?? false)
              FilledButton.icon(
                onPressed: () => showTransferDialog(context, ref),
                icon: const Icon(Icons.moving_rounded, size: 17),
                label: const Text('Transfer Tool'),
              ),
          ],
        ),

        AsyncView<List<TrackingZone>>(
          value: zones,
          showRefreshLine: false,
          loading: const SizedBox(height: 120, child: BlockSkeleton()),
          onRetry: () => ref.invalidate(trackingZonesProvider),
          data: (list) => ResponsiveGrid(
            columns: context.cardColumns,
            children: [
              for (final zone in list)
                _ZoneCard(
                  zone: zone,
                  selected: query.shop == zone.shop,
                  onTap: () => ref.read(trackingQueryProvider.notifier).update(
                        (q) => q.shop == zone.shop
                            ? q.copyWith(clearShop: true)
                            : q.copyWith(shop: zone.shop),
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),

        FilterBar(
          controls: [
            SearchField(
              controller: _searchController,
              hintText: 'Find a tool…',
              width: 250,
              onChanged: (value) =>
                  ref.read(trackingQueryProvider.notifier).update((q) => q.copyWith(q: value)),
            ),
            SegmentedFilter<String?>(
              value: query.status,
              onChanged: (value) => ref.read(trackingQueryProvider.notifier).update(
                    (q) => value == null ? q.copyWith(clearStatus: true) : q.copyWith(status: value),
                  ),
              segments: const [
                (value: null, label: 'All', count: null),
                (value: 'ISSUED', label: 'In use', count: null),
                (value: 'AVAILABLE', label: 'In store', count: null),
                (value: 'IN_REPAIR', label: 'In repair', count: null),
              ],
            ),
            if (query.shop != null)
              InputChip(
                label: Text(query.shop!, style: const TextStyle(fontSize: 12)),
                onDeleted: () =>
                    ref.read(trackingQueryProvider.notifier).update((q) => q.copyWith(clearShop: true)),
                backgroundColor: AppColors.brandSoft,
                side: const BorderSide(color: AppColors.brandSoft),
                labelStyle: const TextStyle(color: AppColors.brand),
                deleteIconColor: AppColors.brand,
              ),
          ],
        ),

        SectionCard(
          title: 'Live tool locations',
          subtitle: 'Home location, current holder and outstanding quantity',
          trailing: Text(
            'Updated ${Fmt.ago(DateTime.now())}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          padding: EdgeInsets.zero,
          child: AsyncView<PagedResult<TrackedTool>>(
            value: live,
            onRetry: () => ref.invalidate(trackingLiveProvider),
            loading: const GridSkeleton(),
            data: (paged) => Column(
              children: [
                DataGrid<TrackedTool>(
                  rows: paged.items,
                  minWidth: 1040,
                  onRowTap: (row) => showLocateSheet(context, ref, row.toolId),
                  emptyMessage: 'No tools match your filters.',
                  emptyIcon: Icons.my_location_rounded,
                  mobileCardBuilder: _mobileCard,
                  columns: _columns(),
                ),
                PaginationBar(
                  meta: paged.meta,
                  unit: 'tools',
                  onPage: (page) => ref
                      .read(trackingQueryProvider.notifier)
                      .update((q) => q.copyWith(page: page)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<GridColumn<TrackedTool>> _columns() => [
        GridColumn<TrackedTool>(
          label: 'Tool ID',
          width: 106,
          cell: (row) => MonoText(row.toolCode),
        ),
        GridColumn<TrackedTool>(
          label: 'Tool Name',
          flex: 4,
          cell: (row) => TwoLineCell(primary: row.name, secondary: row.categoryName),
        ),
        GridColumn<TrackedTool>(
          label: 'Home Location',
          flex: 3,
          cell: (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.brand),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  row.homeLocation?.name ?? '— Store —',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        GridColumn<TrackedTool>(
          label: 'Held By',
          flex: 3,
          hideBelow: ScreenSize.tablet,
          cell: (row) => Text(
            row.holderLabel,
            style: TextStyle(
              fontSize: 12.5,
              color: row.heldBy == null ? AppColors.muted : AppColors.ink,
              fontWeight: row.heldBy == null ? FontWeight.w400 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GridColumn<TrackedTool>(
          label: 'In Store',
          width: 84,
          numeric: true,
          align: Alignment.centerRight,
          cell: (row) => Text(
            '${row.availableQty}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        GridColumn<TrackedTool>(
          label: 'In Use',
          width: 76,
          numeric: true,
          align: Alignment.centerRight,
          cell: (row) => Text(
            '${row.issuedQty}',
            style: TextStyle(
              fontSize: 13,
              color: row.issuedQty > 0 ? AppColors.brand : AppColors.muted,
            ),
          ),
        ),
        GridColumn<TrackedTool>(
          label: 'Status',
          width: 148,
          cell: (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(row.status, dense: true),
              if (row.hasOverdue) ...[
                const SizedBox(width: 5),
                const Tooltip(
                  message: 'One or more holders are past their due date',
                  child: Icon(Icons.error_outline_rounded, size: 15, color: AppColors.red),
                ),
              ],
            ],
          ),
        ),
      ];

  Widget _mobileCard(TrackedTool row) => Column(
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
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${row.homeLocation?.name ?? '— Store —'} · ${row.holderLabel}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${row.availableQty}/${row.totalQty}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      );
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.selected, required this.onTap});

  final TrackingZone zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(Insets.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Insets.radius),
          child: Container(
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Insets.radius),
              border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: selected ? 1.6 : 1),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        zone.shop,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusChip(
                      'IN_STORE',
                      label: '${zone.totalQty} tools',
                      dense: true,
                      palette: StatusPalette.blue,
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                LevelBar(percent: zone.utilisationPercent.toDouble(), colour: AppColors.brand),
                const SizedBox(height: Insets.sm),
                Row(
                  children: [
                    _dot(AppColors.brand, '${zone.inUseQty} in use'),
                    const Spacer(),
                    _dot(AppColors.green, '${zone.availableQty} available'),
                  ],
                ),
                if (zone.repairQty > 0) ...[
                  const SizedBox(height: 5),
                  _dot(AppColors.amber, '${zone.repairQty} out for repair'),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _dot(Color colour, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      );
}
