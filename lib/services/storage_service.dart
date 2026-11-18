import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/shift_model.dart';
import '../models/cash_movement_model.dart';
import '../models/settings_model.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'database_migration_service.dart';

/// Layanan Penyimpanan Data Lokal (Hybrid Persistence: SharedPreferences + SQLite).
/// - SharedPreferences: Menyimpan data kredensial & preferensi ringan (Users, Settings, ActiveShiftId).
/// - SQLite: Menyimpan seluruh data transaksi, riwayat pesanan, menu produk, shift, kasbon, dan arus kas.
/// Menggunakan in-memory cache untuk menjamin kompatibilitas sinkron dan kecepatan akses instan.
class StorageService {
  static const _keyUsers = 'pos_warkop_users';
  static const _keySettings = 'pos_warkop_settings';
  static const _keyActiveShiftId = 'pos_warkop_active_shift_id';

  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper;

  // In-Memory Cache untuk akses data transaksional yang instan dan sinkron di level Provider/UI
  List<CategoryModel> _cachedCategories = [];
  List<ProductModel> _cachedProducts = [];
  List<CustomerModel> _cachedCustomers = [];
  List<OrderModel> _cachedOrders = [];
  List<TransactionModel> _cachedTransactions = [];
  List<ShiftModel> _cachedShifts = [];
  List<CashMovementModel> _cachedCashMovements = [];

  SharedPreferences get prefs => _prefs;
  DatabaseHelper get dbHelper => _dbHelper;

