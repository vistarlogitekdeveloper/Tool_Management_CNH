import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Override per environment without touching code:
///   flutter run  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
///   flutter build web --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
abstract final class AppConfig {
  static const appName = 'CNH Tool Management System';
  static const shortName = 'TMS';
  static const plantName = 'CNH Pune Plant';
  static const vendor = 'Vistarlogitek';
  static const appVersion = '1.0.0';

  static const _defaultBaseUrl = 'http://localhost:4000/api/v1';

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 45);

  /// How often the dashboard and alert bell re-poll while the app is open.
  static const dashboardRefreshInterval = Duration(minutes: 2);
  static const alertPollInterval = Duration(minutes: 3);

  static const pageSize = 25;

  /// Layout breakpoints — the sidebar collapses below `desktop`.
  static const mobileBreakpoint = 720.0;
  static const tabletBreakpoint = 1050.0;
  static const desktopBreakpoint = 1280.0;

  static bool get isDebug => kDebugMode;
}
