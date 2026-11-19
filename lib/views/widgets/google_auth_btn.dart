/// Ekspor platform-adaptive untuk Tombol Resmi Google Identity Services (GIS).
/// - Di Web: Menggunakan Google Identity Services resmi (`google_sign_in_web/web_only.dart` via `renderButton`).
/// - Di Android/Desktop: Menggunakan fallback `ElevatedButton.icon`.
library;

export 'google_auth_btn_stub.dart'
    if (dart.library.html) 'google_auth_btn_web.dart';
