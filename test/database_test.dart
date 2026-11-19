import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:mini_resto_pos/services/database_migration_service.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/models/category_model.dart';
import 'package:mini_resto_pos/models/customer_model.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/models/transaction_model.dart';
import 'package:mini_resto_pos/models/shift_model.dart';
import 'package:mini_resto_pos/models/cash_movement_model.dart';

void main() {
  // Inisialisasi sqflite FFI untuk eksekusi unit test di lingkungan VM Windows/Desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper SQLite Unit Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // Gunakan in-memory database unik untuk setiap test case
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
      await dbHelper.clearAllData();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('Inisialisasi tabel dan CRUD Produk serta Kategori', () async {
      final categories = [
        CategoryModel(id: 'cat_test', name: 'Makanan Uji', sortOrder: 1, iconName: 'restaurant'),
      ];
      await dbHelper.saveCategories(categories);
      final fetchedCats = await dbHelper.getCategories();
      expect(fetchedCats.length, 1);
      expect(fetchedCats.first.name, 'Makanan Uji');

      final product = ProductModel(
        id: 'p_test',
        name: 'Kopi Susu Uji',
        categoryId: 'cat_test',
        buyPrice: 5000,
        sellPrice: 15000,
        stock: 50,
        trackStock: true,
        unit: 'Cup',
      );
      await dbHelper.saveProducts([product]);
      final fetchedProds = await dbHelper.getProducts();
      expect(fetchedProds.length, 1);
      expect(fetchedProds.first.name, 'Kopi Susu Uji');
      expect(fetchedProds.first.trackStock, isTrue);

      // Uji upsert update stok
      final updated = product.copyWith(stock: 45);
      await dbHelper.upsertProduct(updated);
      final prodsAfter = await dbHelper.getProducts();
      expect(prodsAfter.first.stock, 45);
    });

    test('CRUD Pesanan (Orders & Items) dan Transaksi', () async {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'ord_test_01',
        shiftId: 'shift_1',
        tableNo: '05',
        customerName: 'Budi Santoso',
        items: [
          OrderItem(productId: 'p_test', name: 'Kopi Susu Uji', price: 15000, qty: 2),
        ],
        status: 'open',
        paidAmount: 15000,
        onlineOrderId: 'cloud_order_99',
        kitchenStatus: 'cooking',
        cookingStartedAt: now,
        completedItemIds: ['p_test'],
      );
      await dbHelper.saveOrders([order]);
      final orders = await dbHelper.getOrders();
      expect(orders.length, 1);
      expect(orders.first.tableNo, '05');
      expect(orders.first.items.length, 1);
      expect(orders.first.items.first.qty, 2);
      expect(orders.first.paidAmount, 15000);
      expect(orders.first.onlineOrderId, 'cloud_order_99');
      expect(orders.first.kitchenStatus, 'cooking');
      expect(orders.first.cookingStartedAt?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(orders.first.completedItemIds, ['p_test']);

      // Uji upsertOrder memperbarui status dapur dan checklist
      final updatedOrder = orders.first.copyWith(
        kitchenStatus: 'ready',
        completedItemIds: ['p_test', 'p_test_done'],
        paidAmount: 30000,
      );
      await dbHelper.upsertOrder(updatedOrder);
      final ordersAfterUpsert = await dbHelper.getOrders();
      expect(ordersAfterUpsert.first.kitchenStatus, 'ready');
      expect(ordersAfterUpsert.first.paidAmount, 30000);
      expect(ordersAfterUpsert.first.completedItemIds.length, 2);

      final trx = TransactionModel(
        id: 'trx_test_01',
        orderId: 'ord_test_01',
        shiftId: 'shift_1',
        cashierId: 'user_budi',
        cashierName: 'Budi',
        paymentMethod: 'cash',
        totalAmount: 30000,
        amountPaid: 50000,
        change: 20000,
        customerName: 'Budi Santoso',
      );
      await dbHelper.insertTransaction(trx);
      final trxs = await dbHelper.getTransactions();
      expect(trxs.length, 1);
      expect(trxs.first.totalAmount, 30000);
      expect(trxs.first.change, 20000);
    });

    test('Migrasi Skema Database v1 ke v2 menambahkan kolom KDS dan DP QRIS', () async {
      const testDbPath = 'test_upgrade.db';
      await databaseFactory.deleteDatabase(testDbPath);

      // Simulasikan database v1 lama tanpa kolom baru
      final oldDb = await openDatabase(
        testDbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              shiftId TEXT NOT NULL,
              tableNo TEXT,
              customerName TEXT NOT NULL,
              itemsJson TEXT NOT NULL,
              status TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              completedAt INTEGER
            )
          ''');
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
              customerName TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
          // Sisipkan 1 order versi v1
          await db.insert('orders', {
            'id': 'ord_v1',
            'shiftId': 's1',
            'tableNo': '01',
            'customerName': 'Tamu V1',
            'itemsJson': '[]',
            'status': 'open',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        },
      );
      await oldDb.close();

      // Buka dengan DatabaseHelper (versi 2 dengan onUpgrade)
      await dbHelper.initDatabase(customPath: testDbPath);
      final migratedOrders = await dbHelper.getOrders();
      expect(migratedOrders.length, 1);
      expect(migratedOrders.first.id, 'ord_v1');
      expect(migratedOrders.first.paidAmount, 0);
      expect(migratedOrders.first.kitchenStatus, 'pending');
      expect(migratedOrders.first.completedItemIds, isEmpty);

      // Pastikan bisa menyimpan order baru dengan kolom v2
      final newV2Order = OrderModel(
        id: 'ord_v2',
        shiftId: 's1',
        customerName: 'Tamu V2',
        items: [],
        paidAmount: 25000,
        kitchenStatus: 'ready',
        completedItemIds: ['item_abc'],
      );
      await dbHelper.upsertOrder(newV2Order);
      final allOrders = await dbHelper.getOrders();
      expect(allOrders.length, 2);
      final fetchedV2 = allOrders.firstWhere((o) => o.id == 'ord_v2');
      expect(fetchedV2.paidAmount, 25000);
      expect(fetchedV2.kitchenStatus, 'ready');
      expect(fetchedV2.completedItemIds, ['item_abc']);

      // Bersihkan file database pengujian
      await dbHelper.close();
      await databaseFactory.deleteDatabase(testDbPath);
    });

    test('CRUD Shift & Cash Movements', () async {
      final shift = ShiftModel(
        id: 'shift_test',
        userId: 'user_budi',
        cashierName: 'Budi',
        startedAt: DateTime.now(),
        initialCash: 100000,
      );
      await dbHelper.saveShifts([shift]);
      final shifts = await dbHelper.getShifts();
      expect(shifts.length, 1);
      expect(shifts.first.initialCash, 100000);

      final movement = CashMovementModel(
        id: 'cm_01',
        shiftId: 'shift_test',
        userId: 'user_budi',
        cashierName: 'Budi',
        type: 'out',
        amount: 15000,
        notes: 'Beli es batu kristal',
      );
      await dbHelper.insertCashMovement(movement);
      final movements = await dbHelper.getCashMovements();
      expect(movements.length, 1);
      expect(movements.first.notes, 'Beli es batu kristal');
    });

    test('CRUD Pelanggan Kasbon', () async {
      final customer = CustomerModel(
        id: 'cust_01',
        name: 'Pak RT',
        phoneWA: '081234567890',
        totalDebt: 25000,
        debtLimit: 100000,
      );
      await dbHelper.saveCustomers([customer]);
      final customers = await dbHelper.getCustomers();
      expect(customers.length, 1);
      expect(customers.first.totalDebt, 25000);
    });
  });

  group('DatabaseMigrationService & Clean Up Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
      await dbHelper.clearAllData();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('Migrasi sukses memindahkan data dan membersihkan SharedPreferences', () async {
      // Simulasikan SharedPreferences dengan data lama
      SharedPreferences.setMockInitialValues({
        'pos_warkop_categories': jsonEncode([
          {'id': 'c_old', 'name': 'Kategori Lama', 'sortOrder': 1, 'iconName': 'star'}
        ]),
        'pos_warkop_products': jsonEncode([
          {
            'id': 'p_old',
            'name': 'Menu Lama',
            'categoryId': 'c_old',
            'buyPrice': 3000,
            'sellPrice': 7000,
            'stock': 10,
            'trackStock': true,
            'unit': 'Porsi'
          }
        ]),
        'pos_warkop_transactions': jsonEncode([
          {
            'id': 'trx_old',
            'orderId': 'ord_old',
            'shiftId': 's_old',
            'cashierId': 'u1',
            'cashierName': 'Kasir 1',
            'paymentMethod': 'cash',
            'totalAmount': 7000,
            'amountPaid': 10000,
            'change': 3000,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pos_warkop_categories'), isTrue);
      expect(prefs.containsKey('pos_warkop_products'), isTrue);
      expect(prefs.containsKey('pos_warkop_transactions'), isTrue);
      expect(prefs.getBool(DatabaseMigrationService.keyIsMigrated), isNull);

      final migration = DatabaseMigrationService(prefs, dbHelper);
      final result = await migration.migrateIfNeeded();
      expect(result, isTrue);

      // Verifikasi data berpindah ke SQLite
      final prods = await dbHelper.getProducts();
      expect(prods.length, 1);
      expect(prods.first.name, 'Menu Lama');

      final trxs = await dbHelper.getTransactions();
      expect(trxs.length, 1);
      expect(trxs.first.id, 'trx_old');

      // Verifikasi PEMBERSIHAN BERSIH: kunci JSON lama harus sudah terhapus
      expect(prefs.containsKey('pos_warkop_categories'), isFalse);
      expect(prefs.containsKey('pos_warkop_products'), isFalse);
      expect(prefs.containsKey('pos_warkop_transactions'), isFalse);

      // Verifikasi flag migrasi tersimpan
      expect(prefs.getBool(DatabaseMigrationService.keyIsMigrated), isTrue);

      // Migrasi kedua kali tidak boleh mengeksekusi ulang
      final secondResult = await migration.migrateIfNeeded();
      expect(secondResult, isFalse);
    });
  });

  group('StorageService Hybrid Integration Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
      await dbHelper.clearAllData();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('Inisialisasi StorageService, seed data awal, dan verifikasi cache sinkron', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await StorageService.init(dbHelper: dbHelper);

      // Verifikasi produk awal berhasil di-seed
      final products = service.getProducts();
      expect(products.isNotEmpty, isTrue);

      // Verifikasi kategori awal
      final categories = service.getCategories();
      expect(categories.isNotEmpty, isTrue);

      // Simpan transaksi baru dan pastikan langsung tersimpan di cache dan SQLite
      final newTrx = TransactionModel(
        id: 'trx_live_01',
        orderId: 'ord_live_01',
        shiftId: 'shift_live',
        cashierId: 'user_budi',
        cashierName: 'Budi',
        paymentMethod: 'qris',
        totalAmount: 45000,
        amountPaid: 45000,
        change: 0,
      );

      await service.insertTransaction(newTrx);
      expect(service.getTransactions().any((t) => t.id == 'trx_live_01'), isTrue);

      // Verifikasi di SQLite
      final sqliteTrxs = await dbHelper.getTransactions();
      expect(sqliteTrxs.any((t) => t.id == 'trx_live_01'), isTrue);
    });
  });
}
