import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('window.downloadFileFromBase64')
external void _downloadFileFromBase64JS(JSString base64Data, JSString fileName, JSString mimeType);

@JS('window.copyImageToClipboard')
external JSPromise<JSBoolean> _copyImageToClipboardJS(JSString base64Data);

/// Implementasi pengunduhan file gambar untuk platform Flutter Web.
Future<bool> saveOrDownloadImageCrossPlatform({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  try {
    final base64Str = base64Encode(bytes);
    _downloadFileFromBase64JS(base64Str.toJS, fileName.toJS, mimeType.toJS);
    return true;
  } catch (e) {
    return false;
  }
}

/// Implementasi penyalinan gambar langsung ke clipboard sistem di platform Flutter Web.
Future<bool> copyImageToClipboardCrossPlatform(Uint8List bytes) async {
  try {
    final base64Str = base64Encode(bytes);
    final promise = _copyImageToClipboardJS(base64Str.toJS);
    final jsBool = await promise.toDart;
    return jsBool.toDart;
  } catch (e) {
    return false;
  }
}
