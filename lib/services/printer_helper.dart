library;

/// Abstraksi ekspor kondisional untuk pencetakan struk HTML printer thermal
/// di platform Web dan Non-Web (Mobile & Desktop).
export 'printer_helper_io.dart'
    if (dart.library.js_interop) 'printer_helper_web.dart';
