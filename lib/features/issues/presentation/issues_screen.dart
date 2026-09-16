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
import '../../../models/issue.dart';
import '../../auth/data/auth_controller.dart';
import '../../shell/data/masters_repository.dart';
import '../data/issues_repository.dart';
import 'widgets/issue_dialog.dart';
import 'widgets/reservation_dialog.dart';
import 'widgets/reservations_view.dart';
import 'widgets/return_dialog.dart';

/// Issue & Return — who has what, and whether it came back.
class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

/// The two views this screen hosts. Reservations are the step before an issue,
/// so they belong inside Issue & Return rather than in a tenth sidebar slot —
/// the RFQ lists "Tool Reservation" under Software Development, and the deck and
/// prototype both fix the sidebar at nine modules.
enum _IssuesView { issues, reservations }

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  final _searchController = TextEditingController();
  _IssuesView _view = _IssuesView.issues;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      // Deep link from an alert, e.g. /issues?status=OVERDUE.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(issueQueryProvider.notifier).update(
              (q) => q.copyWith(status: widget.initialStatus!.toUpperCase()),
            );
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
    final query = ref.watch(issueQueryProvider);
    final list = ref.watch(issuesListProvider);
    final summary = ref.watch(issueSummaryProvider);
    final masters = ref.watch(masterBootstrapProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          breadcrumb: 'Tool Lifecycle / Issue & Return',
          title: 'Issue & Return',
          subtitle: 'Who has what — issue a tool and stock updates instantly',
          actions: [
            if (_view == _IssuesView.issues)
              OutlinedButton.icon(
                onPressed: () {
                  ref
                    ..invalidate(issuesListProvider)
                    ..invalidate(issueSummaryProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            if (user?.can(P.issueReserve) ?? false)
              OutlinedButton.icon(
                onPressed: () async {
                  final made = await showReservationDialog(context, ref);
                  // Land on the list so the new hold is visible straight away.
                  if (made && mounted) setState(() => _view = _IssuesView.reservations);
                },
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: const Text('Reserve Tool'),
              ),
            if (user?.can(P.issueCreate) ?? false)
              FilledButton.icon(
                onPressed: () => showIssueDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Issue Tool'),
              ),
          ],
        ),

        // View switch. Kept above the KPI strip so the numbers below always
        // describe whatever is on screen.
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedFilter<_IssuesView>(
              value: _view,
              onChanged: (value) => setState(() => _view = value),
              segments: [
                (value: _IssuesView.issues, label: 'Issues & Returns', count: null),
                (
                  value: _IssuesView.reservations,
                  label: 'Reservations',
                  count: ref.watch(activeReservationsProvider).valueOrNull?.length,
                ),
              ],
            ),
          ),
        ),

        if (_view == _IssuesView.reservations) const ReservationsView(),

        if (_view == _IssuesView.issues) ...[
          AsyncView<IssueSummary>(
            value: summary,
            showRefreshLine: false,
            loading: const SizedBox(height: 118, child: BlockSkeleton()),
            data: (s) => KpiStrip(
              cards: [
                KpiCard(
                  label: 'Currently Issued',
                  value: Fmt.int_(s.openCount),
                  icon: Icons.swap_horiz_rounded,
                  tone: KpiTone.blue,
                  caption: '${s.qtyOutstanding} unit(s) outstanding',
                ),
                KpiCard(
                  label: 'Overdue Returns',
                  value: Fmt.int_(s.overdueCount),
                  icon: Icons.running_with_errors_rounded,
                  tone: s.overdueCount > 0 ? KpiTone.red : KpiTone.green,
                  caption: s.overdueCount > 0 ? 'Escalate to supervisors' : 'Nothing late',
                  captionTone: s.overdueCount > 0 ? KpiTone.red : KpiTone.green,
                  onTap: s.overdueCount == 0
                      ? null
                      : () => ref
                          .read(issueQueryProvider.notifier)
                          .update((q) => q.copyWith(status: 'OVERDUE')),
                ),
                KpiCard(
                  label: 'Returned',
                  value: Fmt.int_(s.returnedCount),
                  icon: Icons.assignment_turned_in_outlined,
                  tone: KpiTone.green,
                  caption: 'Closed records',
                ),
                KpiCard(
                  label: 'Issued Today',
                  value: Fmt.int_(s.issuedToday),
                  icon: Icons.today_rounded,
                  tone: KpiTone.violet,
                  caption: '${s.totalCount} records in total',
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          FilterBar(
            controls: [
              SegmentedFilter<String?>(
                value: query.status,
                onChanged: (value) => ref.read(issueQueryProvider.notifier).update(
                      (q) => value == null ? q.copyWith(clearStatus: true) : q.copyWith(status: value),
                    ),
                segments: [
                  (value: null, label: 'All', count: null),
                  (value: 'OPEN', label: 'Open', count: summary.valueOrNull?.openCount),
                  (value: 'OVERDUE', label: 'Overdue', count: summary.valueOrNull?.overdueCount),
                  (value: 'RETURNED', label: 'Returned', count: null),
                ],
              ),
              SearchField(
                controller: _searchController,
                hintText: 'Employee, tool or issue no…',
                width: 250,
                onChanged: (value) =>
                    ref.read(issueQueryProvider.notifier).update((q) => q.copyWith(q: value)),
              ),
              if (masters != null)
                FilterDropdown<int?>(
                  value: query.departmentId,
                  hint: 'All departments',
                  onChanged: (value) => ref.read(issueQueryProvider.notifier).update(
                        (q) => value == null
                            ? q.copyWith(clearDepartment: true)
                            : q.copyWith(departmentId: value),
                      ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All departments')),
                    for (final d in masters.departments)
                      DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                  ],
                ),
            ],
            trailing: query.status != null || query.q.isNotEmpty || query.departmentId != null
                ? TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(issueQueryProvider.notifier).state = const IssueQuery();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                    label: const Text('Clear'),
                  )
                : null,
          ),

          SectionCard(
            padding: EdgeInsets.zero,
            child: AsyncView<PagedResult<ToolIssue>>(
              value: list,
              onRetry: () => ref.invalidate(issuesListProvider),
              loading: const GridSkeleton(),
              data: (paged) => Column(
                children: [
                  DataGrid<ToolIssue>(
                    rows: paged.items,
                    minWidth: 1080,
                    emptyMessage: 'No issue records match your filters.',
                    emptyIcon: Icons.swap_horiz_rounded,
                    mobileCardBuilder: (row) => _mobileCard(row, user),
                    columns: _columns(user),
                  ),
                  PaginationBar(
                    meta: paged.meta,
                    unit: 'issue records',
                    onPage: (page) =>
                        ref.read(issueQueryProvider.notifier).update((q) => q.copyWith(page: page)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<GridColumn<ToolIssue>> _columns(user) {
    final canReturn = user?.can(P.issueReturn) ?? false;
    final canExtend = user?.can(P.issueCreate) ?? false;

    return [
      GridColumn<ToolIssue>(
        label: 'Issue No.',
        width: 130,
        sortKey: 'issueNo',
        cell: (row) => MonoText(row.issueNo, size: 12),
      ),
      GridColumn<ToolIssue>(
        label: 'Employee',
        flex: 3,
        sortKey: 'employee',
        cell: (row) => TwoLineCell(
          primary: row.employee.name,
          secondary: row.department,
          leading: InitialsAvatar(row.employee.initials, size: 28),
        ),
      ),
      GridColumn<ToolIssue>(
        label: 'Tool',
        flex: 3,
        sortKey: 'tool',
        cell: (row) => TwoLineCell(primary: row.tool.name, secondary: row.tool.toolCode),
      ),
      GridColumn<ToolIssue>(
        label: 'Station',
        flex: 2,
        hideBelow: ScreenSize.desktop,
        cell: (row) => Text(
          row.location ?? '—',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      GridColumn<ToolIssue>(
        label: 'Qty',
        width: 92,
        numeric: true,
        align: Alignment.centerRight,
        sortKey: 'qty',
        cell: (row) => Text(
          row.qtyReturned > 0 && !row.isClosed
              ? '${row.qtyOutstanding}/${row.qtyIssued}'
              : '${row.qtyIssued}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      GridColumn<ToolIssue>(
        label: 'Issued',
        width: 108,
        sortKey: 'issueDate',
        hideBelow: ScreenSize.tablet,
        cell: (row) => Text(
          Fmt.date(row.issueDate),
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
      GridColumn<ToolIssue>(
        label: 'Due / Returned',
        width: 130,
        sortKey: 'dueDate',
        cell: (row) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Fmt.date(row.isClosed ? row.returnedOn : row.dueDate),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: row.isOverdue && !row.isClosed ? AppColors.redInk : AppColors.ink,
              ),
            ),
            if (row.isOverdue && !row.isClosed)
              Text(
                '${row.daysOverdue} day(s) late',
                style: const TextStyle(fontSize: 11, color: AppColors.redInk),
              ),
          ],
        ),
      ),
      GridColumn<ToolIssue>(
        label: 'Status',
        width: 132,
        sortKey: 'status',
        cell: (row) => StatusChip(row.effectiveStatus),
      ),
      GridColumn<ToolIssue>(
        label: '',
        width: canReturn ? 190 : 90,
        align: Alignment.centerRight,
        cell: (row) => row.isClosed
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: AppColors.green),
                  SizedBox(width: 4),
                  Text('Closed', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canExtend)
                    IconButton(
                      onPressed: () => showExtendDialog(context, ref, row),
                      icon: const Icon(Icons.event_repeat_rounded, size: 16),
                      tooltip: 'Extend due date',
                      visualDensity: VisualDensity.compact,
                      color: AppColors.slate,
                    ),
                  if (canReturn) ...[
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () => showReturnDialog(context, ref, row),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Return'),
                    ),
                  ],
                ],
              ),
      ),
    ];
  }

  Widget _mobileCard(ToolIssue row, user) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InitialsAvatar(row.employee.initials, size: 32),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TwoLineCell(
                  primary: row.employee.name,
                  secondary: '${row.department ?? '—'} · ${row.location ?? '—'}',
                ),
              ),
              StatusChip(row.effectiveStatus, dense: true),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '${row.tool.name} · ${row.tool.toolCode} · qty ${row.qtyOutstanding > 0 ? row.qtyOutstanding : row.qtyIssued}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                'Issued ${Fmt.dateShort(row.issueDate)} · due ${Fmt.dateShort(row.dueDate)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: row.isOverdue && !row.isClosed ? AppColors.redInk : AppColors.muted,
                ),
              ),
              const Spacer(),
              if (!row.isClosed && (user?.can(P.issueReturn) ?? false))
                OutlinedButton(
                  onPressed: () => showReturnDialog(context, ref, row),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Return'),
                ),
            ],
          ),
        ],
      );
}
