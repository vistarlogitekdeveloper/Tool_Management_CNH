
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/auth/data/auth_controller.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/calibration/presentation/calibration_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/issues/presentation/issues_screen.dart';
import '../../features/maintenance/presentation/maintenance_screen.dart';
import '../../features/purchase/presentation/purchase_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/tools/presentation/tool_master_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../models/enums.dart';
import '../widgets/async_view.dart';

/// Route paths, in one place so nothing navigates by a hand-typed string.
abstract final class Routes {
  static const login = '/login';
  static const changePassword = '/change-password';
  static const dashboard = '/';
  static const tools = '/tools';
  static const inventory = '/inventory';
  static const issues = '/issues';
  static const tracking = '/tracking';
  static const calibration = '/calibration';
  static const maintenance = '/maintenance';
  static const purchase = '/purchase';
  static const reports = '/reports';
  static const alerts = '/alerts';
  static const admin = '/admin';

  static String report(String key) => '/reports/$key';

  /// The route each sidebar module points at.
  static String forModule(AppModule module) => switch (module) {
        AppModule.dashboard => dashboard,
        AppModule.toolMaster => tools,
        AppModule.inventory => inventory,
        AppModule.issueReturn => issues,
        AppModule.tracking => tracking,
        AppModule.calibration => calibration,
        AppModule.repairScrap => maintenance,
        AppModule.purchase => purchase,
        AppModule.reports => reports,
        AppModule.admin => admin,
      };

  /// The module a path belongs to, for highlighting the active nav item.
  static AppModule? moduleFor(String location) {
    if (location == dashboard) return AppModule.dashboard;
    for (final module in AppModule.values) {
      final route = forModule(module);
      if (route != dashboard && location.startsWith(route)) return module;
    }
    return null;
  }
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final atLogin = state.matchedLocation == Routes.login;

      // Hold every route until the cached session has been checked, so a signed-in
      // user never sees the login screen flash on a cold start.
      if (!auth.isResolved) return null;

      if (!auth.isAuthenticated) return atLogin ? null : Routes.login;

      // A forced password change closes the whole app until it is done. The server
      // refuses every other endpoint anyway, so without this the user would land on
      // a dashboard of failed requests with no way to fix it.
      final atChangePassword = state.matchedLocation == Routes.changePassword;
      if (auth.user?.mustChangePassword ?? false) {
        return atChangePassword ? null : Routes.changePassword;
      }
      if (atChangePassword) return Routes.dashboard;

      if (atLogin) return Routes.dashboard;

      // Deep link into a module the role cannot see: land them somewhere useful
      // rather than on an error.
      final module = Routes.moduleFor(state.matchedLocation);
      if (module != null && !(auth.user?.canSee(module) ?? false)) {
        final first = auth.user?.visibleModules.firstOrNull;
        return first == null ? Routes.dashboard : Routes.forModule(first);
      }
      return null;
    },

    routes: [
      GoRoute(
        path: Routes.login,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.changePassword,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) => _fade(state, const DashboardScreen()),
          ),
          GoRoute(
            path: Routes.tools,
            pageBuilder: (context, state) => _fade(
              state,
              ToolMasterScreen(initialToolId: int.tryParse(state.uri.queryParameters['toolId'] ?? '')),
            ),
          ),
          GoRoute(
            path: Routes.inventory,
            pageBuilder: (context, state) => _fade(
              state,
              InventoryScreen(lowStockOnly: state.uri.queryParameters['low'] == '1'),
            ),
          ),
          GoRoute(
            path: Routes.issues,
            pageBuilder: (context, state) => _fade(
              state,
              IssuesScreen(initialStatus: state.uri.queryParameters['status']),
            ),
          ),
          GoRoute(
            path: Routes.tracking,
            pageBuilder: (context, state) => _fade(state, const TrackingScreen()),
          ),
          GoRoute(
            path: Routes.calibration,
            pageBuilder: (context, state) => _fade(
              state,
              CalibrationScreen(initialStatus: state.uri.queryParameters['status']),
            ),
          ),
          GoRoute(
            path: Routes.maintenance,
            pageBuilder: (context, state) => _fade(
              state,
              MaintenanceScreen(initialApproval: state.uri.queryParameters['approval']),
            ),
          ),
          GoRoute(
            path: Routes.purchase,
            pageBuilder: (context, state) => _fade(state, const PurchaseScreen()),
          ),
          GoRoute(
            path: Routes.reports,
            pageBuilder: (context, state) => _fade(state, const ReportsScreen()),
            routes: [
              GoRoute(
                path: ':key',
                pageBuilder: (context, state) =>
                    _fade(state, ReportDetailScreen(reportKey: state.pathParameters['key']!)),
              ),
            ],
          ),
          GoRoute(
            path: Routes.alerts,
            pageBuilder: (context, state) => _fade(state, const AlertsScreen()),
          ),
          GoRoute(
            path: Routes.admin,
            pageBuilder: (context, state) => _fade(
              state,
              AdminScreen(initialTab: state.uri.queryParameters['tab']),
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: ErrorPanel(
          error: 'No screen matches ${state.uri}',
          onRetry: () => context.go(Routes.dashboard),
        ),
      ),
    ),
  );
});

/// Cross-fade between shell pages — the prototype's `.screen` transition.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );

/// Bridges Riverpod's auth state into GoRouter's `refreshListenable`.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        // Also fire when a forced password change clears — the status stays
        // `authenticated` throughout, so watching it alone would strand the user
        // on the change-password screen after a successful update.
        if (previous?.status != next.status ||
            previous?.user?.mustChangePassword != next.user?.mustChangePassword) {
          notifyListeners();
        }
      },
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
