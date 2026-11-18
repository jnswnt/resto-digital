import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:mini_resto_pos/services/backup_restore_service.dart';
import 'package:mini_resto_pos/providers/pos_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late StorageService storageService;
  late PosProvider posProvider;
  late DatabaseHelper dbHelper;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dbHelper = DatabaseHelper();
    await dbHelper.initDatabase(customPath: inMemoryDatabasePath);

    storageService = await StorageService.init(dbHelper: dbHelper);
    posProvider = PosProvider(storageService);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Fitur 1 & 2: Pajak Restoran (PB1), Service Charge, dan Diskon', () {
    test('Kalkulasi diskon persen dan nominal di PosProvider', () {
      final products = posProvider.products;
      expect(products.isNotEmpty, true);

      // Tambah produk ke keranjang
      posProvider.addToCart(products.first); // Misal Rp 15.000 atau Rp 20.000
      final subtotal = posProvider.cartSubtotal;
      expect(subtotal > 0, true);

      // Terapkan diskon 10%
      posProvider.setDiscountPercent(10.0);
      expect(posProvider.cartDiscountPercent, 10.0);
      final expectedDiscount = (subtotal * 0.10).round();
      expect(posProvider.cartDiscountAmount, expectedDiscount);
      expect(posProvider.cartSubtotalAfterDiscount, subtotal - expectedDiscount);

      // Terapkan diskon nominal langsung
      posProvider.setDiscountAmount(5000);
      expect(posProvider.cartDiscountAmount, 5000);
      expect(posProvider.cartSubtotalAfterDiscount, subtotal - 5000);

      // Hapus diskon
      posProvider.clearDiscount();
      expect(posProvider.cartDiscountAmount, 0);
      expect(posProvider.cartDiscountPercent, 0.0);
      expect(posProvider.cartSubtotalAfterDiscount, subtotal);
    });

    test('Kalkulasi Service Charge (5%) dan Pajak PB1 (10%) berdasarkan SettingsModel', () {
      final products = posProvider.products;
      posProvider.addToCart(products.first);
      final subtotal = posProvider.cartSubtotal;

      // Konfigurasi dengan Pajak PB1 10% dan Service Charge 5%
      final settings = SettingsModel(
        enableTax: true,
        taxPercentage: 10.0,
        enableServiceCharge: true,
        serviceChargePercentage: 5.0,
      );

      final expectedService = ((subtotal * 5.0) / 100).round();
      final expectedTax = (((subtotal + expectedService) * 10.0) / 100).round();
      final expectedGrandTotal = subtotal + expectedService + expectedTax;

      expect(posProvider.calculateServiceCharge(settings), expectedService);
      expect(posProvider.calculateTax(settings), expectedTax);
      expect(posProvider.calculateCartGrandTotal(settings), expectedGrandTotal);
    });

    test('Checkout kasir menyimpan diskon, service charge, dan pajak ke OrderModel & TransactionModel', () async {
      final products = posProvider.products;
      posProvider.addToCart(products.first);
      final sub = posProvider.cartSubtotal;

      posProvider.setDiscountAmount(2000);

      final trx = await posProvider.completeCheckout(
        shiftId: 'shift_test',
        cashierId: 'c1',
        cashierName: 'Kasir Uji',
        paymentMethod: 'cash',
        amountPaid: sub - 2000,
        change: 0,
        discountAmount: 2000,
        discountPercent: 0.0,
        serviceChargeAmount: 1000,
        taxAmount: 1500,
      );

      expect(trx.subtotal, sub);
      expect(trx.discountAmount, 2000);
      expect(trx.serviceChargeAmount, 1000);
      expect(trx.taxAmount, 1500);
      expect(trx.totalAmount, sub - 2000 + 1000 + 1500);

      // Verifikasi pesanan tersimpan di database
      final savedOrders = await dbHelper.getOrders();
      final lastOrder = savedOrders.firstWhere((o) => o.id == trx.orderId);
      expect(lastOrder.discountAmount, 2000);
      expect(lastOrder.serviceChargeAmount, 1000);
      expect(lastOrder.taxAmount, 1500);
      expect(lastOrder.total, sub - 2000 + 1000 + 1500);
    });
  });

  group('Fitur 3: Split Bill (Pisah Tagihan)', () {
    test('splitOrderToNewTab memindahkan item terpilih ke tab baru dan mengurangi pesanan asal', () async {
      final products = posProvider.products;
      expect(products.length >= 2, true);

      // Buat open tab dengan 2 menu berbeda
      posProvider.addToCart(products[0]);
      posProvider.addToCart(products[1]);
      posProvider.setTableNo('Meja 05');
      final originalOrder = await posProvider.saveAsOpenTab(shiftId: 'shift_test');

      expect(originalOrder.items.length, 2);

      // Pisahkan item pertama ke meja baru
      final itemToSplit = [originalOrder.items[0]];
      final newTab = await posProvider.splitOrderToNewTab(
        sourceOrderId: originalOrder.id,
        itemsToSplit: itemToSplit,
        newTableNo: 'Meja 05 - Bill B',
        newCustomerName: 'Tamu B',
        shiftId: 'shift_test',
      );

      expect(newTab != null, true);
      expect(newTab!.tableNo, 'Meja 05 - Bill B');
      expect(newTab.customerName, 'Tamu B');
      expect(newTab.items.length, 1);
      expect(newTab.items[0].productId, products[0].id);

      // Verifikasi pesanan meja asal tinggal 1 item (item kedua)
      final orders = await dbHelper.getOrders();
      final updatedOriginal = orders.firstWhere((o) => o.id == originalOrder.id);
      expect(updatedOriginal.items.length, 1);
      expect(updatedOriginal.items[0].productId, products[1].id);
      expect(updatedOriginal.status, 'open');
    });

    test('splitOrderAndCheckoutDirectly membayar sebagian item dan menyelesaikan meja jika seluruh item lunas', () async {
      final products = posProvider.products;
      posProvider.addToCart(products[0]);
      posProvider.setTableNo('Meja 07');
      final originalOrder = await posProvider.saveAsOpenTab(shiftId: 'shift_test');

      // Bayar langsung item tersebut lewat split checkout
      final trx = await posProvider.splitOrderAndCheckoutDirectly(
        sourceOrderId: originalOrder.id,
        itemsToPay: [originalOrder.items[0]],
        shiftId: 'shift_test',
        cashierId: 'c1',
        cashierName: 'Kasir Uji',
        paymentMethod: 'cash',
        amountPaid: originalOrder.items[0].total,
        change: 0,
      );

      expect(trx.totalAmount, originalOrder.items[0].total);

      // Karena seluruh item sudah dibayar, meja asal harus berstatus completed
      final orders = await dbHelper.getOrders();
      final updatedOriginal = orders.firstWhere((o) => o.id == originalOrder.id);
      expect(updatedOriginal.status, 'completed');
    });
  });

  group('Fitur 4: Backup & Restore Database Manual', () {
    test('generateBackupJson dan restoreFromBackupJson bekerja sempurna', () async {
      // 1. Tambah data sampel
      final products = posProvider.products;
      posProvider.addToCart(products.first);
      await posProvider.saveAsOpenTab(shiftId: 'shift_backup_test');

      // 2. Generate JSON backup
      final backupJson = await BackupRestoreService.generateBackupJson(
        dbHelper: dbHelper,
        storageService: storageService,
      );
      expect(backupJson.contains('mini_resto_pos'), true);
      expect(backupJson.contains('categories'), true);
      expect(backupJson.contains('products'), true);
      expect(backupJson.contains('orders'), true);

      // 3. Clear seluruh database
      await dbHelper.clearAllData();
      final emptyOrders = await dbHelper.getOrders();
      expect(emptyOrders.isEmpty, true);

      // 4. Restore dari string JSON
      final restoreSuccess = await BackupRestoreService.restoreFromBackupJson(
        jsonContent: backupJson,
        dbHelper: dbHelper,
        storageService: storageService,
      );
      expect(restoreSuccess, true);

      // 5. Verifikasi data berhasil pulih
      final restoredOrders = await dbHelper.getOrders();
      expect(restoredOrders.isNotEmpty, true);
      final restoredProducts = await dbHelper.getProducts();
      expect(restoredProducts.isNotEmpty, true);
    });
  });
}
