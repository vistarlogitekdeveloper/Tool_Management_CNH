import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cnh_tms/core/network/api_client.dart';
import 'package:cnh_tms/core/storage/token_storage.dart';
import 'package:cnh_tms/features/files/data/files_repository.dart';

/// The RFQ asks for drawing (PDF/DWG), tool image and calibration certificate
/// upload. The API and the schema always supported it; what was missing was a
/// client that ever called `POST /files`.
///
/// These tests hold the wiring in place: the right endpoint, the right category,
/// a bearer header rather than a token in the URL, and the attachment id parsed
/// back out so the caller can save it on the parent record.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> sent;
  late FilesRepository repo;

  Future<FilesRepository> build(
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

    return FilesRepository(
      ApiClient(storage: storage, dio: dio, baseUrl: 'https://uat-api.vistarlogitek.com/api/v1'),
    );
  }

  ResponseBody json(Map<String, dynamic> body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  setUp(() => sent = <RequestOptions>[]);

  group('FilesRepository.upload', () {
    setUp(() async {
      repo = await build((options) async => json({
            'success': true,
            'data': {
              'id': '3f1b9c22-0000-4000-8000-000000000abc',
              'category': options.queryParameters['category'],
              'fileName': 'GA-DRAWING.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 4096,
              'uploadedAt': '2026-09-07T10:00:00.000Z',
              'url': '/api/v1/files/3f1b9c22-0000-4000-8000-000000000abc',
            },
          }));
    });

    test('posts to /files with the category the server expects', () async {
      final attachment = await repo.upload(
        const PickedUpload(name: 'GA-DRAWING.pdf', bytes: [1, 2, 3, 4], sizeBytes: 4),
        AttachmentCategory.drawing,
      );

      expect(sent, hasLength(1));
      expect(sent.single.method, 'POST');
      expect(sent.single.path, '/files');
      expect(sent.single.queryParameters['category'], 'DRAWING',
          reason: 'the category must travel in the query string — multer reads it before '
              'the body is parsed, so a form field would arrive too late');
      expect(sent.single.data, isA<FormData>());

      // The id is what the caller saves on the parent record.
      expect(attachment.id, '3f1b9c22-0000-4000-8000-000000000abc');
      expect(attachment.fileName, 'GA-DRAWING.pdf');
      expect(attachment.sizeLabel, '4 KB');
    });

    test('sends the bearer header, never a token in the URL', () async {
      await repo.upload(
        const PickedUpload(name: 'photo.png', bytes: [9], sizeBytes: 1),
        AttachmentCategory.image,
      );

      expect(sent.single.headers['Authorization'], 'Bearer test-access-token');
      expect(sent.single.uri.toString(), isNot(contains('access_token')));
    });

    test('tags the upload against its parent when the parent already exists', () async {
      await repo.upload(
        const PickedUpload(name: 'cert.pdf', bytes: [7], sizeBytes: 1),
        AttachmentCategory.certificate,
        entityType: 'tool',
        entityId: '42',
      );

      final form = sent.single.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};
      expect(fields['entityType'], 'tool');
      expect(fields['entityId'], '42');
      expect(form.files.single.value.filename, 'cert.pdf');
    });

    test('a rejected file type surfaces the server message', () async {
      repo = await build((options) async => json({
            'success': false,
            'error': {
              'code': 'BAD_REQUEST',
              'message': 'text/html is not an accepted drawing file type',
            },
          }, 400));

      expect(
        () => repo.upload(
          const PickedUpload(name: 'evil.pdf', bytes: [0], sizeBytes: 1),
          AttachmentCategory.drawing,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FilesRepository.download', () {
    test('fetches the stored file as an attachment, with the bearer header', () async {
      repo = await build((options) async => ResponseBody.fromBytes(
            Uint8List.fromList([37, 80, 68, 70]), // %PDF
            200,
            headers: {
              Headers.contentTypeHeader: ['application/pdf'],
              'content-disposition': ['attachment; filename="GA-DRAWING.pdf"'],
            },
          ));

      final file = await repo.download('3f1b9c22-0000-4000-8000-000000000abc');

      expect(sent.single.method, 'GET');
      expect(sent.single.path, '/files/3f1b9c22-0000-4000-8000-000000000abc');
      expect(sent.single.queryParameters['download'], '1',
          reason: 'ask for the attachment disposition rather than an inline render');
      expect(sent.single.headers['Authorization'], 'Bearer test-access-token');
      expect(file.filename, 'GA-DRAWING.pdf');
      expect(file.bytes, [37, 80, 68, 70]);
    });

    test('falls back to a known name when the server sends no filename', () async {
      repo = await build((options) async => ResponseBody.fromBytes(
            Uint8List.fromList([1]),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/octet-stream'],
            },
          ));

      final file = await repo.download('abc', fallbackName: 'TL-1001-drawing.pdf');
      expect(file.filename, 'TL-1001-drawing.pdf');
    });
  });

  group('AttachmentCategory', () {
    test('every category filters the picker to types the server accepts', () {
      // Mirrors config.uploads.allowedMime — a category the picker allows but the
      // upload endpoint refuses would let the user choose a file and then fail.
      expect(AttachmentCategory.drawing.extensions, containsAll(['pdf', 'dwg', 'dxf']));
      expect(AttachmentCategory.image.extensions, containsAll(['png', 'jpg']));
      expect(AttachmentCategory.certificate.extensions, containsAll(['pdf', 'png']));
      expect(AttachmentCategory.image.extensions, isNot(contains('pdf')),
          reason: 'IMAGE only accepts png/jpeg/webp on the server');
    });

    test('the wire value matches the server enum', () {
      expect(AttachmentCategory.drawing.wire, 'DRAWING');
      expect(AttachmentCategory.image.wire, 'IMAGE');
      expect(AttachmentCategory.certificate.wire, 'CERTIFICATE');
      expect(AttachmentCategory.document.wire, 'DOCUMENT');
    });
  });
}

/// Captures the outgoing request instead of putting it on the wire.
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
