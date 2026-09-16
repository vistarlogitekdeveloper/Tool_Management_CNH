/// Fallback for any platform that provides neither dart:io nor dart:js_interop.
Future<String> saveFile(List<int> bytes, String filename, String contentType) async =>
    throw UnsupportedError('File download is not supported on this platform');
