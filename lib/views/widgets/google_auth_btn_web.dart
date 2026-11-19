import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Implementasi tombol resmi Google Identity Services (GIS) untuk Web.
/// Menampilkan widget resmi renderButton() dari Google jika tidak sedang loading,
/// atau animasi loading elegan jika sedang proses verifikasi ke server backend.
Widget buildGoogleSignInPlatformButton({
  required VoidCallback onPressed,
  required bool isLoading,
}) {
  if (isLoading) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Menghubungkan Akun...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return SizedBox(
    height: 48,
    width: double.infinity,
    child: Center(
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.filledBlue,
          shape: web.GSIButtonShape.rectangular,
          text: web.GSIButtonText.continueWith,
          size: web.GSIButtonSize.large,
        ),
      ),
    ),
  );
}
