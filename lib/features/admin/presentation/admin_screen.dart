import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../models/enums.dart';
import '../../auth/data/auth_controller.dart';
import 'widgets/audit_tab.dart';
import 'widgets/masters_tab.dart';
import 'widgets/settings_tab.dart';
import 'widgets/users_tab.dart';

/// Administration: users and roles, master data, configurable workflow rules,
/// and the audit trail.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _controller;
  late final List<_AdminTab> _tabs;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);

    _tabs = [
      if (user?.can(P.userManage) ?? false)
        const _AdminTab('users', 'Users & Roles', Icons.people_outline_rounded),
      if (user?.can(P.masterManage) ?? false)
        const _AdminTab('masters', 'Master Data', Icons.category_outlined),
      if (user?.can(P.settingsManage) ?? false)
        const _AdminTab('settings', 'Workflow Rules', Icons.tune_rounded),
      if (user?.can(P.auditView) ?? false)
        const _AdminTab('audit', 'Audit Trail', Icons.fact_check_outlined),
    ];

    // A role with no administration permissions gets an empty tab list, so the
    // index has to be resolved before it can be clamped against it.
    final requested = widget.initialTab == null
        ? 0
        : _tabs.indexWhere((t) => t.key == widget.initialTab);
    final initialIndex =
        _tabs.isEmpty || requested < 0 ? 0 : requested.clamp(0, _tabs.length - 1);

    _controller = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return const Column(
        children: [
          PageHeader(
            breadcrumb: 'Administration',
            title: 'Administration',
          ),
          EmptyStateCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          breadcrumb: 'Administration',
          title: 'Administration',
          subtitle: 'Users and roles, master data, workflow rules and the audit trail',
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(Insets.radius),
            border: Border.all(color: AppColors.line),
          ),
          child: TabBar(
            controller: _controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(Insets.radiusSm),
            ),
            dividerColor: Colors.transparent,
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.muted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            padding: const EdgeInsets.all(6),
            tabs: [
              for (final tab in _tabs)
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 16),
                      const SizedBox(width: 8),
                      Text(tab.label),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        // A fixed height keeps each tab's own scroll view working inside the
        // shell's page scroll.
        SizedBox(
          height: (MediaQuery.sizeOf(context).height - 260).clamp(420.0, 1400.0),
          child: TabBarView(
            controller: _controller,
            children: [
              for (final tab in _tabs)
                switch (tab.key) {
                  'users' => const UsersTab(),
                  'masters' => const MastersTab(),
                  'settings' => const SettingsTab(),
                  _ => const AuditTab(),
                },
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminTab {
  const _AdminTab(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.lock_outline_rounded, size: 32, color: AppColors.muted),
              SizedBox(height: Insets.md),
              Text(
                'Administration is not available for your role.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
}
