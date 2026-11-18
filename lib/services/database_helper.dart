import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/shift_model.dart';
import '../models/cash_movement_model.dart';
import '../models/customer_model.dart';

/// Pengelola Database Lokal Restoran (Hybrid: SQLite untuk Native & SharedPreferences untuk Web).
/// Menyimpan seluruh data operasional (Produk, Kategori, Pesanan, Transaksi, Shift, Arus Kas, Pelanggan)
/// secara terstruktur dan persisten baik di lingkungan Mobile/Desktop (SQLite) maupun Web Browser (LocalStorage).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  factory DatabaseHelper() => instance;

  static Database? _database;
  SharedPreferences? _webPrefs;

  /// Memastikan koneksi SharedPreferences di lingkungan Web siap digunakan
  Future<SharedPreferences> _getWebPrefs() async {
    _webPrefs ??= await SharedPreferences.getInstance();
    return _webPrefs!;
  }

  /// Inisialisasi awal penyimpanan Web
  Future<void> _initWebStorage() async {
    await _getWebPrefs();
  }

  /// Getter database SQLite (pada web, mengembalikan null secara aman)
  Future<Database?> get database async {
    if (kIsWeb) {
      await _initWebStorage();
      return null;
    }
    if (_database != null && _database!.isOpen) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  /// Inisialisasi koneksi SQLite atau Web Storage. Parameter [customPath] digunakan untuk pengujian (testing).
  Future<Database?> initDatabase({String? customPath}) async {
    if (kIsWeb) {
      await _initWebStorage();
      return null;
    }
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    final dbPath = customPath ?? join(await getDatabasesPath(), 'mini_resto.db');
    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  /// Menangani peningkatan versi database (Database Schema Migration)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrasi v1 -> v2:
      // Menambahkan kolom pelacakan KDS, DP QRIS, dan ID Pesanan Online pada tabel orders
      await db.execute('ALTER TABLE orders ADD COLUMN paidAmount INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN onlineOrderId TEXT');
      await db.execute("ALTER TABLE orders ADD COLUMN kitchenStatus TEXT NOT NULL DEFAULT 'pending'");
      await db.execute('ALTER TABLE orders ADD COLUMN cookingStartedAt INTEGER');
      await db.execute("ALTER TABLE orders ADD COLUMN completedItemIdsJson TEXT NOT NULL DEFAULT '[]'");
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_kitchenStatus ON orders(kitchenStatus)');
    }
  }

  /// Mengosongkan seluruh tabel data (berguna untuk testing dan reset)
  Future<void> clearAllData() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      await prefs.remove('web_db_categories');
      await prefs.remove('web_db_products');
      await prefs.remove('web_db_orders');
      await prefs.remove('web_db_transactions');
      await prefs.remove('web_db_shifts');
      await prefs.remove('web_db_cash_movements');
      await prefs.remove('web_db_customers');
      return;
    }
    final db = (await database)!;
    await db.delete('categories');
    await db.delete('products');
    await db.delete('orders');
    await db.delete('transactions');
    await db.delete('shifts');
    await db.delete('cash_movements');
    await db.delete('customers');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabel Kategori Menu
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL,
        iconName TEXT
      )
    ''');

    // 2. Tabel Produk / Menu Makanan & Minuman
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        buyPrice INTEGER NOT NULL,
        sellPrice INTEGER NOT NULL,
        stock INTEGER NOT NULL,
        trackStock INTEGER NOT NULL DEFAULT 1,
        unit TEXT NOT NULL,
        imageUrl TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_category ON products(categoryId)');

    // 3. Tabel Pesanan & Meja (Open Tabs, Completed, KDS Dapur, & DP QRIS)
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        shiftId TEXT NOT NULL,
        tableNo TEXT,
        customerName TEXT NOT NULL,
        itemsJson TEXT NOT NULL,
        status TEXT NOT NULL,
        paidAmount INTEGER NOT NULL DEFAULT 0,
        onlineOrderId TEXT,
        createdAt INTEGER NOT NULL,
        completedAt INTEGER,
        kitchenStatus TEXT NOT NULL DEFAULT 'pending',
        cookingStartedAt INTEGER,
        completedItemIdsJson TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_tableNo ON orders(tableNo)');
    await db.execute('CREATE INDEX idx_orders_kitchenStatus ON orders(kitchenStatus)');

    // 4. Tabel Transaksi Pembayaran
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        shiftId TEXT NOT NULL,
        cashierId TEXT NOT NULL,
        cashierName TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        totalAmount INTEGER NOT NULL,
        amountPaid INTEGER NOT NULL,
        change INTEGER NOT NULL,
        customerId TEXT,
        customerName TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_transactions_shiftId ON transactions(shiftId)');

    // 5. Tabel Sesi Shift Kasir
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        cashierName TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        endedAt INTEGER,
        initialCash INTEGER NOT NULL,
        totalCashSales INTEGER NOT NULL DEFAULT 0,
        totalQrisSales INTEGER NOT NULL DEFAULT 0,
        totalDebtSales INTEGER NOT NULL DEFAULT 0,
        totalDebtRepaidCash INTEGER NOT NULL DEFAULT 0,
        totalCashOut INTEGER NOT NULL DEFAULT 0,
        expectedCash INTEGER NOT NULL DEFAULT 0,
        actualCash INTEGER NOT NULL DEFAULT 0,
        difference INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'open'
      )
    ''');
    await db.execute('CREATE INDEX idx_shifts_status ON shifts(status)');

    // 6. Tabel Mutasi Kas Laci (Petty Cash)
    await db.execute('''
      CREATE TABLE cash_movements (
        id TEXT PRIMARY KEY,
        shiftId TEXT NOT NULL,
        userId TEXT NOT NULL,
        cashierName TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        notes TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_cash_movements_shiftId ON cash_movements(shiftId)');

    // 7. Tabel Pelanggan & Rekap Kasbon
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phoneWA TEXT NOT NULL,
        totalDebt INTEGER NOT NULL DEFAULT 0,
        debtLimit INTEGER NOT NULL DEFAULT 100000,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  // ===================== CRUD CATEGORIES =====================

  Future<List<CategoryModel>> getCategories() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_categories');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final cats = list
          .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      cats.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return cats;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('categories', orderBy: 'sortOrder ASC');
    return rows.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<void> saveCategories(List<CategoryModel> categories) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(categories.map((c) => c.toMap()).toList());
      await prefs.setString('web_db_categories', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('categories');
      final batch = txn.batch();
      for (final cat in categories) {
        batch.insert('categories', cat.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // ===================== CRUD PRODUCTS =====================

  Future<List<ProductModel>> getProducts() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_products');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final prods = list
          .map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      prods.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return prods;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('products', orderBy: 'name ASC');
    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['trackStock'] = map['trackStock'] == 1;
      return ProductModel.fromMap(map);
    }).toList();
  }

  Future<void> saveProducts(List<ProductModel> products) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(products.map((p) => p.toMap()).toList());
      await prefs.setString('web_db_products', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('products');
      final batch = txn.batch();
      for (final prod in products) {
        final map = prod.toMap();
        map['trackStock'] = prod.trackStock ? 1 : 0;
        batch.insert('products', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertProduct(ProductModel product) async {
    if (kIsWeb) {
      final prods = await getProducts();
      final idx = prods.indexWhere((p) => p.id == product.id);
      if (idx >= 0) {
        prods[idx] = product;
      } else {
        prods.add(product);
      }
      await saveProducts(prods);
      return;
    }
    final db = (await database)!;
    final map = product.toMap();
    map['trackStock'] = product.trackStock ? 1 : 0;
    await db.insert('products', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===================== CRUD ORDERS =====================

  Future<List<OrderModel>> getOrders() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_orders');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final orders = list
          .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('orders', orderBy: 'createdAt DESC');
    return rows.map((e) {
      final itemsRaw = jsonDecode(e['itemsJson'] as String? ?? '[]') as List<dynamic>;
      final completedItemsRaw = jsonDecode(e['completedItemIdsJson'] as String? ?? '[]') as List<dynamic>;
      return OrderModel(
        id: e['id'] as String,
        shiftId: e['shiftId'] as String,
        tableNo: e['tableNo'] as String?,
        customerName: e['customerName'] as String,
        items: itemsRaw
            .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList(),
        status: e['status'] as String,
        paidAmount: (e['paidAmount'] as num?)?.toInt() ?? 0,
        onlineOrderId: e['onlineOrderId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(e['createdAt'] as int),
        completedAt: e['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(e['completedAt'] as int)
            : null,
        kitchenStatus: e['kitchenStatus'] as String? ?? 'pending',
        cookingStartedAt: e['cookingStartedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(e['cookingStartedAt'] as int)
            : null,
        completedItemIds: completedItemsRaw.map((x) => x.toString()).toList(),
      );
    }).toList();
  }

  /// Menyimpan daftar pesanan ke database (Web: JSON LocalStorage, Native: SQLite Batch)
  Future<void> saveOrders(List<OrderModel> orders) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(orders.map((o) => o.toMap()).toList());
      await prefs.setString('web_db_orders', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('orders');
      final batch = txn.batch();
      for (final o in orders) {
        batch.insert(
          'orders',
          {
            'id': o.id,
            'shiftId': o.shiftId,
            'tableNo': o.tableNo,
            'customerName': o.customerName,
            'itemsJson': jsonEncode(o.items.map((e) => e.toMap()).toList()),
            'status': o.status,
            'paidAmount': o.paidAmount,
            'onlineOrderId': o.onlineOrderId,
            'createdAt': o.createdAt.millisecondsSinceEpoch,
            'completedAt': o.completedAt?.millisecondsSinceEpoch,
            'kitchenStatus': o.kitchenStatus,
            'cookingStartedAt': o.cookingStartedAt?.millisecondsSinceEpoch,
            'completedItemIdsJson': jsonEncode(o.completedItemIds),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Menambah atau memperbarui pesanan individual secara persisten
  Future<void> upsertOrder(OrderModel order) async {
    if (kIsWeb) {
      final orders = await getOrders();
      final idx = orders.indexWhere((o) => o.id == order.id);
      if (idx >= 0) {
        orders[idx] = order;
      } else {
        orders.add(order);
      }
      await saveOrders(orders);
      return;
    }
    final db = (await database)!;
    await db.insert(
      'orders',
      {
        'id': order.id,
        'shiftId': order.shiftId,
        'tableNo': order.tableNo,
        'customerName': order.customerName,
        'itemsJson': jsonEncode(order.items.map((e) => e.toMap()).toList()),
        'status': order.status,
        'paidAmount': order.paidAmount,
        'onlineOrderId': order.onlineOrderId,
        'createdAt': order.createdAt.millisecondsSinceEpoch,
        'completedAt': order.completedAt?.millisecondsSinceEpoch,
        'kitchenStatus': order.kitchenStatus,
        'cookingStartedAt': order.cookingStartedAt?.millisecondsSinceEpoch,
        'completedItemIdsJson': jsonEncode(order.completedItemIds),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===================== CRUD TRANSACTIONS =====================

  Future<List<TransactionModel>> getTransactions() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_transactions');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final txs = list
          .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return txs;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('transactions', orderBy: 'timestamp DESC');
    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(transactions.map((t) => t.toMap()).toList());
      await prefs.setString('web_db_transactions', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      final batch = txn.batch();
      for (final t in transactions) {
        batch.insert('transactions', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertTransaction(TransactionModel transaction) async {
    if (kIsWeb) {
      final txs = await getTransactions();
      final idx = txs.indexWhere((t) => t.id == transaction.id);
      if (idx >= 0) {
        txs[idx] = transaction;
      } else {
        txs.insert(0, transaction);
      }
      await saveTransactions(txs);
      return;
    }
    final db = (await database)!;
    await db.insert('transactions', transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===================== CRUD SHIFTS =====================

  Future<List<ShiftModel>> getShifts() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_shifts');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final shifts = list
          .map((e) => ShiftModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      shifts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return shifts;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('shifts', orderBy: 'startedAt DESC');
    return rows.map((e) => ShiftModel.fromMap(e)).toList();
  }

  Future<void> saveShifts(List<ShiftModel> shifts) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(shifts.map((s) => s.toMap()).toList());
      await prefs.setString('web_db_shifts', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('shifts');
      final batch = txn.batch();
      for (final s in shifts) {
        batch.insert('shifts', s.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertShift(ShiftModel shift) async {
    if (kIsWeb) {
      final shifts = await getShifts();
      final idx = shifts.indexWhere((s) => s.id == shift.id);
      if (idx >= 0) {
        shifts[idx] = shift;
      } else {
        shifts.insert(0, shift);
      }
      await saveShifts(shifts);
      return;
    }
    final db = (await database)!;
    await db.insert('shifts', shift.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===================== CRUD CASH MOVEMENTS =====================

  Future<List<CashMovementModel>> getCashMovements() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_cash_movements');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final cms = list
          .map((e) => CashMovementModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      cms.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return cms;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('cash_movements', orderBy: 'timestamp DESC');
    return rows.map((e) => CashMovementModel.fromMap(e)).toList();
  }

  Future<void> saveCashMovements(List<CashMovementModel> movements) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(movements.map((m) => m.toMap()).toList());
      await prefs.setString('web_db_cash_movements', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('cash_movements');
      final batch = txn.batch();
      for (final m in movements) {
        batch.insert('cash_movements', m.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertCashMovement(CashMovementModel movement) async {
    if (kIsWeb) {
      final cms = await getCashMovements();
      cms.insert(0, movement);
      await saveCashMovements(cms);
      return;
    }
    final db = (await database)!;
    await db.insert('cash_movements', movement.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===================== CRUD CUSTOMERS =====================

  Future<List<CustomerModel>> getCustomers() async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final raw = prefs.getString('web_db_customers');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final custs = list
          .map((e) => CustomerModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      custs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return custs;
    }
    final db = (await database)!;
    final List<Map<String, dynamic>> rows =
        await db.query('customers', orderBy: 'name ASC');
    return rows.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<void> saveCustomers(List<CustomerModel> customers) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefs();
      final data = jsonEncode(customers.map((c) => c.toMap()).toList());
      await prefs.setString('web_db_customers', data);
      return;
    }
    final db = (await database)!;
    await db.transaction((txn) async {
      await txn.delete('customers');
      final batch = txn.batch();
      for (final c in customers) {
        batch.insert('customers', c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertCustomer(CustomerModel customer) async {
    if (kIsWeb) {
      final custs = await getCustomers();
      final idx = custs.indexWhere((c) => c.id == customer.id);
      if (idx >= 0) {
        custs[idx] = customer;
      } else {
        custs.add(customer);
      }
      await saveCustomers(custs);
      return;
    }
    final db = (await database)!;
    await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Menutup koneksi database SQLite
  Future<void> close() async {
    if (kIsWeb) return;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
