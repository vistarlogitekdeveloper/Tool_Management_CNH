import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/enums.dart';
import '../../../../models/user.dart';

/// The dark sidebar. Items come from the signed-in role's module list, so the
/// navigation is the role — exactly what the deck promises.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.user,
    required this.activeModule,
    required this.onSelect,
    required this.onLogout,
    this.badges = const {},
  });

  final AuthUser user;
  final AppModule activeModule;
  final void Function(AppModule module) onSelect;
  final VoidCallback onLogout;
  final Map<AppModule, int> badges;

  static const _sections = <String, List<AppModule>>{
    'Overview': [AppModule.dashboard],
    'Tool Lifecycle': [
      AppModule.toolMaster,
      AppModule.inventory,
      AppModule.issueReturn,
      AppModule.tracking,
      AppModule.calibration,
      AppModule.repairScrap,
      AppModule.purchase,
    ],
    'Insights': [AppModule.reports],
    'Administration': [AppModule.admin],
  };

  static const _icons = <AppModule, IconData>{
    AppModule.dashboard: Icons.dashboard_outlined,
    AppModule.toolMaster: Icons.inventory_2_outlined,
    AppModule.inventory: Icons.widgets_outlined,
    AppModule.issueReturn: Icons.swap_horiz_rounded,
    AppModule.tracking: Icons.my_location_rounded,
    AppModule.calibration: Icons.schedule_rounded,
    AppModule.repairScrap: Icons.handyman_outlined,
    AppModule.purchase: Icons.shopping_cart_outlined,
    AppModule.reports: Icons.assessment_outlined,
    AppModule.admin: Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.md),
              children: [
                for (final entry in _sections.entries) ..._section(entry.key, entry.value),
              ],
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _brand() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'CNH',
                style: TextStyle(
                  color: AppColors.navBg,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 19,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'TMS · PUNE',
                style: TextStyle(
                  color: Color(0xFF8EA3BD),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  List<Widget> _section(String title, List<AppModule> modules) {
    final visible = modules.where(user.canSee).toList();
    if (visible.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.5,
            color: AppColors.navSection,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final module in visible) _navItem(module),
    ];
  }

  Widget _navItem(AppModule module) {
    final active = module == activeModule;
    final badge = badges[module] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0.5),
      child: Material(
        color: active ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: () => onSelect(module),
          borderRadius: BorderRadius.circular(7),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 9),
            child: Row(
              children: [
                Icon(
                  _icons[module],
                  size: 17,
                  color: active ? Colors.white : AppColors.navText.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    module.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: active ? Colors.white : AppColors.navText,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge > 0) CountBadge(badge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Web-Based TMS · v${AppConfig.appVersion}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.navFoot),
            ),
            const SizedBox(height: 3),
            Text(
              'Role: ${user.role.name}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.navFoot),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.sm),
            InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, size: 13, color: AppColors.navFoot),
                    SizedBox(width: 6),
                    Text(
                      'Log out',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.navFoot,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.navFoot,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
