import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:vistar_event_tracker/vistar_event_tracker.dart'
    show EventType, TrackerConfig, VistarEventTracker, VistarEvents;

import '../config/app_config.dart';

/// Usage analytics for the CNH Tool Management System, sent to the in-house
/// event tracker and read in the Platform Console under Analytics > Event
/// tracker.
///
/// Off unless the build is given both:
///   --dart-define=ET_APP_ID=tms_app --dart-define=ET_WRITE_KEY=wk_...
/// (register the app in the Platform Console, Settings > Event tracker; the
/// write key only lets a client append events, so it may ship in the app).
/// Optional --dart-define=ET_BASE_URL=... sends a test build's events
/// somewhere other than the API host the app uses (by default, the host of
/// AppConfig.apiBaseUrl, so a UAT build reports to UAT).
///
/// What is sent:
///   * screen views, by route pattern (`/tools`, `/reports/calibration`), and the
///     detail panels opened over them (`/tools/:id`, `/purchase/:id`,
///     `/tracking/locate/:id`)
///   * sign-in / sign-out; the user as `tms:<user id>`, with their role code
///     as a trait (the TMS has no organisation; it is one plant)
///   * named actions from successful API writes (see [_actions]):
///     `tool_issued`, `tool_returned`, `calibration_recorded`, ...
///   * failed API calls (5xx or no connection), and client errors by TYPE
///     only (never the message, which can quote a server reply)
/// Never sent: request or response bodies, tool codes or serial numbers,
/// employee names or codes, usernames, emails, phone numbers, vendor names,
/// PO numbers, quantities, amounts, reasons, remarks, or any other record
/// content.
///
/// NEVER IN THE WAY OF WORK. Nothing here is awaited by a screen, an issue or
/// return, a sign-in or a sign-out; start-up waits at most [_initBudget];
/// every call swallows its own failures; the queue is capped at [_maxQueue]
/// events (oldest dropped) and lives in shared preferences; sending is in the
/// background with the SDK's backoff.
abstract final class Telemetry {
  static const _appId = String.fromEnvironment('ET_APP_ID');
  static const _writeKey = String.fromEnvironment('ET_WRITE_KEY');
  static const _baseUrlOverride = String.fromEnvironment('ET_BASE_URL');
  static const _appVersion = String.fromEnvironment('APP_VERSION');
  static const _initBudget = Duration(seconds: 2);
  static const _maxQueue = 200;

  /// Names for the detail panels shown over the router's screens (a dialog on
  /// a desktop, a pushed page on a phone; no route of their own).
  static const toolDetailScreen = '/tools/:id';
  static const purchaseOrderScreen = '/purchase/:id';
  static const locateToolScreen = '/tracking/locate/:id';

  static bool get enabled => _appId != '' && _writeKey != '';

  static VistarEventTracker get _t => VistarEventTracker.instance;
  static bool get _on => enabled && _t.isInitialized;

  static String? _lastScreen;
  static String? _routerScreen;
  static final _covers = <String>[];
  static String? _identity;
  static Future<void>? _resetting;

