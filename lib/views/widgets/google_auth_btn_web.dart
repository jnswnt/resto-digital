import 'package:flutter/material.dart';

/// Implementasi tombol resmi Google Identity Services untuk Web.
/// 
/// Menggunakan tombol interaktif Flutter dengan styling resmi Google
/// agar terhindar dari isu pemblokiran gesture pada Platform View HTML di peramban web,
/// serta menjamin event `onPressed` selalu terpicu dengan user activation penuh.
Widget buildGoogleSignInPlatformButton({
  required VoidCallback onPressed,
  required bool isLoading,
}) {
  if (isLoading) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
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

  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A73E8),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ikon Google Resmi dengan Kontainer Putih Bersih
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Lanjutkan dengan Google',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}
