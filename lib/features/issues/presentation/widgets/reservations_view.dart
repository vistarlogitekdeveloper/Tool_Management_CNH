import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/issue.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/issues_repository.dart';
import 'issue_dialog.dart';

/// The Reservations view inside Issue & Return.
///
/// "Tool Reservation" is an RFQ *Software Development* line, not one of the nine
/// modules, so it lives here rather than taking a tenth sidebar slot: a
/// reservation is the step before an issue, and this is where the store keeper
/// turns one into the other.
class ReservationsView extends ConsumerWidget {
  const ReservationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final status = ref.watch(reservationStatusProvider);
    final reservations = ref.watch(reservationsProvider);
    final canReserve = user?.can(P.issueReserve) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterBar(
          controls: [
            SegmentedFilter<String?>(
              value: status,
              onChanged: (value) =>
                  ref.read(reservationStatusProvider.notifier).state = value,
              segments: const [
                (value: 'ACTIVE', label: 'Active', count: null),
                (value: 'FULFILLED', label: 'Fulfilled', count: null),
                (value: 'CANCELLED', label: 'Cancelled', count: null),
                (value: 'EXPIRED', label: 'Expired', count: null),
                (value: null, label: 'All', count: null),
              ],
            ),
          ],
          trailing: OutlinedButton.icon(
            onPressed: () => ref.invalidate(reservationsProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ),

        AsyncView<List<Reservation>>(
          value: reservations,
          onRetry: () => ref.invalidate(reservationsProvider),
          loading: const BlockSkeleton(),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.any((r) => r.isLapsing)) ...[
                NoticeBar(
                  tone: NoticeTone.warning,
                  icon: Icons.schedule_rounded,
                  message: '${rows.where((r) => r.isLapsing).length} reservation(s) have '
                      'reached the end of their window. The nightly job releases the held '
                      'stock back to store — issue or extend them if the job is still on.',
                ),
              ],
              SectionCard(
                title: _titleFor(status),
                subtitle: _subtitleFor(rows, status),
                child: DataGrid<Reservation>(
                  rows: rows,
                  minWidth: 940,
                  emptyIcon: Icons.event_available_outlined,
                  emptyMessage: status == 'ACTIVE'
                      ? 'Nothing is reserved right now. Hold stock for an upcoming job '
                          'and it cannot be issued to anyone else in the meantime.'
                      : 'No reservations with this status.',
                  columns: [
                    GridColumn<Reservation>(
                      label: 'Reservation',
                      width: 130,
                      cell: (r) => Text(
                        r.reservationNo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Tool',
                      flex: 3,
                      cell: (r) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            r.tool.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            r.tool.toolCode,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Held for',
                      flex: 2,
                      cell: (r) => Text(
                        r.employeeName ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Station',
                      flex: 2,
                      hideBelow: ScreenSize.desktop,
                      cell: (r) => Text(
                        r.locationName ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Qty',
                      width: 66,
                      numeric: true,
                      align: Alignment.centerRight,
                      cell: (r) => Text(
                        '${r.qty}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Window',
                      flex: 2,
                      cell: (r) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${Fmt.dateShort(r.fromDate)} → ${Fmt.dateShort(r.toDate)}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          if (r.isActive)
                            Text(
                              _remainingLabel(r),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: r.isLapsing ? AppColors.red : AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: 'Status',
                      width: 110,
                      cell: (r) => Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(r.status, dense: true),
                      ),
                    ),
                    GridColumn<Reservation>(
                      label: '',
                      width: 150,
                      align: Alignment.centerRight,
                      cell: (r) => _rowActions(context, ref, r, canReserve),
                    ),
                  ],
                  mobileCardBuilder: (r) => _mobileCard(context, ref, r, canReserve),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _titleFor(String? status) => switch (status) {
        'ACTIVE' => 'Active reservations',
        'FULFILLED' => 'Fulfilled reservations',
        'CANCELLED' => 'Cancelled reservations',
        'EXPIRED' => 'Expired reservations',
        _ => 'All reservations',
      };

  String _subtitleFor(List<Reservation> rows, String? status) {
    if (rows.isEmpty) return 'Nothing to show';
    final units = rows.fold<int>(0, (sum, r) => sum + r.qty);
    if (status == 'ACTIVE') {
      return '${rows.length} reservation(s) holding $units unit(s) out of available stock';
    }
    return '${rows.length} reservation(s), $units unit(s)';
  }

  static String _remainingLabel(Reservation r) {
    final days = r.daysRemaining;
    if (days == null) return '';
    if (days < 0) return 'window passed';
    if (days == 0) return 'ends today';
    return '$days day(s) left';
  }

  Widget _rowActions(BuildContext context, WidgetRef ref, Reservation r, bool canReserve) {
    if (!r.isActive) {
      return const Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canReserve)
          TextButton(
            onPressed: () => _issueAgainst(context, ref, r),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Issue', style: TextStyle(fontSize: 12.5)),
          ),
        if (canReserve)
          IconButton(
            onPressed: () => _cancel(context, ref, r),
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Cancel reservation',
            visualDensity: VisualDensity.compact,
            color: AppColors.muted,
          ),
      ],
    );
  }

  Widget _mobileCard(BuildContext context, WidgetRef ref, Reservation r, bool canReserve) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.tool.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              StatusChip(r.status, dense: true),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${r.reservationNo} · ${r.tool.toolCode}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '${r.qty} unit(s) held for ${r.employeeName ?? '—'}'
            '${r.locationName == null ? '' : ' at ${r.locationName}'}',
            style: const TextStyle(fontSize: 12.5),
          ),
          Text(
            '${Fmt.dateShort(r.fromDate)} → ${Fmt.dateShort(r.toDate)}'
            '${r.isActive ? ' · ${_remainingLabel(r)}' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: r.isLapsing ? AppColors.red : AppColors.muted,
            ),
          ),
          if (r.purpose != null && r.purpose!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              r.purpose!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
          ],
          if (r.isActive && canReserve) ...[
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _issueAgainst(context, ref, r),
                    child: const Text('Issue against this'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                OutlinedButton(
                  onPressed: () => _cancel(context, ref, r),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      );

  /// Consume the hold: the issue releases the reserved quantity and charges the
  /// issue in one transaction, so the units are never counted twice.
  Future<void> _issueAgainst(BuildContext context, WidgetRef ref, Reservation r) async {
    final issued = await showIssueDialog(context, ref, reservation: r);
    if (issued) ref.invalidate(reservationsProvider);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Reservation r) async {
    final reasonController = TextEditingController();
    final ok = await confirm(
      context,
      title: 'Cancel ${r.reservationNo}?',
      message: '${r.qty} × ${r.tool.name} goes straight back into available stock.',
      confirmLabel: 'Cancel reservation',
      cancelLabel: 'Keep it',
      destructive: true,
      extra: Padding(
        padding: const EdgeInsets.only(top: Insets.md),
        child: AppTextField(
          controller: reasonController,
          hintText: 'Reason (optional) — recorded on the stock ledger',
        ),
      ),
    );
    if (!ok) return;

    try {
      await ref.read(issuesRepositoryProvider).cancelReservation(
            r.id,
            reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
          );
      invalidateStockViews(ref);
      if (context.mounted) {
        context.toast('${r.reservationNo} cancelled — ${r.qty} unit(s) back in store');
      }
    } catch (error) {
      if (context.mounted) context.showApiError(error);
    } finally {
      reasonController.dispose();
    }
  }
}