  static String get _origin {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    final u = Uri.parse(AppConfig.apiBaseUrl);
    return '${u.scheme}://${u.authority}';
  }

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await _t
          .init(TrackerConfig(
            appId: _appId,
            writeKey: _writeKey,
            baseUrl: _origin,
            appVersion: _appVersion.isEmpty ? AppConfig.appVersion : _appVersion,
            maxQueueSize: _maxQueue,
            // The SDK's own error capture sends the exception message and
            // stack, and a message here can quote a server reply (a tool
            // code, an employee). [_captureErrors] sends the type only.
            autoCaptureErrors: false,
          ))
          .timeout(_initBudget);
      _captureErrors();
    } catch (_) {
      // Analytics must never stop the app from starting.
    }
  }

  /// Client errors, by type only. Chains to whatever handled them before, so
  /// the app's own error handling is unchanged.
  static void _captureErrors() {
    if (!_on) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _clientError(details.exception, fatal: false, library: details.library);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _clientError(error, fatal: true);
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  static void _clientError(Object e, {required bool fatal, String? library}) {
    try {
      error(VistarEvents.clientError, {
        'error': e.runtimeType.toString(),
        'library': ?library,
        'fatal': fatal,
      });
    } catch (_) {}
  }

  /// A screen the router shows, by its route pattern. Repeats are dropped.
  static void screen(String location) {
    if (!_on) return;
    final name = routePattern(location);
    _routerScreen = name;
    _report(name);
  }

  /// A detail panel opened over the router's screen ([toolDetailScreen], ...),
  /// possibly over another panel (a tool opened from the locate panel).
  static void covering(String name) {
    if (!_on) return;
    _covers.add(name);
    _report(name);
  }

  /// That panel closed: back on the panel or the router's screen beneath.
  static void uncovered(String name) {
    if (!_on) return;
    final i = _covers.lastIndexOf(name);
    if (i >= 0) _covers.removeAt(i);
    final beneath = _covers.isEmpty ? _routerScreen : _covers.last;
    if (beneath != null) _report(beneath);
  }

  static void _report(String name) {
    if (name == _lastScreen) return;
    _lastScreen = name;
    _guard(() => _t.screen(name));
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_on) _guard(() => _t.track(name, properties: properties));
  }

  static void error(String name, Map<String, dynamic> properties) {
    if (_on) _guard(() => _t.track(name, properties: properties, type: EventType.error));
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // Analytics never surfaces as an app error.
    }
  }

  /// Fire and forget: the sign-in never waits for analytics.
  ///
  /// Called just BEFORE the auth state changes. With no sign-out in flight the
  /// SDK sets the user synchronously (before its first await), so the screen
  /// the sign-in leads to is already attributed to them. A repeat for the
  /// same user and role (a restored session confirmed by the server) is
  /// dropped.
  static void signedIn({required String userId, String? role}) {
    if (!_on || userId.isEmpty) return;
    final id = 'tms:$userId';
    final traits = <String, dynamic>{
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final identity = '$id|$role';
    if (identity == _identity) return;
    _identity = identity;
    final pending = _resetting;
    if (pending == null) {
      _identify(id, traits);
      return;
    }
    // A sign-out just before (a shared tool-room terminal changing hands)
    // resets the identity; let it finish so this one is not wiped by it.
    unawaited(() async {
      try {
        await pending.timeout(const Duration(seconds: 5), onTimeout: () {});
      } catch (_) {}
      _identify(id, traits);
    }());
  }

  static void _identify(String id, Map<String, dynamic> traits) {
    try {
      unawaited(_t.identify(id, traits: traits).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Fire and forget: the sign-out never waits for analytics (the SDK's reset
  /// sends what is queued first, which can take a while on a poor network).
  static void signedOut() {
    if (!_on) return;
    _lastScreen = null;
    _identity = null;
    _covers.clear();
    try {
      late final Future<void> done;
      done = _t.reset().catchError((Object _) {}).whenComplete(() {
        if (identical(_resetting, done)) _resetting = null;
      });
      _resetting = done;
    } catch (_) {}
  }

  /// `/issues/42/return?x=1` -> `/issues/:id/return`.
  ///
  /// Any segment with a digit in it is replaced: numbers and uuids become
  /// `:id`; everything else with a digit (a month such as `2026-09`) becomes
  /// `:ref`. The query string (tool ids, filters) is dropped. An API version
  /// segment (`v1`) is kept, and so are the report keys from the server's
  /// fixed catalogue (`/reports/calibration`, `/reports/low-stock`).
  /// Tool codes, serial numbers and employee codes never appear in this app's
  /// paths (records are addressed by numeric id), and would be replaced if
  /// they did.
  static String routePattern(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    return path.split('/').map((s) {
      if (s.isEmpty) return s;
      if (RegExp(r'^\d+$').hasMatch(s)) return ':id';
      if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-', caseSensitive: false).hasMatch(s)) return ':id';
      if (RegExp(r'^v\d{1,2}$').hasMatch(s)) return s;
      if (RegExp(r'\d').hasMatch(s)) return ':ref';
      return s;
    }).join('/');
  }

  static const _id = r':(id|ref)';

  /// Masters behind every dropdown, and the event-name stem for each.
  static const _masters = [
    ('categories', 'tool_category'),
    ('locations', 'location'),
    ('departments', 'department'),
    ('employees', 'employee'),
    ('vendors', 'vendor'),
  ];

  /// Successful API writes worth naming, by method and path (ids stripped;
  /// paths are relative to API_BASE_URL, `.../api/v1/tool-management`). First
  /// match wins; anything else (reads, exports, sign-in, unknown paths) is
  /// not reported.
  static final List<(String, RegExp, String)> _actions = [
    // Tool master
    ('POST', RegExp(r'^/tools$'), 'tool_created'),
    ('PATCH', RegExp('^/tools/$_id\$'), 'tool_updated'),
    ('DELETE', RegExp('^/tools/$_id\$'), 'tool_deactivated'),
    // Stock
    ('POST', RegExp(r'^/inventory/adjust$'), 'stock_adjusted'),
    // Issue and return
    ('POST', RegExp(r'^/issues$'), 'tool_issued'),
    ('POST', RegExp('^/issues/$_id/return\$'), 'tool_returned'),
    ('POST', RegExp('^/issues/$_id/extend\$'), 'issue_extended'),
    ('POST', RegExp(r'^/issues/reservations$'), 'reservation_created'),
    ('POST', RegExp('^/issues/reservations/$_id/cancel\$'), 'reservation_cancelled'),
    // Tracking
    ('POST', RegExp(r'^/tracking/transfers$'), 'tool_transferred'),
    // Calibration
    ('POST', RegExp(r'^/calibration$'), 'calibration_recorded'),
    ('POST', RegExp(r'^/calibration/plan$'), 'calibration_plan_saved'),
    // Repair and scrap
    ('POST', RegExp(r'^/maintenance$'), 'maintenance_requested'),
    ('POST', RegExp('^/maintenance/$_id/decision\$'), 'maintenance_decided'),
    ('POST', RegExp('^/maintenance/$_id/complete\$'), 'maintenance_completed'),
    // Purchase
    ('POST', RegExp(r'^/purchase$'), 'purchase_order_created'),
    ('POST', RegExp('^/purchase/$_id/approve\$'), 'purchase_order_approved'),
    ('POST', RegExp('^/purchase/$_id/in-transit\$'), 'purchase_order_in_transit'),
    ('POST', RegExp('^/purchase/$_id/receive\$'), 'purchase_order_received'),
    // Attachments (drawings, photos, certificates)
    ('POST', RegExp(r'^/files$'), 'file_uploaded'),
    ('DELETE', RegExp('^/files/$_id\$'), 'file_deleted'),
    // Alerts
    ('POST', RegExp('^/alerts/$_id/acknowledge\$'), 'alert_acknowledged'),
    ('POST', RegExp(r'^/alerts/sweep$'), 'alert_sweep_run'),
    ('POST', RegExp(r'^/alerts/notifications/read$'), 'notifications_read'),
    ('POST', RegExp(r'^/alerts/deliveries/dispatch$'), 'alert_deliveries_dispatched'),
    ('POST', RegExp(r'^/alerts/deliveries/test$'), 'alert_delivery_tested'),
    // Masters: <master>_created / _updated / _deactivated
    for (final (path, master) in _masters) ...[
      ('POST', RegExp('^/masters/$path\$'), '${master}_created'),
      ('PATCH', RegExp('^/masters/$path/$_id\$'), '${master}_updated'),
      ('DELETE', RegExp('^/masters/$path/$_id\$'), '${master}_deactivated'),
    ],
    // Administration
    ('PUT', RegExp(r'^/settings/[^/]+$'), 'setting_updated'),
    ('POST', RegExp(r'^/users$'), 'user_created'),
    ('PATCH', RegExp('^/users/$_id\$'), 'user_updated'),
    ('POST', RegExp('^/users/$_id/reset-password\$'), 'user_password_reset'),
    ('POST', RegExp('^/users/$_id/unlock\$'), 'user_unlocked'),
    ('PUT', RegExp('^/users/roles/$_id/permissions\$'), 'role_permissions_changed'),
    // Account
    ('POST', RegExp(r'^/auth/change-password$'), 'password_changed'),
  ];

  /// The business event for a successful API call, or null.
  static String? actionFor(String method, String path) {
    final pattern = routePattern(path);
    final m = method.toUpperCase();
    for (final (am, re, name) in _actions) {
      if (am == m && re.hasMatch(pattern)) return name;
    }
    return null;
  }
}

/// Reports named actions and failed calls from the app's one HTTP client
/// (core/network/api_client.dart). Adds no headers and changes nothing about
/// the request or its handling.
class TelemetryInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // The client's validateStatus lets every status below 500 through to here
    // (so its auth interceptor can refresh on a 401): only a 2xx is an action
    // that happened, and not one whose envelope says `success: false`.
    final code = response.statusCode ?? 0;
    if (Telemetry.enabled && code >= 200 && code < 300) {
      String? name;
      try {
        final body = response.data;
        final refused = body is Map && body['success'] == false;
        final o = response.requestOptions;
        if (!refused) name = Telemetry.actionFor(o.method, o.path);
      } catch (_) {}
      if (name != null) Telemetry.track(name);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Telemetry.enabled) {
      try {
        final status = err.response?.statusCode;
        // Only a 5xx or a failed connection arrives here as a server error (a
        // 4xx is a response, above); a cancel is the app's own.
        if ((status == null || status >= 500) && err.type != DioExceptionType.cancel) {
          Telemetry.error('api_error', {
            'endpoint': Telemetry.routePattern(err.requestOptions.path),
            'method': err.requestOptions.method,
            'status': ?status,
            'kind': err.type.name,
          });
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
