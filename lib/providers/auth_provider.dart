import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Provider Pengelolaan Sesi Kasir & Autentikasi Kiosk PIN.
class AuthProvider with ChangeNotifier {
  final StorageService _storageService;

  UserModel? _currentUser;
  bool _isLocked = true;
  String? _errorMessage;
  bool _isOwnerModeUnlocked = false;

  AuthProvider(this._storageService);

  UserModel? get currentUser => _currentUser;
  bool get isLocked => _isLocked;
  bool get isAuthenticated => _currentUser != null && !_isLocked;
  String? get errorMessage => _errorMessage;

  /// Memeriksa apakah hak akses mode Owner sedang terbuka.
  /// Otomatis true jika akun yang login adalah Owner murni,
  /// atau jika kasir telah berhasil memasukkan PIN Owner pada sesi aktif.
  bool get isOwnerMode => (_currentUser?.isOwner ?? false) || _isOwnerModeUnlocked;

  /// Membuka hak akses Owner sementara dengan validasi PIN Owner.
  bool unlockOwnerMode(String pin) {
    if (verifyOwnerPin(pin)) {
      _isOwnerModeUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Mengunci kembali hak akses Owner (dipanggil saat kasir meninggalkan halaman admin/owner)
  void lockOwnerMode() {
    if (_isOwnerModeUnlocked) {
      _isOwnerModeUnlocked = false;
      notifyListeners();
    }
  }

  /// Memverifikasi input PIN pada layar Kiosk Lock Screen
  Future<bool> loginWithPin(String pin) async {
    _errorMessage = null;
    final users = _storageService.getUsers().where((u) => u.isActive).toList();

    for (final user in users) {
      final isValid = AuthService.verifyPin(
        inputPin: pin,
        pinHash: user.pinHash,
        salt: user.salt,
      );

      if (isValid) {
        _currentUser = user;
        _isLocked = false;
        _isOwnerModeUnlocked = false;
        notifyListeners();
        return true;
      }
    }

    _errorMessage = 'PIN tidak valid. Silakan coba lagi.';
    notifyListeners();
    return false;
  }

  /// Memverifikasi PIN khusus Owner (misal untuk membuka Halaman Pengaturan)
  bool verifyOwnerPin(String pin) {
    final settings = _storageService.getSettings();
    if (settings.ownerPinHash.isNotEmpty && settings.ownerSalt.isNotEmpty) {
      return AuthService.verifyPin(
        inputPin: pin,
        pinHash: settings.ownerPinHash,
        salt: settings.ownerSalt,
      );
    }

    // Fallback jika belum diatur di settings, cek akun user bertipe owner
    final owners = _storageService.getUsers().where((u) => u.isOwner && u.isActive);
    for (final owner in owners) {
      if (AuthService.verifyPin(inputPin: pin, pinHash: owner.pinHash, salt: owner.salt)) {
        return true;
      }
    }

    // Fallback darurat default pin resto
    return pin == '9999';
  }

  /// Memperbarui informasi nama kasir/owner yang sedang aktif di sesi ini
  void updateCurrentUserName(String newName) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(name: newName);
      notifyListeners();
    }
  }

  /// Memuat ulang currentUser dari database lokal agar data profil selalu sinkron
  void reloadCurrentUser() {
    if (_currentUser != null) {
      final users = _storageService.getUsers();
      final updated = users.firstWhere(
        (u) => u.id == _currentUser!.id,
        orElse: () => _currentUser!,
      );
      _currentUser = updated;
      notifyListeners();
    }
  }

  /// Mengunci layar tablet kembali ke numpad (Ganti Shift / Kasir Istirahat)
  void lockScreen() {
    _isLocked = true;
    _errorMessage = null;
    _isOwnerModeUnlocked = false;
    notifyListeners();
  }

  /// Logout penuh kasir
  void logout() {
    _currentUser = null;
    _isLocked = true;
    _errorMessage = null;
    _isOwnerModeUnlocked = false;
    notifyListeners();
  }
}
