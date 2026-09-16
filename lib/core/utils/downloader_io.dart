import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop and mobile: write to the downloads folder (documents where there
/// isn't one) and open the file with the platform's default handler.
Future<String> saveFile(List<int> bytes, String filename, String contentType) async {
  final directory = await _targetDirectory();
  final path = '${directory.path}${Platform.pathSeparator}$filename';
  await File(path).writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(path);
  return result.type == ResultType.done ? 'Opened $filename' : 'Saved to $path';
}

Future<Directory> _targetDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } on UnsupportedError {
    // Android and iOS have no downloads directory — fall through.
  } catch (_) {
    // Any other platform channel failure: fall back to documents.
  }
  return getApplicationDocumentsDirectory();
}
