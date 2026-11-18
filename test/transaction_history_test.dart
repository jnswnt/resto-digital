import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/models/transaction_model.dart';
import 'package:mini_resto_pos/models/category_model.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/models/restaurant_table.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/services/printer_receipt_service.dart';
import 'package:mini_resto_pos/providers/pos_provider.dart';
import 'package:mini_resto_pos/providers/analytics_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID', null);
  });

  group('Transaction History & Lookup Tests', () {
    late StorageService storageService;
    late PosProvider posProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);

      // Simpan beberapa produk dan kategori uji coba
      await storageService.saveCategories([
        CategoryModel(id: 'cat_makanan', name: 'Makanan', sortOrder: 1),
        CategoryModel(id: 'cat_minuman', name: 'Minuman', sortOrder: 2),
      ]);

      await storageService.saveProducts([
        ProductModel(
          id: 'p1',
          name: 'Nasi Goreng Spesial',
          categoryId: 'cat_makanan',
          buyPrice: 12000,
          sellPrice: 22000,
          stock: 50,
        ),
        ProductModel(
          id: 'p2',
          name: 'Es Teh Manis',
          categoryId: 'cat_minuman',
          buyPrice: 2000,
          sellPrice: 5000,
          stock: 100,
        ),
      ]);

      posProvider = PosProvider(storageService);
    });

    test('Menyelesaikan pesanan otomatis mencatat riwayat transaksi di PosProvider', () async {
      // 1. Tambahkan item ke keranjang belanja
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p1'));
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p2'));
      posProvider.setCustomerName('Kak Doni');
      posProvider.setTableNo('Meja 05');

      expect(posProvider.cartSubtotal, equals(27000));

      // 2. Selesaikan pembayaran
      final trx = await posProvider.completeCheckout(
        cashierId: 'user_budi',
        cashierName: 'Budi (Kasir)',
        shiftId: 'shift_1',
        paymentMethod: 'cash',
        amountPaid: 30000,
        change: 3000,
        customerName: 'Kak Doni',
      );

      // 3. Verifikasi transaksi tersimpan di PosProvider.transactions
      final history = posProvider.transactions;
      expect(history.length, equals(1));
      expect(history.first.id, equals(trx.id));
      expect(history.first.totalAmount, equals(27000));
      expect(history.first.amountPaid, equals(30000));
      expect(history.first.change, equals(3000));
      expect(history.first.customerName, equals('Kak Doni'));
      expect(history.first.paymentMethod, equals('cash'));

      // 4. Verifikasi lookup order
      final order = posProvider.findOrderById(trx.orderId, fallbackTx: trx);
      expect(order.id, equals(trx.orderId));
      expect(order.tableNo, equals('Meja 05'));
      expect(order.customerName, equals('Kak Doni'));
      expect(order.items.length, equals(2));
    });

    test('Fallback lookup aman jika orderId tidak ditemukan', () {
      final fakeTx = TransactionModel(
        id: 'trx_orphan_123',
        orderId: 'ord_deleted_456',
        shiftId: 'shift_test',
        cashierId: 'cashier_1',
        cashierName: 'Siti',
        paymentMethod: 'qris',
        totalAmount: 50000,
        amountPaid: 50000,
        customerName: 'Tamu VIP',
      );

      final fallbackOrder = posProvider.findOrderById(fakeTx.orderId, fallbackTx: fakeTx);
      expect(fallbackOrder.id, equals('ord_deleted_456'));
      expect(fallbackOrder.customerName, equals('Tamu VIP'));
      expect(fallbackOrder.paidAmount, equals(50000));
      expect(fallbackOrder.items.isNotEmpty, isTrue);
      expect(fallbackOrder.items.first.price, equals(50000));
    });

    // ========================================================================
    // PENGUJIAN KATEGORI 1: SIKLUS MEJA, KDS, & PROTEKSI KERANJANG
    // ========================================================================

    test('1.1 Anti-Duplikasi Meja: Menyimpan open tab pada meja yang sudah ada akan menggabungkan item', () async {
      // 1. Buat open tab awal untuk Meja 02
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p1')); // Nasi Goreng Spesial (22000)
      posProvider.setTableNo('Meja 02');
      posProvider.setCustomerName('Pak Hendra');
      final firstTab = await posProvider.saveAsOpenTab(shiftId: 'shift_1');

      expect(posProvider.openOrders.length, equals(1));
      expect(firstTab.items.length, equals(1));
      expect(firstTab.items.first.qty, equals(1));

      // 2. Kasir input lagi menu baru di POS untuk Meja 02 tanpa mode edit tab
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p2')); // Es Teh Manis (5000)
      posProvider.setTableNo('Meja 02'); // Meja yang sama
      final mergedTab = await posProvider.saveAsOpenTab(shiftId: 'shift_1');

      // 3. Pastikan tetap HANYA ADA 1 OPEN TAB untuk Meja 02, bukan 2 tab terpisah
      expect(posProvider.openOrders.length, equals(1));
      expect(mergedTab.id, equals(firstTab.id));
      expect(mergedTab.items.length, equals(2));
      expect(mergedTab.total, equals(27000));
    });

    test('1.2 Sinkronisasi KDS Ronde 2: Penambahan item mereset kitchenStatus ke pending dan membersihkan checklist', () async {
      // 1. Buat tab meja yang sudah selesai disajikan oleh koki di ronde 1
      final initialOrder = await posProvider.createOpenTabDirectly(
        shiftId: 'shift_1',
        tableNo: 'Meja 04',
        customerName: 'Ibu Rina',
        items: [
          OrderItem(productId: 'p1', name: 'Nasi Goreng Spesial', price: 22000, qty: 1),
        ],
      );
      // Simulasikan koki telah memasak dan menyajikan
      await posProvider.updateKitchenStatus(initialOrder.id, 'served');
      await posProvider.toggleKitchenItemCompleted(initialOrder.id, 'Nasi Goreng Spesial');

      var current = posProvider.openOrders.firstWhere((o) => o.id == initialOrder.id);
      expect(current.kitchenStatus, equals('served'));
      expect(current.completedItemIds.isNotEmpty, isTrue);

      // 2. Tamu memesan ronde 2 (add-on item)
      final round2 = await posProvider.appendItemsToOpenTab(
        tableNo: 'Meja 04',
        newItems: [
          OrderItem(productId: 'p2', name: 'Es Teh Manis', price: 5000, qty: 2),
        ],
      );

      // 3. Status harus ter-reset ke pending agar tiket KDS muncul kembali di tab Dapur
      expect(round2, isNotNull);
      expect(round2!.kitchenStatus, equals('pending'));
      expect(round2.cookingStartedAt, isNull);
      expect(round2.completedItemIds.isEmpty, isTrue);
    });

    test('1.3 Proteksi Keranjang Kasir POS: completeOrderDirectly tidak menghapus isi keranjang aktif', () async {
      // 1. Kasir di POS sedang melayani pelanggan walk-in (isi keranjang aktif)
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p1'));
      posProvider.setCustomerName('Pelanggan Antrean');
      expect(posProvider.cartItems.length, equals(1));
      expect(posProvider.cartSubtotal, equals(22000));

      // 2. Ada pesanan gantung meja lain
      final tableOrder = await posProvider.createOpenTabDirectly(
        shiftId: 'shift_1',
        tableNo: 'Meja 08',
        customerName: 'Pak Wahyu',
        items: [
          OrderItem(productId: 'p2', name: 'Es Teh Manis', price: 5000, qty: 3),
        ],
      );

      // 3. Waiter / Kasir melunasi Meja 08 langsung dari denah meja menggunakan completeOrderDirectly
      final trx = await posProvider.completeOrderDirectly(
        order: tableOrder,
        shiftId: 'shift_1',
        cashierId: 'waiter_1',
        cashierName: 'Andi (Waiter)',
        paymentMethod: 'cash',
        amountPaid: 15000,
        change: 0,
      );

      expect(trx.totalAmount, equals(15000));

      // 4. VERIFIKASI UTAMA: Keranjang belanja kasir aktif di POS TIDAK TERHAPUS!
      expect(posProvider.cartItems.length, equals(1));
      expect(posProvider.cartSubtotal, equals(22000));
      expect(posProvider.customerName, equals('Pelanggan Antrean'));
    });

    // ========================================================================
    // PENGUJIAN KATEGORI 2: METODE BAYAR, CETAK STRUK, & PELUNASAN KASBON
    // ========================================================================

    test('2.1 Pembayaran Kombinasi: DP QRIS + Pelunasan Kasir terpecah akurat tanpa distorsi kas laci', () async {
      // 1. Meja pesan mandiri dan sudah DP via QRIS 20.000, total tagihan 50.000
      final comboOrder = OrderModel(
        id: 'ord_combo_1',
        shiftId: 'shift_1',
        tableNo: 'Meja 10',
        customerName: 'Bima',
        items: [
          OrderItem(productId: 'p1', name: 'Nasi Goreng Spesial', price: 25000, qty: 2), // Total 50000
        ],
        status: 'open',
        paidAmount: 20000, // DP QRIS 20.000
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final orders = storageService.getOrders();
      orders.add(comboOrder);
      await storageService.saveOrders(orders);

      // 2. Pelanggan melunasi sisa tagihan Rp 30.000 dengan Uang Tunai Rp 50.000 (Kembali Rp 20.000)
      final settlementTrx = await posProvider.completeOrderDirectly(
        order: comboOrder,
        shiftId: 'shift_1',
        cashierId: 'cashier_1',
        cashierName: 'Dewi',
        paymentMethod: 'cash',
        amountPaid: 50000,
        change: 20000,
      );

      // 3. Verifikasi: Transaksi terpecah menjadi 2 entri akurat
      final allTx = posProvider.transactions;
      final qrisTx = allTx.firstWhere((t) => t.orderId == comboOrder.id && t.paymentMethod == 'qris');
      final cashTx = allTx.firstWhere((t) => t.orderId == comboOrder.id && t.paymentMethod == 'cash');

      expect(qrisTx.totalAmount, equals(20000));
      expect(qrisTx.paymentMethod, equals('qris'));

      expect(cashTx.totalAmount, equals(30000)); // HANYA 30.000 uang kas, bukan 50.000!
      expect(cashTx.paymentMethod, equals('cash'));
      expect(settlementTrx.id, equals(cashTx.id));
    });

    test('2.2 Format Struk Thermal: Mencetak Total Tagihan asli & rincian Uang Muka QRIS', () {
      final sampleOrder = OrderModel(
        id: 'ord_print_test',
        shiftId: 'shift_1',
        tableNo: 'Meja 01',
        customerName: 'Pak Hadi',
        items: [
          OrderItem(productId: 'p1', name: 'Nasi Goreng Spesial', price: 22000, qty: 2),
        ],
        status: 'completed',
        paidAmount: 20000, // DP 20.000, total tagihan 44.000
        createdAt: DateTime.now(),
      );

      final settings = SettingsModel(storeName: 'Resto Berkah');

      // Uji Struk Plain Text
      final receiptText = PrinterReceiptService.buildTextReceipt(
        settings: settings,
        order: sampleOrder,
        receiptNo: '001',
        orderTime: DateTime.now(),
        cashierName: 'Kasir 1',
        paymentMethod: 'Tunai',
        amountPaid: 24000,
        change: 0,
      );

      expect(receiptText.contains('44.000'), isTrue); // Total belanja 44.000, BUKAN 20.000 atau 0!
      expect(receiptText.contains('Uang Muka (QRIS):'), isTrue);
      expect(receiptText.contains('Sisa Tagihan:'), isTrue);

      // Uji Struk HTML
      final html = PrinterReceiptService.buildHtmlReceipt(
        settings: settings,
        order: sampleOrder,
        receiptNo: '001',
        orderTime: DateTime.now(),
        cashierName: 'Kasir 1',
        paymentMethod: 'Tunai',
        amountPaid: 24000,
        change: 0,
      );

      expect(html.contains('44.000'), isTrue);
      expect(html.contains('Uang Muka (QRIS):'), isTrue);
      expect(html.contains('Sisa Tagihan:'), isTrue);
    });

    test('2.3 Pelunasan Kasbon: Tercatat di transaksi & AnalyticsProvider tidak double count omzet', () async {
      // 1. Simulasikan pesanan awal kasbon sebesar Rp 50.000
      final debtOrder = OrderModel(
        id: 'ord_debt_initial',
        shiftId: 'shift_1',
        tableNo: null,
        customerName: 'Pak Joko',
        items: [
          OrderItem(productId: 'p1', name: 'Nasi Goreng Spesial', price: 25000, qty: 2),
        ],
        status: 'completed',
        paidAmount: 50000,
        createdAt: DateTime.now(),
      );
      final debtTx = TransactionModel(
        id: 'trx_debt_initial',
        orderId: debtOrder.id,
        shiftId: 'shift_1',
        cashierId: 'cashier_1',
        cashierName: 'Kasir 1',
        paymentMethod: 'debt',
        totalAmount: 50000,
        amountPaid: 50000,
        customerName: 'Pak Joko',
        timestamp: DateTime.now(),
      );

      final orders = storageService.getOrders()..add(debtOrder);
      await storageService.saveOrders(orders);
      final txs = storageService.getTransactions()..add(debtTx);
      await storageService.saveTransactions(txs);

      // Cek analitik sebelum pelunasan
      final analytics = AnalyticsProvider(storageService);
      expect(analytics.summary.totalRevenue, equals(50000));
      expect(analytics.summary.debtTotal, equals(50000));
      expect(analytics.summary.cashTotal, equals(0));

      // 2. Pak Joko mencicil/melunasi kasbon sebesar Rp 30.000 secara tunai
      final repayTx = await posProvider.recordDebtRepaymentTransaction(
        customerId: 'cust_joko',
        customerName: 'Pak Joko',
        amountPaid: 30000,
        paymentMethod: 'cash',
        shiftId: 'shift_1',
        cashierId: 'cashier_1',
        cashierName: 'Kasir 1',
      );

      expect(repayTx.orderId.startsWith('ord_repay_'), isTrue);
      expect(posProvider.transactions.any((t) => t.id == repayTx.id), isTrue);

      // 3. Verifikasi Analitik: Omzet TIDAK BERTAMBAH (tetap 50.000), kas bertambah 30.000, piutang berkurang jadi 20.000
      analytics.calculateSummary();
      expect(analytics.summary.totalRevenue, equals(50000)); // TIDAK MENJADI 80.000! (Anti double-counting)
      expect(analytics.summary.cashTotal, equals(30000));
      expect(analytics.summary.debtTotal, equals(20000)); // 50.000 - 30.000 = 20.000
    });

    // ========================================================================
    // PENGUJIAN KATEGORI 4: MEJA, PINDAH MEJA & MANAJEMEN INVENTORI
    // ========================================================================

    test('4.1 Pencocokan Meja: RestaurantTable.isMatch mencegah false match antar area resto yang berbeda', () {
      // 1. Variasi penulisan meja yang sama harus cocok (MATCH)
      expect(RestaurantTable.isMatch('Meja 01', 'Meja 1'), isTrue);
      expect(RestaurantTable.isMatch('01', '1'), isTrue);
      expect(RestaurantTable.isMatch('Meja 02', '2'), isTrue);
      expect(RestaurantTable.isMatch('Table 03', 'Meja 3'), isTrue);
      expect(RestaurantTable.isMatch('VIP 1', 'VIP 01'), isTrue);
      expect(RestaurantTable.isMatch('Lesehan 02', 'Lesehan 2'), isTrue);

      // 2. Meja beda area/tipe DENGAN NOMOR SAMA TIDAK BOLEH COCOK (PREVENT FALSE MATCH)
      expect(RestaurantTable.isMatch('VIP 1', 'Meja 01'), isFalse);
      expect(RestaurantTable.isMatch('VIP 1', '1'), isFalse);
      expect(RestaurantTable.isMatch('Lesehan 2', 'Outdoor 2'), isFalse);
      expect(RestaurantTable.isMatch('Meja 03', 'Lesehan 3'), isFalse);
      expect(RestaurantTable.isMatch('VIP 2', 'Lesehan 2'), isFalse);
    });

    test('4.2 Validasi Pindah Meja: Menolak perpindahan jika meja tujuan sudah terisi', () async {
      // 1. Meja 01 dan Meja 02 sama-sama terisi
      await posProvider.createOpenTabDirectly(
        shiftId: 'shift_1',
        tableNo: 'Meja 01',
        customerName: 'Tamu Meja 1',
        items: [OrderItem(productId: 'p1', name: 'Nasi Goreng', price: 22000, qty: 1)],
      );
      await posProvider.createOpenTabDirectly(
        shiftId: 'shift_1',
        tableNo: 'Meja 02',
        customerName: 'Tamu Meja 2',
        items: [OrderItem(productId: 'p2', name: 'Es Teh', price: 5000, qty: 1)],
      );

      // 2. Tamu Meja 01 minta pindah ke Meja 02 yang sedang terisi -> HARUS DITOLAK!
      final moveFail = await posProvider.moveTable('Meja 01', 'Meja 02');
      expect(moveFail, isFalse);

      // Pastikan Meja 01 tetap berada di Meja 01
      final order1 = posProvider.openOrders.firstWhere((o) => o.customerName == 'Tamu Meja 1');
      expect(order1.tableNo, equals('Meja 01'));

      // 3. Pindah ke Meja 09 yang kosong -> HARUS BERHASIL!
      final moveSuccess = await posProvider.moveTable('Meja 01', 'Meja 09');
      expect(moveSuccess, isTrue);

      final order1Moved = posProvider.openOrders.firstWhere((o) => o.customerName == 'Tamu Meja 1');
      expect(order1Moved.tableNo, equals('Meja 09'));
    });

    test('4.3 Proteksi Overselling: Stok berkurang saat open tab dibuka & pulih saat tab dibatalkan', () async {
      final initialStock = posProvider.products.firstWhere((p) => p.id == 'p1').stock; // 50

      // 1. Meja 03 memesan 5 porsi Nasi Goreng Spesial via Open Tab
      posProvider.addToCart(posProvider.products.firstWhere((p) => p.id == 'p1'));
      posProvider.updateItemQty(0, 4); // Total qty = 5
      posProvider.setTableNo('Meja 03');
      posProvider.setCustomerName('Keluarga Besar');

      final openTab = await posProvider.saveAsOpenTab(shiftId: 'shift_1');

      // 2. Verifikasi: Stok di katalog produk LANGSUNG BERKURANG 5 (tidak menunggu checkout)
      final stockAfterOrder = posProvider.products.firstWhere((p) => p.id == 'p1').stock;
      expect(stockAfterOrder, equals(initialStock - 5)); // 45 porsi tersisa

      // 3. Meja menambah 2 porsi lagi di Ronde 2
      await posProvider.appendItemsToOpenTab(
        tableNo: 'Meja 03',
        newItems: [OrderItem(productId: 'p1', name: 'Nasi Goreng Spesial', price: 22000, qty: 2)],
      );

      final stockAfterRound2 = posProvider.products.firstWhere((p) => p.id == 'p1').stock;
      expect(stockAfterRound2, equals(initialStock - 7)); // 43 porsi tersisa

      // 4. Pelanggan membatalkan seluruh pesanan sebelum dimasak
      await posProvider.cancelOpenOrder(openTab.id);

      // 5. Verifikasi: Seluruh 7 porsi stok dikembalikan utuh ke katalog
      final stockAfterCancel = posProvider.products.firstWhere((p) => p.id == 'p1').stock;
      expect(stockAfterCancel, equals(initialStock)); // Kembali utuh 50 porsi!
    });
  });
}
