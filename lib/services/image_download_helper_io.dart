import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Implementasi penyimpanan dan pengunduhan file gambar untuk platform Non-Web (Desktop & Mobile).
Future<bool> saveOrDownloadImageCrossPlatform({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  try {
    Directory? dir;
    if (Platform.isAndroid || Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    debugPrint('[ImageDownloadHelper] Berhasil menyimpan gambar ke: $filePath');
    return true;
  } catch (e) {
    debugPrint('[ImageDownloadHelper] Gagal menyimpan gambar: $e');
    return false;
  }
}

/// Implementasi salin gambar ke clipboard untuk platform Non-Web (Desktop & Mobile).
Future<bool> copyImageToClipboardCrossPlatform(Uint8List bytes) async {
  // Pada platform desktop native, clipboard image biasanya membutuhkan plugin khusus
  // Kita kembalikan false sebagai fallback agar sistem menggunakan salin teks
  return false;
}
