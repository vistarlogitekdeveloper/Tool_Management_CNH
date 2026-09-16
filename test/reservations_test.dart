import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cnh_tms/core/network/api_client.dart';
import 'package:cnh_tms/core/storage/token_storage.dart';
import 'package:cnh_tms/features/issues/data/issues_repository.dart';
import 'package:cnh_tms/models/issue.dart';

/// Tool Reservation is an RFQ *Software Development* line. The API, the
/// `reserved_qty` bucket and the nightly expiry job were all built; what was
/// missing was any way to reach them from the app.
///
/// The reserve → issue handover is the part worth pinning down: issuing against
/// a reservation has to send `reservationId`, or the server charges the issue to
/// available stock a second time and the hold is stranded in `reserved` where
/// only the expiry job can reach it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> sent;

  Future<IssuesRepository> build(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'tms.access_token': 'test-access-token',
      'tms.refresh_token': 'test-refresh-token',
    });
    final storage = await TokenStorage.create();

    final dio = Dio();
    dio.httpClientAdapter = _MockAdapter((options) {
      sent.add(options);
      return handler(options);
    });

    return IssuesRepository(
      ApiClient(storage: storage, dio: dio, baseUrl: 'https://uat-api.vistarlogitek.com/api/v1'),
    );
  }

  ResponseBody json(Object body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  Map<String, dynamic> reservationJson({
    int id = 7,
    String status = 'ACTIVE',
    int qty = 5,
    String toDate = '2026-09-30',
  }) =>
      {
        'id': id,
        'reservationNo': 'RSV-2026-0012',
        'tool': {'id': 3, 'toolCode': 'TL-1004', 'name': 'Torque Wrench 40-200Nm'},
        'employeeId': 11,
        'employeeName': 'Vikas Jadhav',
        'locationId': 4,
        'locationName': 'Assembly Bay 2',
        'qty': qty,
        'fromDate': '2026-09-20',
        'toDate': toDate,
        'status': status,
        'purpose': 'Line B changeover',
      };

  setUp(() => sent = <RequestOptions>[]);

  group('reserve()', () {
    test('posts the hold with dates the API will accept', () async {
      final repo = await build((_) async => json({'success': true, 'data': reservationJson()}));

      final saved = await repo.reserve(
        toolId: 3,
        employeeId: 11,
        qty: 5,
        fromDate: DateTime(2026, 9, 20),
        toDate: DateTime(2026, 9, 30),
        locationId: 4,
        purpose: 'Line B changeover',
      );

      expect(sent.single.method, 'POST');
      expect(sent.single.path, '/issues/reservations');

      final body = sent.single.data as Map<String, dynamic>;
      expect(body['toolId'], 3);
      expect(body['employeeId'], 11);
      expect(body['qty'], 5);
      expect(body['fromDate'], '2026-09-20', reason: 'the API validates an isoDate string');
      expect(body['toDate'], '2026-09-30');
      expect(body['locationId'], 4);
      expect(body['purpose'], 'Line B changeover');

      expect(saved.reservationNo, 'RSV-2026-0012');
      expect(saved.qty, 5);
    });

    test('omits the optional fields rather than sending nulls', () async {
      final repo = await build((_) async => json({'success': true, 'data': reservationJson()}));

      await repo.reserve(
        toolId: 3,
        employeeId: 11,
        qty: 1,
        fromDate: DateTime(2026, 9, 20),
        toDate: DateTime(2026, 9, 20),
      );

      final body = sent.single.data as Map<String, dynamic>;
      expect(body.containsKey('locationId'), isFalse);
      expect(body.containsKey('purpose'), isFalse);
    });
  });

  group('listing and cancelling', () {
    test('filters by status', () async {
      final repo = await build((_) async => json({
            'success': true,
            'data': [reservationJson(), reservationJson(id: 8, status: 'ACTIVE')],
          }));

      final rows = await repo.reservations(status: 'ACTIVE');

      expect(sent.single.method, 'GET');
      expect(sent.single.path, '/issues/reservations');
      expect(sent.single.queryParameters['status'], 'ACTIVE');
      expect(rows, hasLength(2));
    });

    test('cancel posts the reason so it lands on the stock ledger', () async {
      final repo = await build(
        (_) async => json({'success': true, 'data': reservationJson(status: 'CANCELLED')}),
      );

      final cancelled = await repo.cancelReservation(7, reason: 'Job pulled forward');

      expect(sent.single.method, 'POST');
      expect(sent.single.path, '/issues/reservations/7/cancel');
      expect((sent.single.data as Map)['reason'], 'Job pulled forward');
      expect(cancelled.status, 'CANCELLED');
    });
  });

  group('reserve → issue handover', () {
    test('issuing against a reservation sends reservationId', () async {
      final repo = await build((_) async => json({
            'success': true,
            'data': {
              'id': 91,
              'issueNo': 'ISS-2026-00133',
              'tool': {'id': 3, 'toolCode': 'TL-1004', 'name': 'Torque Wrench 40-200Nm'},
              'employee': {'id': 11, 'code': 'E-2231', 'name': 'Vikas Jadhav'},
              'qtyIssued': 5,
              'qtyReturned': 0,
              'status': 'ISSUED',
            },
          }));

      await repo.issue(const IssueRequest(
        toolId: 3,
        employeeId: 11,
        qty: 5,
        reservationId: 7,
      ));

      final body = sent.single.data as Map<String, dynamic>;
      expect(body['reservationId'], 7,
          reason: 'without this the server charges available stock again and the held '
              'quantity is stranded in reserved_qty');
    });

    test('an ordinary issue carries no reservationId at all', () async {
      final repo = await build((_) async => json({
            'success': true,
            'data': {
              'id': 92,
              'issueNo': 'ISS-2026-00134',
              'tool': {'id': 3, 'toolCode': 'TL-1004', 'name': 'Torque Wrench'},
              'employee': {'id': 11, 'code': 'E-2231', 'name': 'Vikas Jadhav'},
              'qtyIssued': 1,
              'qtyReturned': 0,
              'status': 'ISSUED',
            },
          }));

      await repo.issue(const IssueRequest(toolId: 3, employeeId: 11, qty: 1));

      expect((sent.single.data as Map).containsKey('reservationId'), isFalse);
    });
  });

  group('Reservation model', () {
    test('parses the ids the issue dialog prefills from', () {
      // The mapper used to return display names only, so "Issue against this
      // reservation" had nobody to default the employee and station to.
      final r = Reservation.fromJson(reservationJson());
      expect(r.employeeId, 11);
      expect(r.locationId, 4);
      expect(r.employeeName, 'Vikas Jadhav');
      expect(r.locationName, 'Assembly Bay 2');
      expect(r.tool.toolCode, 'TL-1004');
    });

    test('daysRemaining counts whole days and goes negative once the window passes', () {
      final today = DateTime.now();
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final future = Reservation.fromJson(
        reservationJson(toDate: iso(today.add(const Duration(days: 3)))),
      );
      final endsToday = Reservation.fromJson(reservationJson(toDate: iso(today)));
      final passed = Reservation.fromJson(
        reservationJson(toDate: iso(today.subtract(const Duration(days: 2)))),
      );

      expect(future.daysRemaining, 3);
      expect(endsToday.daysRemaining, 0);
      expect(passed.daysRemaining, -2);
    });

    test('isLapsing flags an active hold whose window is up, and only an active one', () {
      final today = DateTime.now();
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      expect(Reservation.fromJson(reservationJson(toDate: iso(today))).isLapsing, isTrue);
      expect(
        Reservation.fromJson(reservationJson(toDate: iso(today.add(const Duration(days: 5)))))
            .isLapsing,
        isFalse,
      );
      // A fulfilled reservation is not holding anything, so it never lapses.
      expect(
        Reservation.fromJson(reservationJson(status: 'FULFILLED', toDate: iso(today))).isLapsing,
        isFalse,
      );
    });
  });
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
