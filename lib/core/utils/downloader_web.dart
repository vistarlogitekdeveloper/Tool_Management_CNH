import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: wrap the bytes in a Blob and click a temporary anchor, which is how a
/// browser saves a file the page generated.
Future<String> saveFile(List<int> bytes, String filename, String contentType) async {
  final data = Uint8List.fromList(bytes).toJS;
  final blob = web.Blob([data].toJS, web.BlobPropertyBag(type: contentType));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return 'Downloaded $filename';
}
