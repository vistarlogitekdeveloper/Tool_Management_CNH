import 'dart:convert';
import 'dart:typed_data';

import 'package:cnh_tms/core/telemetry/telemetry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen names carry no record ids or filters', () {
    expect(Telemetry.routePattern('/'), '/');
    expect(Telemetry.routePattern('/tools?toolId=1002'), '/tools');
    expect(Telemetry.routePattern('/inventory?low=1'), '/inventory');
    expect(Telemetry.routePattern('/issues?status=OVERDUE'), '/issues');
    expect(Telemetry.routePattern('/admin?tab=users'), '/admin');
    expect(Telemetry.routePattern('/reports/calibration'), '/reports/calibration');
    expect(Telemetry.routePattern('/reports/low-stock?from=2026-09-01'), '/reports/low-stock');
  });

  test('tool codes, serials, employee codes and months become :ref', () {
    expect(Telemetry.routePattern('/tools/TL-1002'), '/tools/:ref');
    expect(Telemetry.routePattern('/tools/SN%2F2026%2F0042'), '/tools/:ref');
    expect(Telemetry.routePattern('/masters/employees/EMP0042'), '/masters/employees/:ref');
    expect(Telemetry.routePattern('/calibration/plan/2026-09'), '/calibration/plan/:ref');
    expect(Telemetry.routePattern('/issues/42/return'), '/issues/:id/return');
    expect(Telemetry.routePattern('https://uat-api.example.com/api/v1/tool-management/tools/42'),
        '/api/v1/tool-management/tools/:id');
  });

  test('the tool lifecycle is named from successful writes', () {
    expect(Telemetry.actionFor('POST', '/tools'), 'tool_created');
    expect(Telemetry.actionFor('PATCH', '/tools/42'), 'tool_updated');
    expect(Telemetry.actionFor('DELETE', '/tools/42'), 'tool_deactivated');
    expect(Telemetry.actionFor('POST', '/inventory/adjust'), 'stock_adjusted');
    expect(Telemetry.actionFor('POST', '/issues'), 'tool_issued');
    expect(Telemetry.actionFor('POST', '/issues/42/return'), 'tool_returned');
    expect(Telemetry.actionFor('POST', '/issues/42/extend'), 'issue_extended');
    expect(Telemetry.actionFor('POST', '/issues/reservations'), 'reservation_created');
    expect(Telemetry.actionFor('POST', '/issues/reservations/7/cancel'), 'reservation_cancelled');
    expect(Telemetry.actionFor('POST', '/tracking/transfers'), 'tool_transferred');
    expect(Telemetry.actionFor('POST', '/calibration'), 'calibration_recorded');
    expect(Telemetry.actionFor('POST', '/calibration/plan'), 'calibration_plan_saved');
    expect(Telemetry.actionFor('POST', '/maintenance'), 'maintenance_requested');
    expect(Telemetry.actionFor('POST', '/maintenance/9/decision'), 'maintenance_decided');
    expect(Telemetry.actionFor('POST', '/maintenance/9/complete'), 'maintenance_completed');
    expect(Telemetry.actionFor('POST', '/purchase'), 'purchase_order_created');
    expect(Telemetry.actionFor('POST', '/purchase/3/approve'), 'purchase_order_approved');
    expect(Telemetry.actionFor('POST', '/purchase/3/in-transit'), 'purchase_order_in_transit');
    expect(Telemetry.actionFor('POST', '/purchase/3/receive'), 'purchase_order_received');
    expect(Telemetry.actionFor('POST', '/files'), 'file_uploaded');
    expect(Telemetry.actionFor('DELETE', '/files/12'), 'file_deleted');
    expect(Telemetry.actionFor('POST', '/alerts/5/acknowledge'), 'alert_acknowledged');
    expect(Telemetry.actionFor('POST', '/alerts/sweep'), 'alert_sweep_run');
    expect(Telemetry.actionFor('POST', '/alerts/notifications/read'), 'notifications_read');
    expect(Telemetry.actionFor('POST', '/alerts/deliveries/dispatch'), 'alert_deliveries_dispatched');
    expect(Telemetry.actionFor('POST', '/alerts/deliveries/test'), 'alert_delivery_tested');
  });

  test('masters and administration are named too', () {
    expect(Telemetry.actionFor('POST', '/masters/categories'), 'tool_category_created');
    expect(Telemetry.actionFor('PATCH', '/masters/locations/3'), 'location_updated');
    expect(Telemetry.actionFor('DELETE', '/masters/departments/3'), 'department_deactivated');
    expect(Telemetry.actionFor('POST', '/masters/employees'), 'employee_created');
    expect(Telemetry.actionFor('PATCH', '/masters/vendors/8'), 'vendor_updated');
    expect(Telemetry.actionFor('PUT', '/settings/calibration.reminder_days'), 'setting_updated');
    expect(Telemetry.actionFor('PUT', '/settings/alert_window_7'), 'setting_updated');
    expect(Telemetry.actionFor('post', '/users'), 'user_created');
    expect(Telemetry.actionFor('PATCH', '/users/4'), 'user_updated');
    expect(Telemetry.actionFor('POST', '/users/4/reset-password'), 'user_password_reset');
    expect(Telemetry.actionFor('POST', '/users/4/unlock'), 'user_unlocked');
    expect(Telemetry.actionFor('PUT', '/users/roles/2/permissions'), 'role_permissions_changed');
    expect(Telemetry.actionFor('POST', '/auth/change-password'), 'password_changed');
  });

  test('reads, exports, sign-in and unknown paths are not reported', () {
    expect(Telemetry.actionFor('GET', '/tools'), isNull);
    expect(Telemetry.actionFor('GET', '/tools/42/history'), isNull);
    expect(Telemetry.actionFor('GET', '/tracking/locate/42'), isNull);
    expect(Telemetry.actionFor('GET', '/reports/calibration'), isNull);
    expect(Telemetry.actionFor('GET', '/files/12'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/login'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/logout'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/refresh'), isNull);
    expect(Telemetry.actionFor('POST', '/masters/unknown'), isNull);
    expect(Telemetry.actionFor('DELETE', '/issues/42'), isNull);
  });

  test('off without ET_APP_ID and ET_WRITE_KEY (the default build); calls are safe', () async {
    expect(Telemetry.enabled, isFalse);
    await Telemetry.init();
    Telemetry.screen('/tools');
    Telemetry.covering(Telemetry.toolDetailScreen);
    Telemetry.uncovered(Telemetry.toolDetailScreen);
    Telemetry.track('tool_issued');
    Telemetry.error('api_error', {'endpoint': '/issues', 'method': 'POST'});
    Telemetry.signedIn(userId: '1', role: 'ADMIN');
    Telemetry.signedOut();
  });

  test('the interceptor changes nothing about a request or its outcome', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid', validateStatus: (s) => s != null && s < 500))
      ..httpClientAdapter = _Answer()
      ..interceptors.add(TelemetryInterceptor());
    final ok = await dio.post<dynamic>('/issues', data: {'x': 1});
    expect(ok.statusCode, 201);
    expect((ok.data as Map)['success'], isTrue);
    final refused = await dio.post<dynamic>('/issues/42/return');
    expect(refused.statusCode, 409);
    await expectLater(
      dio.post<dynamic>('/tracking/transfers'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
  });
}

/// 201 for an issue, 409 for a return, 503 for anything else; no network.
class _Answer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final status = switch (options.path) {
      '/issues' => 201,
      '/issues/42/return' => 409,
      _ => 503,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': status == 201}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
