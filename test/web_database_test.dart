import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/models/category_model.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/models/transaction_model.dart';
import 'package:mini_resto_pos/models/shift_model.dart';
import 'package:mini_resto_pos/models/cash_movement_model.dart';
import 'package:mini_resto_pos/models/customer_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web Storage Serialization & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Serialisasi Kategori dan Produk ke JSON SharedPreferences Web', () async {
      final prefs = await SharedPreferences.getInstance();

      final categories = [
        CategoryModel(id: 'cat_web_1', name: 'Makanan Web', sortOrder: 1, iconName: 'restaurant'),
        CategoryModel(id: 'cat_web_2', name: 'Minuman Web', sortOrder: 2, iconName: 'local_drink'),
      ];

      final encodedCats = jsonEncode(categories.map((c) => c.toMap()).toList());
      await prefs.setString('web_db_categories', encodedCats);

      final raw = prefs.getString('web_db_categories');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List<dynamic>;
      final parsedCats = decoded
          .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(parsedCats.length, 2);
      expect(parsedCats[0].name, 'Makanan Web');
      expect(parsedCats[1].name, 'Minuman Web');

      final product = ProductModel(
        id: 'p_web_1',
        name: 'Mie Goreng Spesial Web',
        categoryId: 'cat_web_1',
        buyPrice: 10000,
        sellPrice: 22000,
        stock: 50,
        trackStock: true,
        unit: 'Porsi',
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
      );

      final encodedProds = jsonEncode([product.toMap()]);
      await prefs.setString('web_db_products', encodedProds);

      final rawProd = prefs.getString('web_db_products');
      expect(rawProd, isNotNull);
      final decodedProd = jsonDecode(rawProd!) as List<dynamic>;
      final parsedProds = decodedProd
          .map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(parsedProds.length, 1);
      expect(parsedProds[0].name, 'Mie Goreng Spesial Web');
      expect(parsedProds[0].sellPrice, 22000);
      expect(parsedProds[0].trackStock, isTrue);
    });

    test('Serialisasi Pesanan Meja, Transaksi Kasir, dan Shift di Web', () async {
      final prefs = await SharedPreferences.getInstance();

      final order = OrderModel(
        id: 'ord_web_001',
        shiftId: 'shift_web_1',
        tableNo: 'Meja 05',
        customerName: 'Ahmad Fauzi',
        items: [
          OrderItem(productId: 'p_web_1', name: 'Mie Goreng Spesial', price: 22000, qty: 2),
        ],
        status: 'open',
      );

      final encodedOrders = jsonEncode([order.toMap()]);
      await prefs.setString('web_db_orders', encodedOrders);

      final rawOrders = prefs.getString('web_db_orders');
      expect(rawOrders, isNotNull);
      final decodedOrders = jsonDecode(rawOrders!) as List<dynamic>;
      final parsedOrders = decodedOrders
          .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(parsedOrders.length, 1);
      expect(parsedOrders[0].tableNo, 'Meja 05');
      expect(parsedOrders[0].total, 44000);
      expect(parsedOrders[0].items.length, 1);
      expect(parsedOrders[0].items[0].qty, 2);

      // Transaksi
      final tx = TransactionModel(
        id: 'tx_web_001',
        orderId: 'ord_web_001',
        shiftId: 'shift_web_1',
        cashierId: 'cashier_budi',
        cashierName: 'Budi Santoso',
        paymentMethod: 'cash',
        totalAmount: 44000,
        amountPaid: 50000,
        change: 6000,
        timestamp: DateTime.now(),
      );

      final encodedTxs = jsonEncode([tx.toMap()]);
      await prefs.setString('web_db_transactions', encodedTxs);

      final rawTxs = prefs.getString('web_db_transactions');
      expect(rawTxs, isNotNull);
      final decodedTxs = jsonDecode(rawTxs!) as List<dynamic>;
      final parsedTxs = decodedTxs
          .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(parsedTxs.length, 1);
      expect(parsedTxs[0].change, 6000);
      expect(parsedTxs[0].cashierName, 'Budi Santoso');

      // Shift & Arus Kas
      final shift = ShiftModel(
        id: 'shift_web_1',
        userId: 'cashier_budi',
        cashierName: 'Budi Santoso',
        startedAt: DateTime.now(),
        initialCash: 100000,
        status: 'open',
      );
      final encodedShifts = jsonEncode([shift.toMap()]);
      await prefs.setString('web_db_shifts', encodedShifts);

      final cashMovement = CashMovementModel(
        id: 'cm_web_1',
        shiftId: 'shift_web_1',
        userId: 'cashier_budi',
        cashierName: 'Budi Santoso',
        type: 'in',
        amount: 50000,
        notes: 'Modal kembalian tambahan',
        timestamp: DateTime.now(),
      );
      final encodedCms = jsonEncode([cashMovement.toMap()]);
      await prefs.setString('web_db_cash_movements', encodedCms);

      // Pelanggan Kasbon
      final customer = CustomerModel(
        id: 'cust_web_1',
        name: 'Pak RT Bambang',
        phoneWA: '081234567890',
        totalDebt: 25000,
      );
      final encodedCusts = jsonEncode([customer.toMap()]);
      await prefs.setString('web_db_customers', encodedCusts);

      expect(prefs.getString('web_db_shifts'), isNotNull);
      expect(prefs.getString('web_db_cash_movements'), isNotNull);
      expect(prefs.getString('web_db_customers'), isNotNull);
    });
  });
}
