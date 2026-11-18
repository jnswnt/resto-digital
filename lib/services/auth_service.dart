import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';

/// Layanan Autentikasi Pengguna & Kasir.
/// Menggunakan enkripsi Salted SHA-256 untuk keamanan PIN kasir dan Owner.
class AuthService {
  /// Menghasilkan salt acak 8 karakter hex
  static String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(8, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Menghasilkan hash SHA-256 dari kombinasi PIN dan Salt
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Memvalidasi apakah PIN yang diinput sesuai dengan pinHash dan salt pengguna
  static bool verifyPin({
    required String inputPin,
    required String pinHash,
    required String salt,
  }) {
    final computedHash = hashPin(inputPin, salt);
    return computedHash == pinHash;
  }

  /// Membuat objek UserModel baru dengan PIN yang sudah ter-hash secara aman
  static UserModel createUserWithPin({
    required String id,
    required String name,
    required String role,
    required String pin,
  }) {
    final salt = generateSalt();
    final pinHash = hashPin(pin, salt);
    return UserModel(
      id: id,
      name: name,
      role: role,
      pinHash: pinHash,
      salt: salt,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}
