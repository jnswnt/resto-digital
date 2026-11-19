import 'package:flutter/material.dart';

/// Implementasi tombol Google Sign-In untuk platform non-web (Android / Desktop)
Widget buildGoogleSignInPlatformButton({
  required VoidCallback onPressed,
  required bool isLoading,
}) {
  return ElevatedButton.icon(
    onPressed: isLoading ? null : onPressed,
    icon: Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 20),
    ),
    label: Text(
      isLoading ? 'Menghubungkan...' : 'Lanjutkan dengan Akun Google',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  );
}
