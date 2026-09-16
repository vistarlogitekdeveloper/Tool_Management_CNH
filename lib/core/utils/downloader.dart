import '../network/api_client.dart';
import 'downloader_stub.dart'
    if (dart.library.io) 'downloader_io.dart'
    if (dart.library.js_interop) 'downloader_web.dart' as impl;

/// Saves an exported report (Excel / PDF / CSV) and hands it to the platform.
///
/// Web pushes the bytes through a Blob download; desktop and mobile write the
/// file to the downloads directory and open it with the default handler, so
/// .xlsx lands in Excel and .pdf in a reader.
abstract final class Downloader {
  /// Returns a short message describing where the file went, for the toast.
  static Future<String> save(DownloadedFile file) =>
      impl.saveFile(file.bytes, file.filename, file.contentType);
}
