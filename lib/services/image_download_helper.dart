library;

/// Abstraksi ekspor kondisional untuk pengunduhan file gambar dan penyalinan gambar
/// ke clipboard sistem di platform Web dan Non-Web (Desktop & Mobile).
export 'image_download_helper_io.dart'
    if (dart.library.js_interop) 'image_download_helper_web.dart';
