import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/models/sales_analytics_model.dart';
import 'package:mini_resto_pos/models/transaction_model.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/services/whatsapp_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mini_resto_pos/services/csv_export_service.dart';
import 'package:mini_resto_pos/providers/analytics_provider.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID', null);
  });

  group('Sales Analytics Model & Calculation Tests', () {
    test('Kalkulasi SalesSummary menghitung Laba Kotor dan Margin dengan presisi', () {
      final now = DateTime.now();
      final summary = SalesSummary(
        startDate: now,
        endDate: now,
        totalRevenue: 1000000,
        totalDiscount: 50000,
        netRevenue: 950000,
        totalCogs: 400000,
        grossProfit: 550000,
        profitMargin: (550000 / 950000) * 100.0,
        transactionCount: 10,
        averageOrderValue: 95000.0,
        cashTotal: 500000,
        qrisTotal: 400000,
        debtTotal: 100000,
        topSellingItems: [],
      );

      expect(summary.netRevenue, equals(950000));
      expect(summary.grossProfit, equals(550000));
      expect(summary.profitMargin, closeTo(57.89, 0.01));
      expect(summary.averageOrderValue, equals(95000.0));
      expect(summary.cashTotal + summary.qrisTotal + summary.debtTotal, equals(1000000));
    });

    test('ItemSalesRank menghitung laba dan margin per item dengan benar', () {
      final item = ItemSalesRank(
        productId: 'm1',
        name: 'Nasi Goreng Spesial',
        category: 'Makanan Utama',
        qtySold: 20,
        totalRevenue: 560000, // 20 x 28.000
        totalCogs: 280000,    // 20 x 14.000
        totalProfit: 280000,
        profitMargin: 50.0,
      );

      expect(item.totalProfit, equals(280000));
      expect(item.profitMargin, equals(50.0));
    });
  });

  group('AnalyticsProvider Integration Tests', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper();
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
      await dbHelper.clearAllData();
      storageService = StorageService(prefs, dbHelper);

      // Setup data produk contoh dengan modal HPP dan harga jual
      final products = [
        ProductModel(
          id: 'prod_1',
          name: 'Nasi Goreng Spesial',
          categoryId: 'cat_makanan',
          buyPrice: 12000,
          sellPrice: 28000,
          stock: 100,
        ),
        ProductModel(
          id: 'prod_2',
          name: 'Es Teh Manis',
          categoryId: 'cat_minuman',
          buyPrice: 2000,
          sellPrice: 6000,
          stock: 200,
        ),
      ];
      await storageService.saveProducts(products);

      // Setup 2 order contoh
      final now = DateTime.now();
      final order1 = OrderModel(
        id: 'ord_1',
        shiftId: 'shift_1',
        tableNo: 'Meja 01',
        customerName: 'Budi',
        items: [
          OrderItem(productId: 'prod_1', name: 'Nasi Goreng Spesial', price: 28000, qty: 2), // 56.000 (cogs: 24.000)
          OrderItem(productId: 'prod_2', name: 'Es Teh Manis', price: 6000, qty: 2),        // 12.000 (cogs: 4.000)
        ],
        createdAt: now,
      );

      final order2 = OrderModel(
        id: 'ord_2',
        shiftId: 'shift_1',
        tableNo: 'Meja 02',
        customerName: 'Siti',
        items: [
          OrderItem(productId: 'prod_1', name: 'Nasi Goreng Spesial', price: 28000, qty: 1), // 28.000 (cogs: 12.000)
        ],
        createdAt: now,
      );
      await storageService.saveOrders([order1, order2]);

      // Setup 2 transaksi contoh (1 cash, 1 qris)
      final tx1 = TransactionModel(
        id: 'tx_1',
        orderId: 'ord_1',
        shiftId: 'shift_1',
        cashierId: 'user_budi',
        cashierName: 'Budi',
        paymentMethod: 'cash',
        totalAmount: 68000,
        amountPaid: 70000,
        change: 2000,
        timestamp: now,
      );

      final tx2 = TransactionModel(
        id: 'tx_2',
        orderId: 'ord_2',
        shiftId: 'shift_1',
        cashierId: 'user_budi',
        cashierName: 'Budi',
        paymentMethod: 'qris',
        totalAmount: 28000,
        amountPaid: 28000,
        change: 0,
        timestamp: now,
      );
      await storageService.saveTransactions([tx1, tx2]);

      // Settings resto
      final settings = SettingsModel(
        storeName: 'Resto Digital',
        phoneWA: '081234567890',
      );
      await storageService.saveSettings(settings);
    });

    test('AnalyticsProvider mengagregasi omzet, total HPP, dan laba kotor hari ini secara akurat', () {
      final provider = AnalyticsProvider(storageService);
      final summary = provider.summary;

      expect(summary.transactionCount, equals(2));
      expect(summary.totalRevenue, equals(96000)); // 68.000 + 28.000
      expect(summary.netRevenue, equals(96000));
      expect(summary.cashTotal, equals(68000));
      expect(summary.qrisTotal, equals(28000));
      expect(summary.debtTotal, equals(0));

      // COGS:
      // Ord1: (12.000 x 2) + (2.000 x 2) = 28.000
      // Ord2: (12.000 x 1) = 12.000
      // Total COGS = 40.000
      expect(summary.totalCogs, equals(40000));

      // Gross Profit: 96.000 - 40.000 = 56.000
      expect(summary.grossProfit, equals(56000));

      // Margin: (56.000 / 96.000) * 100 = 58.333%
      expect(summary.profitMargin, closeTo(58.33, 0.05));

      // Average Order Value: 96.000 / 2 = 48.000
      expect(summary.averageOrderValue, equals(48000.0));

      // Leaderboard Menu:
      // Nasi Goreng Spesial: 3 porsi (84.000 omzet, 36.000 modal, 48.000 profit)
      // Es Teh Manis: 2 porsi (12.000 omzet, 4.000 modal, 8.000 profit)
      expect(summary.topSellingItems.length, equals(2));
      expect(summary.topSellingItems[0].name, equals('Nasi Goreng Spesial'));
      expect(summary.topSellingItems[0].qtySold, equals(3));
      expect(summary.topSellingItems[0].totalRevenue, equals(84000));
      expect(summary.topSellingItems[0].totalProfit, equals(48000));

      expect(summary.topSellingItems[1].name, equals('Es Teh Manis'));
      expect(summary.topSellingItems[1].qtySold, equals(2));
    });
  });

  group('WhatsApp EOD Report & CSV Export Tests', () {
    test('WhatsappService.formatEodReportMessage menghasilkan pesan laporan formal yang lengkap', () {
      final now = DateTime(2026, 9, 12, 22, 0);
      final summary = SalesSummary(
        startDate: DateTime(2026, 9, 12),
        endDate: now,
        totalRevenue: 2450000,
        totalDiscount: 50000,
        netRevenue: 2400000,
        totalCogs: 1150000,
        grossProfit: 1250000,
        profitMargin: 52.0,
        transactionCount: 48,
        averageOrderValue: 50000.0,
        cashTotal: 1100000,
        qrisTotal: 1150000,
        debtTotal: 150000,
        topSellingItems: [
          ItemSalesRank(
            productId: 'm1',
            name: 'Nasi Goreng Spesial Resto',
            category: 'Makanan',
            qtySold: 32,
            totalRevenue: 896000,
            totalCogs: 448000,
            totalProfit: 448000,
            profitMargin: 50.0,
          ),
        ],
      );

      final message = WhatsappService.formatEodReportMessage(
        storeName: 'Resto Digital',
        summary: summary,
        cashierName: 'Siti Aminah',
        closingTime: now,
        note: 'Semua pesanan selesai dengan lancar.',
      );

      expect(message, contains('LAPORAN TUTUP KASIR (END OF DAY)'));
      expect(message, contains('Resto Digital'));
      expect(message, contains('Siti Aminah'));
      expect(message, contains('48 Transaksi'));
      expect(message, contains('Rp 2.400.000'));
      expect(message, contains('Rp 1.100.000'));
      expect(message, contains('Nasi Goreng Spesial Resto (32 porsi)'));
      expect(message, contains('Semua pesanan selesai dengan lancar.'));
    });

    test('CsvExportService menghasilkan format CSV berstandar RFC 4180', () {
      final now = DateTime.now();
      final products = [
        ProductModel(id: 'p1', name: 'Kopi Susu, Gula Aren', categoryId: 'cat_minum', buyPrice: 5000, sellPrice: 15000),
      ];
      final orders = [
        OrderModel(
          id: 'o1',
          shiftId: 's1',
          tableNo: 'Meja "VIP"',
          items: [OrderItem(productId: 'p1', name: 'Kopi Susu, Gula Aren', price: 15000, qty: 2)],
        ),
      ];
      final txs = [
        TransactionModel(
          id: 'tx1',
          orderId: 'o1',
          shiftId: 's1',
          cashierId: 'c1',
          cashierName: 'Budi',
          paymentMethod: 'cash',
          totalAmount: 30000,
          amountPaid: 30000,
          timestamp: now,
        ),
      ];

      final csv = CsvExportService.generateTransactionsCsv(
        transactions: txs,
        orders: orders,
        products: products,
      );

      // Harus meng-escape tanda koma dan tanda petik
      expect(csv, contains('"Kopi Susu, Gula Aren"'));
      expect(csv, contains('"Meja ""VIP"""'));
      expect(csv, contains('30000'));
      expect(csv, contains('ID Transaksi,Waktu,Kasir'));
    });
  });
}
