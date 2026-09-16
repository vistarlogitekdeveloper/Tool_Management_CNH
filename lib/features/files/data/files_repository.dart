import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/tool.dart';

/// Attachment categories the API accepts, with the extensions each one allows.
///
/// The lists mirror `config.uploads.allowedMime` on the server, so the picker
/// filters to what the upload endpoint will actually accept rather than letting
/// the user choose a file and then be refused.
enum AttachmentCategory {
  drawing('DRAWING', 'Drawing', ['pdf', 'dwg', 'dxf']),
  image('IMAGE', 'Photo', ['png', 'jpg', 'jpeg', 'webp']),
  certificate('CERTIFICATE', 'Certificate', ['pdf', 'png', 'jpg', 'jpeg']),
  document('DOCUMENT', 'Document', ['pdf', 'xls', 'xlsx', 'csv']);

  const AttachmentCategory(this.wire, this.label, this.extensions);

  final String wire;
  final String label;
  final List<String> extensions;

  String get extensionHint => extensions.map((e) => e.toUpperCase()).join(' / ');
}

/// Upload, fetch and remove attachments — tool drawings, tool photos,
/// calibration certificates and maintenance documents.
///
/// The API wants the two-step flow described in `files.routes.js`: upload first,
/// then reference the returned id when creating or updating the parent record.
/// That keeps multipart bodies off the JSON business endpoints.
class FilesRepository {
  FilesRepository(this._api);

  final ApiClient _api;

  /// Opens the platform file picker, filtered to the category's extensions.
  /// Returns null when the user cancels.
  ///
  /// `withData` is required: on web there is no file path to read from, and the
  /// upload needs the bytes in memory either way.
  Future<PickedUpload?> pick(AttachmentCategory category) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: category.extensions,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return null;
    return PickedUpload(name: file.name, bytes: file.bytes!, sizeBytes: file.size);
  }

  /// Sends the bytes to `POST /files`. `entityType`/`entityId` are optional — an
  /// attachment uploaded before its parent exists is tagged when the parent
  /// record is saved.
  Future<Attachment> upload(
    PickedUpload file,
    AttachmentCategory category, {
    String? entityType,
    String? entityId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final json = await _api.upload(
      category: category.wire,
      bytes: file.bytes,
      filename: file.name,
      entityType: entityType,
      entityId: entityId,
      onProgress: onProgress,
    );
    return Attachment.fromJson(json);
  }

  /// Fetches the stored file so the platform can save or open it. Goes through
  /// the normal API client, so the bearer header is attached — the server no
  /// longer accepts a token in the query string.
  Future<DownloadedFile> download(String attachmentId, {String? fallbackName}) async {
    final file = await _api.download('/files/$attachmentId', query: {'download': '1'});
    if (file.filename.isNotEmpty && file.filename != 'export') return file;
    // Content-Disposition is percent-encoded by the server; fall back to the
    // name we already know when it cannot be read.
    return DownloadedFile(
      bytes: file.bytes,
      filename: fallbackName ?? 'attachment',
      contentType: file.contentType,
    );
  }

  Future<void> remove(String attachmentId, {String? reason}) =>
      _api.delete<Json?>('/files/$attachmentId', data: {if (reason != null) 'reason': reason});

  /// Attachments already recorded against a parent record.
  Future<List<Attachment>> forEntity(String entityType, String entityId) async {
    final data = await _api.get<List<dynamic>>('/files', query: {
      'entityType': entityType,
      'entityId': entityId,
    });
    return data
        .whereType<Map>()
        .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// A file chosen in the picker but not yet uploaded.
class PickedUpload {
  const PickedUpload({required this.name, required this.bytes, required this.sizeBytes});

  final String name;
  final List<int> bytes;
  final int sizeBytes;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}


final filesRepositoryProvider =
    Provider<FilesRepository>((ref) => FilesRepository(ref.watch(apiClientProvider)));
