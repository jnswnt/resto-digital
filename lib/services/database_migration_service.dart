import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/shift_model.dart';
import '../models/cash_movement_model.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';

/// Layanan Migrasi Data SharedPreferences ke SQLite Lokal.
/// Memindahkan seluruh data transaksional lama (kategori, menu, pesanan, transaksi,
/// shift, arus kas, pelanggan) ke tabel SQLite secara transaksional,
/// lalu membersihkan/menghapus kunci-kunci JSON lama dari SharedPreferences
/// agar memori RAM dan media penyimpanan perangkat kasir menjadi lega.
class DatabaseMigrationService {
  static const String keyIsMigrated = 'is_migrated_to_sqlite';

  // Kunci-kunci JSON lama di SharedPreferences yang akan dipindahkan lalu dibersihkan
  static const String _keyCategories = 'pos_warkop_categories';
  static const String _keyProducts = 'pos_warkop_products';
  static const String _keyCustomers = 'pos_warkop_customers';
  static const String _keyOrders = 'pos_warkop_orders';
  static const String _keyTransactions = 'pos_warkop_transactions';
  static const String _keyShifts = 'pos_warkop_shifts';
  static const String _keyCashMovements = 'pos_warkop_cash_movements';

  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper;

  DatabaseMigrationService(this._prefs, this._dbHelper);

  /// Menjalankan migrasi satu kali jika belum pernah dimigrasikan sebelumnya
  Future<bool> migrateIfNeeded() async {
    if (kIsWeb) {
      // Pada lingkungan Web, data transaksional dikelola langsung oleh Web persistence layer
      await _prefs.setBool(keyIsMigrated, true);
      return false;
    }

    final bool isMigrated = _prefs.getBool(keyIsMigrated) ?? false;
    if (isMigrated) {
      return false; // Sudah pernah dimigrasikan
    }

    try {
      debugPrint('[Migration] Mendeteksi data lama di SharedPreferences, memulai migrasi ke SQLite...');

      // 1. Baca data lama dari SharedPreferences jika ada
      final rawCategories = _prefs.getString(_keyCategories);
      final rawProducts = _prefs.getString(_keyProducts);
      final rawCustomers = _prefs.getString(_keyCustomers);
      final rawOrders = _prefs.getString(_keyOrders);
      final rawTransactions = _prefs.getString(_keyTransactions);
      final rawShifts = _prefs.getString(_keyShifts);
      final rawCashMovements = _prefs.getString(_keyCashMovements);

      int catCount = 0;
      int prodCount = 0;
      int custCount = 0;
      int orderCount = 0;
      int txCount = 0;
      int shiftCount = 0;
      int cmCount = 0;

      // 2. Simpan ke SQLite
      if (rawCategories != null) {
        final list = jsonDecode(rawCategories) as List<dynamic>;
        final categories = list.map((e) => CategoryModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveCategories(categories);
        catCount = categories.length;
      }

      if (rawProducts != null) {
        final list = jsonDecode(rawProducts) as List<dynamic>;
        final products = list.map((e) => ProductModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveProducts(products);
        prodCount = products.length;
      }

      if (rawCustomers != null) {
        final list = jsonDecode(rawCustomers) as List<dynamic>;
        final customers = list.map((e) => CustomerModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveCustomers(customers);
        custCount = customers.length;
      }

      if (rawOrders != null) {
        final list = jsonDecode(rawOrders) as List<dynamic>;
        final orders = list.map((e) => OrderModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveOrders(orders);
        orderCount = orders.length;
      }

      if (rawTransactions != null) {
        final list = jsonDecode(rawTransactions) as List<dynamic>;
        final transactions = list.map((e) => TransactionModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveTransactions(transactions);
        txCount = transactions.length;
      }

      if (rawShifts != null) {
        final list = jsonDecode(rawShifts) as List<dynamic>;
        final shifts = list.map((e) => ShiftModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveShifts(shifts);
        shiftCount = shifts.length;
      }

      if (rawCashMovements != null) {
        final list = jsonDecode(rawCashMovements) as List<dynamic>;
        final movements = list.map((e) => CashMovementModel.fromMap(e as Map<String, dynamic>)).toList();
        await _dbHelper.saveCashMovements(movements);
        cmCount = movements.length;
      }

      // 3. Pembersihan Bersih: Hapus string JSON raksasa dari SharedPreferences
      await _prefs.remove(_keyCategories);
      await _prefs.remove(_keyProducts);
      await _prefs.remove(_keyCustomers);
      await _prefs.remove(_keyOrders);
      await _prefs.remove(_keyTransactions);
      await _prefs.remove(_keyShifts);
      await _prefs.remove(_keyCashMovements);

      // 4. Tandai bahwa migrasi telah berhasil diselesaikan
      await _prefs.setBool(keyIsMigrated, true);

      debugPrint(
        '[Migration] Sukses memigrasi ke SQLite: '
        '$catCount Kategori, $prodCount Menu, $custCount Pelanggan, '
        '$orderCount Pesanan, $txCount Transaksi, $shiftCount Shift, $cmCount Arus Kas. '
        'SharedPreferences lama berhasil dibersihkan.',
      );
      return true;
    } catch (e, stack) {
      debugPrint('[Migration] Kendala saat migrasi data SharedPreferences ke SQLite: $e\n$stack');
      return false;
    }
  }
}