  StorageService(this._prefs, [DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static Future<StorageService> init({DatabaseHelper? dbHelper}) async {
    final prefs = await SharedPreferences.getInstance();
    final db = dbHelper ?? DatabaseHelper.instance;
    await db.database;

    final service = StorageService(prefs, db);

    // 1. Jalankan migrasi satu kali jika ada data lama di SharedPreferences
    final migration = DatabaseMigrationService(prefs, db);
    await migration.migrateIfNeeded();

    // 2. Muat data awal (starter kit) jika database masih kosong
    await service._seedInitialDataIfNeeded();

    // 3. Muat seluruh data dari SQLite ke in-memory cache
    await service.reloadFromDatabase();

    return service;
  }

  /// Memuat ulang seluruh in-memory cache langsung dari database SQLite
  Future<void> reloadFromDatabase() async {
    _cachedCategories = await _dbHelper.getCategories();
    _cachedProducts = await _dbHelper.getProducts();
    _cachedCustomers = await _dbHelper.getCustomers();
    _cachedOrders = await _dbHelper.getOrders();
    _cachedTransactions = await _dbHelper.getTransactions();
    _cachedShifts = await _dbHelper.getShifts();
    _cachedCashMovements = await _dbHelper.getCashMovements();
  }

  /// Memasukkan data awal jika aplikasi baru pertama kali dipasang
  Future<void> _seedInitialDataIfNeeded() async {
    // 1. Inisialisasi Akun Kasir, Koki Dapur, & Owner jika belum ada di SharedPreferences
    if (!_prefs.containsKey(_keyUsers)) {
      final budiSalt = AuthService.generateSalt();
      final sitiSalt = AuthService.generateSalt();
      final kokiSalt = AuthService.generateSalt();
      final ownerSalt = AuthService.generateSalt();

      final initialUsers = [
        UserModel(
          id: 'user_budi',
          name: 'Budi (Kasir)',
          role: 'cashier',
          pinHash: AuthService.hashPin('1234', budiSalt),
          salt: budiSalt,
          isActive: true,
        ),
        UserModel(
          id: 'user_siti',
          name: 'Siti (Kasir)',
          role: 'cashier',
          pinHash: AuthService.hashPin('5678', sitiSalt),
          salt: sitiSalt,
          isActive: true,
        ),
        UserModel(
          id: 'user_koki',
          name: 'Koki Juna (Dapur)',
          role: 'kitchen',
          pinHash: AuthService.hashPin('2233', kokiSalt),
          salt: kokiSalt,
          isActive: true,
        ),
        UserModel(
          id: 'user_owner',
          name: 'H. Sukri (Owner)',
          role: 'owner',
          pinHash: AuthService.hashPin('9999', ownerSalt),
          salt: ownerSalt,
          isActive: true,
        ),
      ];
      await saveUsers(initialUsers);

      final settings = SettingsModel(
        storeName: 'Resto Digital',
        address: 'Jl. Pemuda No. 88, Jakarta Timur',
        phoneWA: '081234567890',
        tableFeatureEnabled: true,
        receiptFooter: 'Terima kasih atas kunjungannya di Resto Digital! Selamat menikmati.',
        ownerPinHash: AuthService.hashPin('9999', ownerSalt),
        ownerSalt: ownerSalt,
      );
      await saveSettings(settings);
    }

    // 2. Inisialisasi Menu & Kategori Resto di SQLite jika masih kosong
    final existingCategories = await _dbHelper.getCategories();
    if (existingCategories.isEmpty) {
      final categories = [
        CategoryModel(id: 'cat_makanan', name: 'Makanan Utama', sortOrder: 1, iconName: 'restaurant'),
        CategoryModel(id: 'cat_minuman', name: 'Minuman Segar', sortOrder: 2, iconName: 'local_drink'),
        CategoryModel(id: 'cat_camilan', name: 'Camilan & Appetizer', sortOrder: 3, iconName: 'fastfood'),
        CategoryModel(id: 'cat_paket', name: 'Paket Hemat', sortOrder: 4, iconName: 'lunch_dining'),
      ];
      await _dbHelper.saveCategories(categories);

      final products = [
        ProductModel(
          id: 'p1',
          name: 'Nasi Goreng Spesial Resto',
          categoryId: 'cat_makanan',
          buyPrice: 12000,
          sellPrice: 22000,
          stock: 50,
          unit: 'Porsi',
          imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p2',
          name: 'Ayam Bakar Madu + Nasi',
          categoryId: 'cat_makanan',
          buyPrice: 15000,
          sellPrice: 28000,
          stock: 40,
          unit: 'Porsi',
          imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p3',
          name: 'Mie Goreng Seafood Spesial',
          categoryId: 'cat_makanan',
          buyPrice: 14000,
          sellPrice: 25000,
          stock: 35,
          unit: 'Porsi',
          imageUrl: 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p4',
          name: 'Sop Iga Sapi Rempah',
          categoryId: 'cat_makanan',
          buyPrice: 22000,
          sellPrice: 38000,
          stock: 25,
          unit: 'Mangkuk',
          imageUrl: 'https://images.unsplash.com/photo-1547928576-a4a33237cbc3?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p5',
          name: 'Es Teh Manis Jumbo',
          categoryId: 'cat_minuman',
          buyPrice: 1500,
          sellPrice: 5000,
          stock: 200,
          unit: 'Gelas',
          imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p6',
          name: 'Jus Alpukat Kocok',
          categoryId: 'cat_minuman',
          buyPrice: 6000,
          sellPrice: 15000,
          stock: 50,
          unit: 'Gelas',
          imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p7',
          name: 'Kopi Susu Gula Aren',
          categoryId: 'cat_minuman',
          buyPrice: 5000,
          sellPrice: 14000,
          stock: 80,
          unit: 'Cup',
          imageUrl: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p8',
          name: 'Lemon Tea Dingin',
          categoryId: 'cat_minuman',
          buyPrice: 3000,
          sellPrice: 8000,
          stock: 100,
          unit: 'Gelas',
          imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p9',
          name: 'Kentang Goreng (French Fries)',
          categoryId: 'cat_camilan',
          buyPrice: 7000,
          sellPrice: 15000,
          stock: 60,
          unit: 'Porsi',
          imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p10',
          name: 'Tahu Crispy Cabai Garam',
          categoryId: 'cat_camilan',
          buyPrice: 5000,
          sellPrice: 12000,
          stock: 70,
          unit: 'Porsi',
          imageUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p11',
          name: 'Paket Ayam Geprek + Es Teh',
          categoryId: 'cat_paket',
          buyPrice: 14000,
          sellPrice: 25000,
          stock: 40,
          unit: 'Paket',
          imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=500&auto=format&fit=crop&q=80',
        ),
        ProductModel(
          id: 'p12',
          name: 'Paket Nasi Liwet Komplit',
          categoryId: 'cat_paket',
          buyPrice: 18000,
          sellPrice: 32000,
          stock: 30,
          unit: 'Paket',
          imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500&auto=format&fit=crop&q=80',
        ),
      ];
      await _dbHelper.saveProducts(products);

      final customers = [
        CustomerModel(id: 'c1', name: 'Mas Joko (Bengkel)', phoneWA: '081298765432', totalDebt: 35000, debtLimit: 100000),
        CustomerModel(id: 'c2', name: 'Bang Rian (Ojol)', phoneWA: '081311223344', totalDebt: 0, debtLimit: 150000),
        CustomerModel(id: 'c3', name: 'Pak RT Slamet', phoneWA: '085612345678', totalDebt: 15000, debtLimit: 200000),
      ];
      await _dbHelper.saveCustomers(customers);
    }
  }

  // --- Users CRUD (SharedPreferences) ---
  List<UserModel> getUsers() {
    final raw = _prefs.getString(_keyUsers);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveUsers(List<UserModel> users) async {
    final raw = jsonEncode(users.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyUsers, raw);
  }

  // --- Settings (SharedPreferences) ---
  SettingsModel getSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw == null) return SettingsModel();
    return SettingsModel.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final raw = jsonEncode(settings.toMap());
    await _prefs.setString(_keySettings, raw);
  }

  // --- Categories (SQLite + Cache) ---
  List<CategoryModel> getCategories() {
    return List.from(_cachedCategories);
  }

  Future<void> saveCategories(List<CategoryModel> categories) async {
    _cachedCategories = List.from(categories);
    await _dbHelper.saveCategories(categories);
  }

  // --- Products (SQLite + Cache) ---
  List<ProductModel> getProducts() {
    return List.from(_cachedProducts);
  }

  Future<void> saveProducts(List<ProductModel> products) async {
    _cachedProducts = List.from(products);
    await _dbHelper.saveProducts(products);
  }

  Future<void> upsertProduct(ProductModel product) async {
    final index = _cachedProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _cachedProducts[index] = product;
    } else {
      _cachedProducts.add(product);
    }
    await _dbHelper.upsertProduct(product);
  }

