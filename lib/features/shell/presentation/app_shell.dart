import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/enums.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../auth/data/auth_controller.dart';
import '../../calibration/data/calibration_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import 'widgets/notification_menu.dart';
import 'widgets/side_nav.dart';
import 'widgets/top_bar.dart';

/// The application chrome: permanent sidebar on desktop, drawer on a tablet or
/// phone, sticky top bar, and the routed page in the middle.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _notificationsLink = LayerLink();
  OverlayEntry? _notificationOverlay;

  @override
  void dispose() {
    _removeNotifications();
    super.dispose();
  }

  void _removeNotifications() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  void _toggleNotifications() {
    if (_notificationOverlay != null) {
      _removeNotifications();
      return;
    }
    _notificationOverlay = OverlayEntry(
      builder: (context) => NotificationMenu(
        link: _notificationsLink,
        onDismiss: _removeNotifications,
        onOpen: (route) {
          _removeNotifications();
          if (route != null) context.go(route);
        },
      ),
    );
    Overlay.of(context).insert(_notificationOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeModule = Routes.moduleFor(widget.location) ?? AppModule.dashboard;
    final badges = _badges(ref);
    final permanent = context.hasPermanentSidebar;

    final nav = SideNav(
      user: user,
      activeModule: activeModule,
      badges: badges,
      onSelect: (module) {
        if (!permanent) Navigator.of(context).pop();
        context.go(Routes.forModule(module));
      },
      onLogout: () async {
        if (!permanent) Navigator.of(context).pop();
        await ref.read(authControllerProvider.notifier).logout();
      },
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: permanent ? null : Drawer(width: 258, child: nav),
      body: Row(
        children: [
          if (permanent) SizedBox(width: 236, child: nav),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  user: user,
                  notificationsLink: _notificationsLink,
                  unreadCount: ref.watch(unreadCountProvider),
                  calibrationDue: badges[AppModule.calibration] ?? 0,
                  onMenu: permanent ? null : () => _scaffoldKey.currentState?.openDrawer(),
                  onNotifications: _toggleNotifications,
                  onSearch: (term) => context.go('${Routes.tools}?q=$term'),
                  onOpenCalibration: () => context.go(Routes.calibration),
                  onLogout: () => ref.read(authControllerProvider.notifier).logout(),
                ),
                Expanded(
                  child: GestureDetector(
                    // Tapping the page dismisses an open notification menu.
                    behavior: HitTestBehavior.translucent,
                    onTap: _notificationOverlay == null ? null : _removeNotifications,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          context.pageGutter,
                          Insets.xl,
                          context.pageGutter,
                          60,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1560),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar badge counts. Each is optional — a role without the permission
  /// simply never loads that provider.
  Map<AppModule, int> _badges(WidgetRef ref) {
    final lowStock = ref.watch(inventorySummaryProvider).valueOrNull?.lowStockCount ?? 0;
    final calibration = ref.watch(calibrationSummaryProvider).valueOrNull?.dueTotal ?? 0;
    final alerts = ref.watch(alertSummaryProvider).valueOrNull;
    return {
      AppModule.inventory: lowStock,
      AppModule.calibration: calibration,
      AppModule.issueReturn: alerts?.overdueReturns ?? 0,
    };
  }
}
