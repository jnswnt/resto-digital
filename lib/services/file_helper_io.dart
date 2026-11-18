import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Implementasi manajemen file lokal khusus platform Native (Android/Windows/iOS/Desktop).
Widget buildPlatformFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
  } catch (_) {}
  return const SizedBox.shrink();
}

/// Menyimpan berkas gambar ke direktori dokumen lokal perangkat native
Future<String?> savePlatformLocalImage(Uint8List bytes, String filename) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/product_images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final file = File('${imagesDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
