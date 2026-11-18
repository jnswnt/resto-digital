import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/shift_model.dart';
import '../models/cash_movement_model.dart';
import '../models/customer_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'storage_service.dart';
import 'image_download_helper.dart';

/// Layanan Pencadangan & Pemulihan Database Lengkap (Backup & Restore Service).
/// Memfasilitasi ekspor seluruh data operasional resto ke berkas JSON mandiri
/// dan pemulihan data (restore) untuk migrasi perangkat atau pencegahan kehilangan data.
class BackupRestoreService {
  static final _dateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Membuat string JSON berisi seluruh data database restoran
  static Future<String> generateBackupJson({
    required DatabaseHelper dbHelper,
    required StorageService storageService,
  }) async {
    final categories = await dbHelper.getCategories();
    final products = await dbHelper.getProducts();
    final orders = await dbHelper.getOrders();
    final transactions = await dbHelper.getTransactions();
    final shifts = await dbHelper.getShifts();
    final cashMovements = await dbHelper.getCashMovements();
    final customers = await dbHelper.getCustomers();
    final settings = storageService.getSettings();
    final users = storageService.getUsers();

    final backupMap = {
      'app': 'mini_resto_pos',
      'version': '1.0.0',
      'schema_version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'summary': {
        'total_categories': categories.length,
        'total_products': products.length,
        'total_orders': orders.length,
        'total_transactions': transactions.length,
        'total_shifts': shifts.length,
        'total_cash_movements': cashMovements.length,
        'total_customers': customers.length,
      },
      'data': {
        'categories': categories.map((c) => c.toMap()).toList(),
        'products': products.map((p) => p.toMap()).toList(),
        'orders': orders.map((o) => o.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'shifts': shifts.map((s) => s.toMap()).toList(),
        'cash_movements': cashMovements.map((m) => m.toMap()).toList(),
        'customers': customers.map((c) => c.toMap()).toList(),
        'settings': settings.toMap(),
        'users': users.map((u) => u.toMap()).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Mengunduh atau menyimpan berkas cadangan database dalam format .json
  static Future<bool> exportBackupFile({
    required DatabaseHelper dbHelper,
    required StorageService storageService,
  }) async {
    try {
      final jsonString = await generateBackupJson(
        dbHelper: dbHelper,
        storageService: storageService,
      );
      final fileName = 'backup_miniresto_${_dateFormat.format(DateTime.now())}.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      return await saveOrDownloadImageCrossPlatform(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/json',
      );
    } catch (_) {
      return false;
    }
  }

  /// Menyalin seluruh data cadangan JSON ke clipboard sistem
  static Future<bool> copyBackupToClipboard({
    required DatabaseHelper dbHelper,
    required StorageService storageService,
  }) async {
    try {
      final jsonString = await generateBackupJson(
        dbHelper: dbHelper,
        storageService: storageService,
      );
      await Clipboard.setData(ClipboardData(text: jsonString));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Memulihkan database dari string JSON cadangan
  static Future<bool> restoreFromBackupJson({
    required String jsonContent,
    required DatabaseHelper dbHelper,
    required StorageService storageService,
  }) async {
    try {
      final dynamic decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) return false;

      if (decoded['app'] != 'mini_resto_pos' || !decoded.containsKey('data')) {
        return false;
      }

      final data = decoded['data'] as Map<String, dynamic>;

      // 1. Kosongkan seluruh data lama
      await dbHelper.clearAllData();

      // 2. Pulihkan Kategori
      if (data.containsKey('categories')) {
        final catList = (data['categories'] as List<dynamic>)
            .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveCategories(catList);
      }

      // 3. Pulihkan Produk / Menu
      if (data.containsKey('products')) {
        final prodList = (data['products'] as List<dynamic>)
            .map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveProducts(prodList);
      }

      // 4. Pulihkan Pesanan (Orders)
      if (data.containsKey('orders')) {
        final orderList = (data['orders'] as List<dynamic>)
            .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveOrders(orderList);
      }

      // 5. Pulihkan Transaksi (Transactions)
      if (data.containsKey('transactions')) {
        final txList = (data['transactions'] as List<dynamic>)
            .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveTransactions(txList);
      }

      // 6. Pulihkan Shift Kasir
      if (data.containsKey('shifts')) {
        final shiftList = (data['shifts'] as List<dynamic>)
            .map((e) => ShiftModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveShifts(shiftList);
      }

      // 7. Pulihkan Pergerakan Kas (Petty Cash)
      if (data.containsKey('cash_movements')) {
        final movList = (data['cash_movements'] as List<dynamic>)
            .map((e) => CashMovementModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveCashMovements(movList);
      }

      // 8. Pulihkan Pelanggan & Kasbon
      if (data.containsKey('customers')) {
        final custList = (data['customers'] as List<dynamic>)
            .map((e) => CustomerModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await dbHelper.saveCustomers(custList);
      }

      // 9. Pulihkan Pengaturan Toko & Pengguna Kasir
      if (data.containsKey('settings')) {
        final settings = SettingsModel.fromMap(Map<String, dynamic>.from(data['settings'] as Map));
        await storageService.saveSettings(settings);
      }
      if (data.containsKey('users')) {
        final userList = (data['users'] as List<dynamic>)
            .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        await storageService.saveUsers(userList);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
