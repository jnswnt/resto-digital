import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Implementasi manajemen file khusus platform Web Browser.
Widget buildPlatformFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.network(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

/// Pada Web Browser, gambar diubah menjadi Data URI Base64 agar dapat ditampilkan secara instan
Future<String?> savePlatformLocalImage(Uint8List bytes, String filename) async {
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}
