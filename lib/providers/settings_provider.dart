import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Provider Pengaturan Sistem & Manajemen Kasir (CRUD Kasir khusus Owner).
class SettingsProvider with ChangeNotifier {
  final StorageService _storageService;
  final _uuid = const Uuid();

  SettingsModel _settings = SettingsModel();
  List<UserModel> _users = [];

  SettingsProvider(this._storageService) {
    loadSettings();
    loadUsers();
  }

  SettingsModel get settings => _settings;
  List<UserModel> get users => List.unmodifiable(_users);
  List<UserModel> get cashiers => _users.where((u) => u.isCashier).toList();
  List<UserModel> get kitchenStaff => _users.where((u) => u.isKitchen).toList();
  List<UserModel> get allStaff => _users.where((u) => u.isStaff).toList();

  /// Mengambil data akun pemilik toko (Owner) aktif
  UserModel? get ownerUser => _users.cast<UserModel?>().firstWhere(
        (u) => u?.isOwner == true,
        orElse: () => null,
      );

  void loadSettings() {
    _settings = _storageService.getSettings();
    notifyListeners();
  }

  void loadUsers() {
    _users = _storageService.getUsers();
    notifyListeners();
  }

  /// Memperbarui profil resto (Nama, Alamat, No WA, Footer Struk)
  Future<void> updateStoreProfile({
    required String storeName,
    required String address,
    required String phoneWA,
    required String receiptFooter,
  }) async {
    _settings = _settings.copyWith(
      storeName: storeName,
      address: address,
      phoneWA: phoneWA,
      receiptFooter: receiptFooter,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Mengaktifkan atau menonaktifkan fitur pemilihan Meja (Toggle Meja)
  Future<void> toggleTableFeature(bool enabled) async {
    _settings = _settings.copyWith(tableFeatureEnabled: enabled);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Memperbarui konfigurasi Pajak Restoran (PB1) dan Biaya Layanan (Service Charge)
  Future<void> updateTaxAndServiceSettings({
    required bool enableTax,
    required double taxPercentage,
    required bool enableServiceCharge,
    required double serviceChargePercentage,
  }) async {
    _settings = _settings.copyWith(
      enableTax: enableTax,
      taxPercentage: taxPercentage,
      enableServiceCharge: enableServiceCharge,
      serviceChargePercentage: serviceChargePercentage,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Memperbarui konfigurasi printer thermal dan format struk belanja
  Future<void> updatePrinterReceiptSettings({
    required String printerType,
    required String paperSize,
    required String printerName,
    required String printerIpAddress,
    required int printerPort,
    required bool autoPrintReceipt,
    required bool autoPrintKitchen,
    required bool autoCut,
    required int numberOfCopies,
    required String receiptHeader,
    required String receiptFooter,
    required bool showCustomerInfo,
    required bool showCashierName,
    required bool showOrderNotes,
    required bool showQrFooter,
  }) async {
    _settings = _settings.copyWith(
      printerType: printerType,
      paperSize: paperSize,
      printerName: printerName,
      printerIpAddress: printerIpAddress,
      printerPort: printerPort,
      autoPrintReceipt: autoPrintReceipt,
      autoPrintKitchen: autoPrintKitchen,
      autoCut: autoCut,
      numberOfCopies: numberOfCopies,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      showCustomerInfo: showCustomerInfo,
      showCashierName: showCashierName,
      showOrderNotes: showOrderNotes,
      showQrFooter: showQrFooter,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Memperbarui payload string QRIS statis resto
  Future<void> updateQrisPayload(String payload) async {
    _settings = _settings.copyWith(qrisPayload: payload.trim());
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Mengubah PIN Owner
  Future<void> updateOwnerPin(String newPin) async {
    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPin(newPin, salt);
    _settings = _settings.copyWith(ownerPinHash: hash, ownerSalt: salt);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  // --- CRUD Kasir & Staf Dapur (Owner Only) ---

  /// Menambah staf baru (Kasir atau Koki Dapur) dengan nama, PIN 4-6 digit, dan peran
  Future<UserModel> addStaff({
    required String name,
    required String pin,
    String role = 'cashier',
  }) async {
    final salt = AuthService.generateSalt();
    final pinHash = AuthService.hashPin(pin, salt);
    final newStaff = UserModel(
      id: 'user_${_uuid.v4().substring(0, 8)}',
      name: name,
      role: role,
      pinHash: pinHash,
      salt: salt,
      isActive: true,
      createdAt: DateTime.now(),
    );

    _users.add(newStaff);
    await _storageService.saveUsers(_users);
    notifyListeners();
    return newStaff;
  }

  /// Menambah kasir baru dengan nama dan PIN 4-6 digit (Kompatibilitas mundur)
  Future<UserModel> addCashier({
    required String name,
    required String pin,
  }) async {
    return addStaff(name: name, pin: pin, role: 'cashier');
  }

  /// Memperbarui data staf (Nama, Role, dan opsional ganti PIN)
  Future<void> updateStaff({
    required String id,
    required String name,
    String? role,
    String? newPin,
  }) async {
    final index = _users.indexWhere((u) => u.id == id);
    if (index >= 0) {
      UserModel updated = _users[index].copyWith(name: name, role: role);
      if (newPin != null && newPin.isNotEmpty) {
        final salt = AuthService.generateSalt();
        final pinHash = AuthService.hashPin(newPin, salt);
        updated = updated.copyWith(pinHash: pinHash, salt: salt);
      }
      _users[index] = updated;
      await _storageService.saveUsers(_users);
      notifyListeners();
    }
  }

  /// Memperbarui data kasir (Nama dan opsional ganti PIN)
  Future<void> updateCashier({
    required String id,
    required String name,
    String? newPin,
  }) async {
    return updateStaff(id: id, name: name, newPin: newPin);
  }

  /// Memperbarui profil pemilik restoran (Nama Owner & opsional ganti PIN Master Owner)
  Future<UserModel?> updateOwnerProfile({
    required String name,
    String? newPin,
  }) async {
    final index = _users.indexWhere((u) => u.isOwner);
    if (index >= 0) {
      String pinHash = _users[index].pinHash;
      String salt = _users[index].salt;

      if (newPin != null && newPin.isNotEmpty) {
        salt = AuthService.generateSalt();
        pinHash = AuthService.hashPin(newPin, salt);
        // Selaraskan juga master PIN owner di Settings
        await updateOwnerPin(newPin);
      }

      final updatedOwner = _users[index].copyWith(
        name: name,
        pinHash: pinHash,
        salt: salt,
      );
      _users[index] = updatedOwner;

      await _storageService.saveUsers(_users);
      notifyListeners();
      return updatedOwner;
    }
    return null;
  }

  /// Mengaktifkan atau menonaktifkan akun kasir
  Future<void> toggleCashierStatus(String id, bool isActive) async {
    final index = _users.indexWhere((u) => u.id == id);
    if (index >= 0) {
      _users[index] = _users[index].copyWith(isActive: isActive);
      await _storageService.saveUsers(_users);
      notifyListeners();
    }
  }

  /// Menghapus kasir dari daftar
  Future<void> deleteCashier(String id) async {
    _users.removeWhere((u) => u.id == id);
    await _storageService.saveUsers(_users);
    notifyListeners();
  }

  /// Memperbarui konfigurasi Integrasi Cloud & Multi-Tenant (Firebase & Resto ID)
  Future<void> updateCloudConfig({
    required String restoId,
    required String firebaseProjectId,
    required String firebaseApiKey,
    required String webOrderBaseUrl,
    required bool isCloudSyncEnabled,
  }) async {
    _settings = _settings.copyWith(
      restoId: restoId.trim(),
      firebaseProjectId: firebaseProjectId.trim(),
      firebaseApiKey: firebaseApiKey.trim(),
      webOrderBaseUrl: webOrderBaseUrl.trim(),
      isCloudSyncEnabled: isCloudSyncEnabled,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }
}
