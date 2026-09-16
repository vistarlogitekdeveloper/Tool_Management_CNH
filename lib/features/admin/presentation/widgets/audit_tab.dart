import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/report.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../reports/presentation/widgets/export_menu.dart';

/// The audit trail viewer: append-only, filterable, exportable. There is no
/// edit or delete — an audit log you can change is not an audit log.
class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});

  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

/// Query state kept local to the tab, since nothing else consumes it.
class _AuditTabState extends ConsumerState<AuditTab> {
  final _searchController = TextEditingController();
  String? _action;
  String? _module;
  int? _userId;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<PagedResult<AuditEntry>> _load() => ref.read(reportsRepositoryProvider).auditLog(
        q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        action: _action,
        module: _module,
        userId: _userId,
        from: _from,
        to: _to,
        page: _page,
      );

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(auditFiltersProvider).valueOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            controls: [
              SearchField(
                controller: _searchController,
                hintText: 'Search summary or user…',
                width: 250,
                onChanged: (_) => setState(() => _page = 1),
              ),
              if (filters != null) ...[
                FilterDropdown<String?>(
                  value: _action,
                  hint: 'All actions',
                  width: 165,
                  onChanged: (v) => setState(() {
                    _action = v;
                    _page = 1;
                  }),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All actions')),
                    for (final action in filters.actions)
                      DropdownMenuItem<String?>(
                        value: action,
                        child: Text(StatusStyles.label(action)),
                      ),
                  ],
                ),
                FilterDropdown<String?>(
                  value: _module,
                  hint: 'All modules',
                  width: 165,
                  onChanged: (v) => setState(() {
                    _module = v;
                    _page = 1;
                  }),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All modules')),
                    for (final module in filters.modules)
                      DropdownMenuItem<String?>(
                        value: module,
                        child: Text(StatusStyles.label(module)),
                      ),
                  ],
                ),
                FilterDropdown<int?>(
                  value: _userId,
                  hint: 'All users',
                  width: 175,
                  onChanged: (v) => setState(() {
                    _userId = v;
                    _page = 1;
                  }),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All users')),
                    for (final user in filters.users)
                      DropdownMenuItem<int?>(value: user.id, child: Text(user.label)),
                  ],
                ),
              ],
              SizedBox(
                width: 165,
                child: DateField(
                  value: _from,
                  hintText: 'From date',
                  clearable: true,
                  onChanged: (d) => setState(() {
                    _from = d;
                    _page = 1;
                  }),
                ),
              ),
              SizedBox(
                width: 165,
                child: DateField(
                  value: _to,
                  hintText: 'To date',
                  clearable: true,
                  firstDate: _from,
                  onChanged: (d) => setState(() {
                    _to = d;
                    _page = 1;
                  }),
                ),
              ),
            ],
            trailing: ExportButton(
              reportKey: 'audit',
              label: 'Export',
              filters: ReportFilters(from: _from, to: _to, module: _module, userId: _userId),
            ),
          ),
          SectionCard(
            padding: EdgeInsets.zero,
            child: FutureBuilder<PagedResult<AuditEntry>>(
              // Re-runs whenever a filter changes, because the key changes with it.
              key: ValueKey('$_action|$_module|$_userId|$_from|$_to|$_page|'
                  '${_searchController.text}'),
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const GridSkeleton(rows: 8);
                }
                if (snapshot.hasError) {
                  return ErrorPanel(
                    error: snapshot.error!,
                    onRetry: () => setState(() {}),
                  );
                }
                final paged = snapshot.data!;
                return Column(
                  children: [
                    DataGrid<AuditEntry>(
                      rows: paged.items,
                      minWidth: 1020,
                      rowHeight: 42,
                      emptyMessage: 'No audit entries match your filters.',
                      emptyIcon: Icons.fact_check_outlined,
                      mobileCardBuilder: (row) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              StatusChip(
                                row.action,
                                dense: true,
                                palette: _paletteFor(row.action),
                              ),
                              const Spacer(),
                              Text(
                                Fmt.dateTime(row.at),
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            row.summary ?? '—',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${row.username ?? 'system'}'
                            '${row.roleCode != null ? ' · ${row.roleCode}' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                      columns: [
                        GridColumn<AuditEntry>(
                          label: 'When',
                          width: 158,
                          cell: (row) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Fmt.dateTime(row.at),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                Fmt.ago(row.at),
                                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        GridColumn<AuditEntry>(
                          label: 'User',
                          width: 148,
                          cell: (row) => TwoLineCell(
                            primary: row.username ?? 'system',
                            secondary: row.roleCode,
                          ),
                        ),
                        GridColumn<AuditEntry>(
                          label: 'Action',
                          width: 148,
                          cell: (row) => StatusChip(
                            row.action,
                            dense: true,
                            palette: _paletteFor(row.action),
                          ),
                        ),
                        GridColumn<AuditEntry>(
                          label: 'Module',
                          width: 132,
                          hideBelow: ScreenSize.desktop,
                          cell: (row) => Text(
                            StatusStyles.label(row.module),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ),
                        GridColumn<AuditEntry>(
                          label: 'Detail',
                          flex: 5,
                          cell: (row) => Text(
                            row.summary ?? '—',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GridColumn<AuditEntry>(
                          label: 'Source',
                          width: 128,
                          hideBelow: ScreenSize.wide,
                          cell: (row) => Text(
                            row.ipAddress ?? '—',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                    PaginationBar(
                      meta: paged.meta,
                      unit: 'audit entries',
                      onPage: (page) => setState(() => _page = page),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static StatusPalette _paletteFor(String action) {
    if (action.contains('DELETE') || action.contains('REJECT') || action.contains('FAILED')) {
      return StatusPalette.red;
    }
    if (action.contains('CREATE') || action.contains('APPROVE') || action == 'LOGIN') {
      return StatusPalette.green;
    }
    if (action.contains('UPDATE') || action.contains('ADJUST') || action.contains('EXTEND')) {
      return StatusPalette.amber;
    }
    return StatusPalette.blue;
  }
}