  // --- Customers (SQLite + Cache) ---
  List<CustomerModel> getCustomers() {
    return List.from(_cachedCustomers);
  }

  Future<void> saveCustomers(List<CustomerModel> customers) async {
    _cachedCustomers = List.from(customers);
    await _dbHelper.saveCustomers(customers);
  }

  Future<void> upsertCustomer(CustomerModel customer) async {
    final index = _cachedCustomers.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      _cachedCustomers[index] = customer;
    } else {
      _cachedCustomers.add(customer);
    }
    await _dbHelper.upsertCustomer(customer);
  }

  // --- Orders (SQLite + Cache) ---
  List<OrderModel> getOrders() {
    return List.from(_cachedOrders);
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    _cachedOrders = List.from(orders);
    await _dbHelper.saveOrders(orders);
  }

  Future<void> upsertOrder(OrderModel order) async {
    final index = _cachedOrders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _cachedOrders[index] = order;
    } else {
      _cachedOrders.add(order);
    }
    await _dbHelper.upsertOrder(order);
  }

  // --- Transactions (SQLite + Cache) ---
  List<TransactionModel> getTransactions() {
    return List.from(_cachedTransactions);
  }

  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    _cachedTransactions = List.from(transactions);
    await _dbHelper.saveTransactions(transactions);
  }

  Future<void> insertTransaction(TransactionModel transaction) async {
    _cachedTransactions.insert(0, transaction);
    await _dbHelper.insertTransaction(transaction);
  }

  // --- Shifts (SQLite + Cache) ---
  List<ShiftModel> getShifts() {
    return List.from(_cachedShifts);
  }

  Future<void> saveShifts(List<ShiftModel> shifts) async {
    _cachedShifts = List.from(shifts);
    await _dbHelper.saveShifts(shifts);
  }

  Future<void> upsertShift(ShiftModel shift) async {
    final index = _cachedShifts.indexWhere((s) => s.id == shift.id);
    if (index >= 0) {
      _cachedShifts[index] = shift;
    } else {
      _cachedShifts.insert(0, shift);
    }
    await _dbHelper.upsertShift(shift);
  }

  String? getActiveShiftId() {
    return _prefs.getString(_keyActiveShiftId);
  }

  Future<void> setActiveShiftId(String? shiftId) async {
    if (shiftId == null) {
      await _prefs.remove(_keyActiveShiftId);
    } else {
      await _prefs.setString(_keyActiveShiftId, shiftId);
    }
  }

  // --- Cash Movements (SQLite + Cache) ---
  List<CashMovementModel> getCashMovements() {
    return List.from(_cachedCashMovements);
  }

  Future<void> saveCashMovements(List<CashMovementModel> movements) async {
    _cachedCashMovements = List.from(movements);
    await _dbHelper.saveCashMovements(movements);
  }

  Future<void> insertCashMovement(CashMovementModel movement) async {
    _cachedCashMovements.insert(0, movement);
    await _dbHelper.insertCashMovement(movement);
  }
}
