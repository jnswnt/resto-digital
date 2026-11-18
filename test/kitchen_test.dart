import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mini_resto_pos/models/user_model.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/providers/pos_provider.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// PENGUJIAN FITUR DAPUR (KDS - KITCHEN DISPLAY SYSTEM & TIKET KOT)
/// ============================================================================
/// Berkas ini menguji:
/// 1. Hak akses dan properti UserModel untuk role Koki Dapur ('kitchen').
/// 2. Properti OrderModel terkait status dapur dan item checklist KDS.
/// 3. Siklus alur dapur pada PosProvider:
///    - Pending (Menunggu Masak) -> Cooking (Sedang Dimasak)
///    - Cooking -> Ready (Siap Saji) -> Served (Selesai Disajikan)
/// 4. Fitur checklist per item pesanan (completedItemIds).
/// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('KDS & Kitchen Staff Role Test', () {
    test('UserModel mendeteksi role kitchen dan membatasi akses non-owner', () {
      final kitchenUser = UserModel(
        id: 'kds_chef_1',
        name: 'Koki Juna',
        pinHash: 'dummy_hash',
        salt: 'dummy_salt',
        role: 'kitchen',
        isActive: true,
      );

      // Verifikasi role dapur
      expect(kitchenUser.isKitchen, isTrue, reason: 'Koki harus diakui sebagai kitchen role');
      expect(kitchenUser.isOwner, isFalse, reason: 'Koki tidak boleh memiliki akses owner');
      expect(kitchenUser.isStaff, isTrue, reason: 'Koki adalah bagian dari staf operasional');
      expect(kitchenUser.isCashier, isFalse, reason: 'Koki bukan kasir');
    });

    test('OrderModel mengelola properti siklus dapur dengan benar', () {
      final now = DateTime.now();
      final item1 = OrderItem(
        productId: 'prod_1',
        name: 'Ayam Bakar Madu',
        price: 28000,
        qty: 2,
        notes: 'Pedas manis, cabai 5',
      );
      final item2 = OrderItem(
        productId: 'prod_2',
        name: 'Es Teh Manis Jumbo',
        price: 5000,
        qty: 2,
        notes: 'Sedikit gula, es banyak',
      );

      final order = OrderModel(
        id: 'ORD-KDS-001',
        shiftId: 'shift_active',
        items: [item1, item2],
        customerName: 'Bapak Ahmad',
        tableNo: 'Meja 05',
        status: 'open',
        paidAmount: 0,
        kitchenStatus: 'pending',
        createdAt: now,
      );

      expect(order.kitchenStatus, equals('pending'));
      expect(order.isKitchenPending, isTrue);
      expect(order.isKitchenCooking, isFalse);
      expect(order.isKitchenReady, isFalse);
      expect(order.isKitchenServed, isFalse);
      expect(order.completedItemIds, isEmpty);
      expect(order.total, equals(66000));
      expect(order.totalItems, equals(4));

      // Simulasi update saat mulai dimasak
      final cookingOrder = order.copyWith(
        kitchenStatus: 'cooking',
        cookingStartedAt: now,
        completedItemIds: ['${order.id}_prod_1_0'],
      );

      expect(cookingOrder.isKitchenCooking, isTrue);
      expect(cookingOrder.cookingStartedAt, equals(now));
      expect(cookingOrder.completedItemIds.contains('${order.id}_prod_1_0'), isTrue);

      // Simulasi update saat makanan siap saji
      final readyOrder = cookingOrder.copyWith(kitchenStatus: 'ready');
      expect(readyOrder.isKitchenReady, isTrue);
      expect(readyOrder.isKitchenCooking, isFalse);

      // Simulasi serialisasi & deserialisasi Map
      final map = readyOrder.toMap();
      final fromMap = OrderModel.fromMap(map);

      expect(fromMap.kitchenStatus, equals('ready'));
      expect(fromMap.completedItemIds.length, equals(1));
      expect(fromMap.tableNo, equals('Meja 05'));
      expect(fromMap.customerName, equals('Bapak Ahmad'));
    });

    test('PosProvider memperbarui siklus masak dapur dan checklist item', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final posProvider = PosProvider(storage);

      final testOrder = OrderModel(
        id: 'ORD-KDS-FLOW',
        shiftId: 'shift_kds_test',
        items: [
          OrderItem(productId: 'item_1', name: 'Nasi Liwet Komplit', price: 32000, qty: 1),
          OrderItem(productId: 'item_2', name: 'Es Lemon Tea', price: 8000, qty: 1),
        ],
        status: 'open',
        paidAmount: 0,
        tableNo: 'Meja 02',
        customerName: 'Pelanggan Meja 02',
        kitchenStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Simpan pesanan awal ke antrean open tab
      await storage.upsertOrder(testOrder);

      // 1. Verifikasi pesanan masuk ke daftar antrean dapur
      expect(posProvider.kitchenOrders.any((o) => o.id == 'ORD-KDS-FLOW'), isTrue);
      var current = posProvider.kitchenOrders.firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.kitchenStatus, equals('pending'));

      // 2. Koki menekan tombol "Mulai Masak"
      await posProvider.updateKitchenStatus('ORD-KDS-FLOW', 'cooking');
      current = storage.getOrders().firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.kitchenStatus, equals('cooking'));
      expect(current.cookingStartedAt, isNotNull);

      // 3. Koki mencentang salah satu item yang selesai dimasak
      const itemKey = 'ORD-KDS-FLOW_item_1_0';
      await posProvider.toggleKitchenItemCompleted('ORD-KDS-FLOW', itemKey);
      current = storage.getOrders().firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.completedItemIds.contains(itemKey), isTrue);

      // Toggle kembali untuk membatalkan checklist
      await posProvider.toggleKitchenItemCompleted('ORD-KDS-FLOW', itemKey);
      current = storage.getOrders().firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.completedItemIds.contains(itemKey), isFalse);

      // 4. Koki menekan "Siap Saji"
      await posProvider.updateKitchenStatus('ORD-KDS-FLOW', 'ready');
      current = storage.getOrders().firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.kitchenStatus, equals('ready'));

      // 5. Pelayan mengantarkan pesanan ke meja -> "Selesai Saji"
      await posProvider.updateKitchenStatus('ORD-KDS-FLOW', 'served');
      current = storage.getOrders().firstWhere((o) => o.id == 'ORD-KDS-FLOW');
      expect(current.kitchenStatus, equals('served'));

      // Pesanan yang sudah 'served' tidak muncul di antrean aktif dapur
      final activeInKitchen = posProvider.kitchenOrders.where((o) => o.id == 'ORD-KDS-FLOW').toList();
      expect(activeInKitchen.isEmpty, isTrue, reason: 'Pesanan served harus dikeluarkan dari antrean koki');
    });

    test('Skenario Pay-First: Transaksi kasir bayar langsung tetap masuk KDS dan keluar saat served', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final posProvider = PosProvider(storage);

      // 1. Kasir input pesanan Dine-in meja 03 dan bayar lunas langsung di kasir
      posProvider.setTableNo('Meja 03');
      posProvider.setCustomerName('Ibu Ratna');
      posProvider.addToCart(
        ProductModel(id: 'p1', name: 'Nasi Goreng Spesial', sellPrice: 25000, buyPrice: 15000, categoryId: 'cat1', stock: 10),
      );

      final trx = await posProvider.completeCheckout(
        shiftId: 'shift_kds_payfirst',
        cashierId: 'cashier_1',
        cashierName: 'Kasir Utama',
        paymentMethod: 'cash',
        amountPaid: 50000,
        change: 25000,
      );

      // Verifikasi transaksi lunas & tersimpan
      expect(trx.totalAmount, equals(25000));
      final completedOrder = posProvider.findOrderById(trx.orderId);
      expect(completedOrder.status, equals('completed'));
      expect(completedOrder.kitchenStatus, equals('pending'));
      expect(completedOrder.tableNo, equals('Meja 03'));

      // 2. Verifikasi tiket KOT Dapur LANGSUNG MUNCUL di kitchenOrders
      final kdsOrders = posProvider.kitchenOrders.where((o) => o.id == trx.orderId).toList();
      expect(kdsOrders.isNotEmpty, isTrue, reason: 'Pesanan bayar langsung kasir harus tetap masuk antrean KDS');
      expect(kdsOrders.first.kitchenStatus, equals('pending'));
      expect(kdsOrders.first.tableNo, equals('Meja 03'));

      // 3. Koki memproses makanan (pending -> cooking -> ready)
      await posProvider.updateKitchenStatus(trx.orderId, 'cooking');
      expect(posProvider.kitchenOrders.firstWhere((o) => o.id == trx.orderId).isKitchenCooking, isTrue);

      await posProvider.updateKitchenStatus(trx.orderId, 'ready');
      expect(posProvider.kitchenOrders.firstWhere((o) => o.id == trx.orderId).isKitchenReady, isTrue);

      // 4. Staf menyajikan makanan ke meja -> status 'served'
      await posProvider.updateKitchenStatus(trx.orderId, 'served');

      // 5. Verifikasi pesanan keluar dari antrean KDS
      final remainingKds = posProvider.kitchenOrders.where((o) => o.id == trx.orderId).toList();
      expect(remainingKds.isEmpty, isTrue, reason: 'Pesanan served harus dikeluarkan dari KDS');
    });

    test('Skenario Takeaway: Bayar langsung kasir & bayar nanti terintegrasi dengan KDS', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final posProvider = PosProvider(storage);

      // A. Takeaway Bayar Langsung di Muka
      posProvider.setTableNo('Takeaway');
      posProvider.setCustomerName('Pak Joko');
      posProvider.addToCart(
        ProductModel(id: 'p2', name: 'Kopi Susu Gula Aren', sellPrice: 18000, buyPrice: 8000, categoryId: 'cat2', stock: 20),
      );

      final directTrx = await posProvider.completeCheckout(
        shiftId: 'shift_kds_takeaway',
        cashierId: 'cashier_1',
        cashierName: 'Kasir Utama',
        paymentMethod: 'qris',
        amountPaid: 18000,
        change: 0,
      );

      // Verifikasi pesanan takeaway lunas masuk KDS
      expect(posProvider.kitchenOrders.any((o) => o.id == directTrx.orderId), isTrue);
      final directOrder = posProvider.kitchenOrders.firstWhere((o) => o.id == directTrx.orderId);
      expect(directOrder.tableNo, equals('Takeaway'));
      expect(directOrder.kitchenStatus, equals('pending'));

      // Saat diserahkan ke pelanggan takeaway, dikeluarkan dari KDS
      await posProvider.updateKitchenStatus(directTrx.orderId, 'served');
      expect(posProvider.kitchenOrders.any((o) => o.id == directTrx.orderId), isFalse);

      // B. Takeaway Bayar Nanti (Simpan Tab)
      posProvider.setTableNo('Takeaway');
      posProvider.setCustomerName('Mbak Rina');
      posProvider.addToCart(
        ProductModel(id: 'p3', name: 'Roti Bakar Coklat', sellPrice: 15000, buyPrice: 7000, categoryId: 'cat1', stock: 15),
      );

      final openOrder = await posProvider.saveAsOpenTab(shiftId: 'shift_kds_takeaway');
      expect(openOrder.status, equals('open'));
      expect(openOrder.kitchenStatus, equals('pending'));

      // Masuk KDS sebagai OPEN TAB
      expect(posProvider.kitchenOrders.any((o) => o.id == openOrder.id), isTrue);

      // Tamu bayar saat makanan selesai
      posProvider.loadOpenTabForEdit(openOrder);
      final paidTrx = await posProvider.completeCheckout(
        shiftId: 'shift_kds_takeaway',
        cashierId: 'cashier_1',
        cashierName: 'Kasir Utama',
        paymentMethod: 'cash',
        amountPaid: 20000,
        change: 5000,
      );

      // Order menjadi completed dan tetap di KDS sampai di-served
      expect(paidTrx.totalAmount, equals(15000));
      expect(posProvider.kitchenOrders.any((o) => o.id == openOrder.id), isTrue);

      await posProvider.updateKitchenStatus(openOrder.id, 'served');
      expect(posProvider.kitchenOrders.any((o) => o.id == openOrder.id), isFalse);
    });

    test('Transaksi pelunasan kasbon / piutang TIDAK PERNAH masuk antrean KDS', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final posProvider = PosProvider(storage);

      // Catat pelunasan kasbon a/n Mas Joko
      final repayTrx = await posProvider.recordDebtRepaymentTransaction(
        customerId: 'cust_joko',
        customerName: 'Mas Joko (Bengkel)',
        amountPaid: 75000,
        paymentMethod: 'cash',
        shiftId: 'shift_kds_test',
        cashierId: 'cashier_1',
        cashierName: 'Kasir Utama',
      );

      // Verifikasi transaksi tercatat di sistem
      expect(repayTrx.totalAmount, equals(75000));
      expect(repayTrx.customerName, equals('Mas Joko (Bengkel)'));

      // Verifikasi di PosProvider bahwa pesanan pelunasan kasbon TIDAK MASUK ke kitchenOrders
      expect(posProvider.kitchenOrders.any((o) => o.id == repayTrx.orderId), isFalse,
          reason: 'Pelunasan kasbon bukan makanan dan tidak boleh muncul di KDS');

      // Verifikasi kitchenStatus pesanan pelunasan kasbon adalah 'served'
      final repayOrder = posProvider.findOrderById(repayTrx.orderId);
      expect(repayOrder.kitchenStatus, equals('served'));
    });
  });
}
