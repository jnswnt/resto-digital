import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../services/storage_service.dart';

/// Provider Transaksi POS Resto.
/// Mengelola keranjang belanja, filter kategori, pencarian menu,
/// diskon/voucher, pajak PB1, service charge,
/// transaksi langsung (Pay First), pesanan gantung/meja (Open Tab), dan Split Bill.
class PosProvider with ChangeNotifier {
  final StorageService _storageService;
  final _uuid = const Uuid();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';

  // Keranjang belanja aktif
  final List<OrderItem> _cartItems = [];
  String? _selectedTableNo;
  String _customerName = 'Pelanggan';
  OrderModel? _activeEditingTab;

  // State Diskon Transaksi Keranjang Kasir
  int _cartDiscountAmount = 0;
  double _cartDiscountPercent = 0.0;

  PosProvider(this._storageService) {
    loadData();
  }

  List<CategoryModel> get categories => _categories;
  List<ProductModel> get products => List.unmodifiable(_products);
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  List<OrderItem> get cartItems => List.unmodifiable(_cartItems);
  String? get selectedTableNo => _selectedTableNo;
  String get customerName => _customerName;
  OrderModel? get activeEditingTab => _activeEditingTab;

  int get cartDiscountAmount => _cartDiscountAmount;
  double get cartDiscountPercent => _cartDiscountPercent;

  int get cartSubtotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  int get cartTotalItems => _cartItems.fold(0, (sum, item) => sum + item.qty);
  bool get isCartEmpty => _cartItems.isEmpty;

  /// Nilai subtotal keranjang setelah dipotong diskon
  int get cartSubtotalAfterDiscount =>
      (cartSubtotal - _cartDiscountAmount).clamp(0, 999999999);

  /// Mengatur diskon keranjang kasir dalam persentase (%)
  void setDiscountPercent(double percent) {
    _cartDiscountPercent = percent.clamp(0.0, 100.0);
    _cartDiscountAmount = ((cartSubtotal * _cartDiscountPercent) / 100).round();
    notifyListeners();
  }

  /// Mengatur diskon keranjang kasir dalam nominal rupiah (Rp)
  void setDiscountAmount(int amount) {
    _cartDiscountAmount = amount.clamp(0, cartSubtotal);
    _cartDiscountPercent = cartSubtotal > 0
        ? ((_cartDiscountAmount / cartSubtotal) * 100)
        : 0.0;
    notifyListeners();
  }

  /// Menghapus diskon yang sedang aktif pada keranjang kasir
  void clearDiscount() {
    _cartDiscountAmount = 0;
    _cartDiscountPercent = 0.0;
    notifyListeners();
  }

  /// Menghitung Biaya Layanan (Service Charge) berdasarkan SettingsModel
  int calculateServiceCharge(SettingsModel settings, [int? customBaseSubtotal]) {
    if (!settings.enableServiceCharge) return 0;
    final base = customBaseSubtotal ?? cartSubtotalAfterDiscount;
    return ((base * settings.serviceChargePercentage) / 100).round();
  }

  /// Menghitung Pajak Restoran (PB1) berdasarkan SettingsModel
  int calculateTax(
    SettingsModel settings, [
    int? customBaseSubtotal,
    int? customServiceCharge,
  ]) {
    if (!settings.enableTax) return 0;
    final base = customBaseSubtotal ?? cartSubtotalAfterDiscount;
    final svc = customServiceCharge ?? calculateServiceCharge(settings, base);
    return (((base + svc) * settings.taxPercentage) / 100).round();
  }

  /// Menghitung Total Akhir Tagihan Keranjang (Subtotal - Diskon + Service Charge + PB1)
  int calculateCartGrandTotal(SettingsModel settings) {
    final subAfterDisc = cartSubtotalAfterDiscount;
    final svc = calculateServiceCharge(settings, subAfterDisc);
    final tax = calculateTax(settings, subAfterDisc, svc);
    return (subAfterDisc + svc + tax).clamp(0, 999999999);
  }

  /// Memuat produk dan kategori dari penyimpanan lokal
  void loadData() {
    _categories = _storageService.getCategories();
    _products = _storageService.getProducts();
    notifyListeners();
  }

  /// Memuat ulang data langsung dari database ke cache lalu memperbarui UI
  Future<void> refreshData() async {
    await _storageService.reloadFromDatabase();
    loadData();
  }

  /// Daftar produk yang sudah difilter berdasarkan kategori dan kata kunci pencarian
  List<ProductModel> get filteredProducts {
    return _products.where((prod) {
      final matchesCategory =
          _selectedCategoryId == 'all' || prod.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty ||
          prod.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Daftar pesanan yang sedang gantung / open tab
  List<OrderModel> get openOrders {
    return _storageService.getOrders().where((o) => o.status == 'open').toList();
  }

  /// Seluruh pesanan aktif yang perlu dipantau oleh Dapur (KDS).
  /// Menampilkan pesanan yang belum disajikan (kitchenStatus != 'served'),
  /// baik yang berstatus Open Tab maupun pesanan yang langsung lunas di kasir (Pay-First) dari 24 jam terakhir.
  /// Transaksi finansial non-dapur (seperti pelunasan kasbon) diabaikan secara otomatis.
  List<OrderModel> get kitchenOrders {
    final now = DateTime.now();
    final list = _storageService.getOrders().where((o) {
      if (o.status == 'cancelled' || o.kitchenStatus == 'served') return false;
      // Transaksi administratif pelunasan kasbon/piutang bukan tiket masakan dapur
      if (o.id.startsWith('ord_repay_') || o.items.any((i) => i.productId == 'item_repay')) {
        return false;
      }
      if (o.status == 'open') return true;
      if (o.status == 'completed') {
        return now.difference(o.createdAt).inHours < 24;
      }
      return false;
    }).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Seluruh data riwayat transaksi pembayaran resto terurut dari yang terbaru
  List<TransactionModel> get transactions {
    final list = _storageService.getTransactions();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Seluruh arsip pesanan resto untuk referensi rincian item nota struk
  List<OrderModel> get allOrders {
    return _storageService.getOrders();
  }

  /// Mencari data pesanan berdasarkan orderId dengan fallback aman jika data pesanan tidak ditemukan
  OrderModel findOrderById(String orderId, {TransactionModel? fallbackTx}) {
    final orders = _storageService.getOrders();
    final match = orders.where((o) => o.id == orderId);
    if (match.isNotEmpty) return match.first;

    if (fallbackTx != null) {
      return OrderModel(
        id: fallbackTx.orderId.isNotEmpty ? fallbackTx.orderId : fallbackTx.id,
        shiftId: fallbackTx.shiftId,
        tableNo: null,
        customerName: fallbackTx.customerName ?? 'Pelanggan',
        items: [
          OrderItem(
            productId: 'item_trx',
            name: 'Item Transaksi #${fallbackTx.id}',
            price: fallbackTx.totalAmount,
            qty: 1,
          ),
        ],
        status: 'completed',
        paidAmount: fallbackTx.totalAmount,
        kitchenStatus: 'served',
        createdAt: fallbackTx.timestamp,
        completedAt: fallbackTx.timestamp,
      );
    }

    return OrderModel(
      id: orderId,
      shiftId: '',
      items: [],
      status: 'completed',
      paidAmount: 0,
      createdAt: DateTime.now(),
    );
  }

  void selectCategory(String catId) {
    _selectedCategoryId = catId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTableNo(String? tableNo) {
    _selectedTableNo = tableNo;
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name.isEmpty ? 'Pelanggan' : name;
    notifyListeners();
  }

  /// Menambahkan item produk ke keranjang belanja
  void addToCart(ProductModel product, {String notes = ''}) {
    final index = _cartItems.indexWhere(
      (item) => item.productId == product.id && item.notes == notes,
    );

    if (index >= 0) {
      _cartItems[index].qty++;
    } else {
      _cartItems.add(
        OrderItem(
          productId: product.id,
          name: product.name,
          price: product.sellPrice,
          qty: 1,
          notes: notes,
        ),
      );
    }
    notifyListeners();
  }

  /// Mengurangi jumlah atau menghapus item dari keranjang
  void updateItemQty(int index, int delta) {
    if (index < 0 || index >= _cartItems.length) return;
    _cartItems[index].qty += delta;
    if (_cartItems[index].qty <= 0) {
      _cartItems.removeAt(index);
    }
    notifyListeners();
  }

  /// Menghapus item dari keranjang
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  /// Memperbarui catatan khusus pada item (contoh: "Gula sedikit, es batu banyak")
  void updateItemNotes(int index, String notes) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index].notes = notes;
      notifyListeners();
    }
  }

  /// Mengosongkan keranjang belanja kasir dan mereset diskon
  void clearCart() {
    _cartItems.clear();
    _selectedTableNo = null;
    _customerName = 'Pelanggan';
    _activeEditingTab = null;
    _cartDiscountAmount = 0;
    _cartDiscountPercent = 0.0;
    notifyListeners();
  }

  /// Menyimpan keranjang sebagai Pesanan Gantung / Meja (Open Tab)
  /// Dilengkapi perlindungan anti-duplikasi meja, sinkronisasi KDS ronde baru,
  /// pencatatan diskon/pajak, dan deduksi stok dini untuk mencegah overselling.
  Future<OrderModel> saveAsOpenTab({
    required String shiftId,
    int? discountAmount,
    double? discountPercent,
    int? taxAmount,
    int? serviceChargeAmount,
  }) async {
    final orders = _storageService.getOrders();
    final disc = discountAmount ?? _cartDiscountAmount;
    final discPct = discountPercent ?? _cartDiscountPercent;
    final tax = taxAmount ?? 0;
    final svc = serviceChargeAmount ?? 0;

    OrderModel orderToSave;
    if (_activeEditingTab != null) {
      // Memperbarui tab yang sudah ada (reset status KDS ke pending agar koki memproses ronde berikutnya)
      final index = orders.indexWhere((o) => o.id == _activeEditingTab!.id);
      orderToSave = _activeEditingTab!.copyWith(
        tableNo: _selectedTableNo,
        customerName: _customerName,
        items: List.from(_cartItems),
        status: 'open',
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        kitchenStatus: 'pending',
        cookingStartedAt: null,
        completedItemIds: const [],
      );
      if (index >= 0) {
        orders[index] = orderToSave;
      }

      // Rekonsiliasi selisih stok jika ada penambahan/pengurangan item saat edit tab
      for (final newItem in _cartItems) {
        final oldQty = _activeEditingTab!.items
            .where((i) => i.productId == newItem.productId)
            .fold<int>(0, (sum, i) => sum + i.qty);
        final diff = newItem.qty - oldQty;
        if (diff > 0) {
          await _deductStock([newItem.copyWith(qty: diff)]);
        } else if (diff < 0) {
          await _restoreStock([newItem.copyWith(qty: -diff)]);
        }
      }
      for (final oldItem in _activeEditingTab!.items) {
        final stillExists = _cartItems.any((i) => i.productId == oldItem.productId);
        if (!stillExists) {
          await _restoreStock([oldItem]);
        }
      }
    } else {
      // Cek apakah meja ini sudah memiliki Open Tab aktif (Anti-Duplikasi Meja)
      final table = _selectedTableNo;
      if (table != null &&
          table.trim().isNotEmpty &&
          table.trim().toLowerCase() != 'takeaway') {
        final existingIndex = orders.indexWhere(
          (o) =>
              o.status == 'open' &&
              o.tableNo != null &&
              _normalizeTable(o.tableNo!) == _normalizeTable(table),
        );
        if (existingIndex >= 0) {
          final existingOrder = orders[existingIndex];
          final appendedOrder = await appendItemsToOpenTab(
            tableNo: table,
            newItems: List.from(_cartItems),
            customerName: _customerName != 'Pelanggan'
                ? _customerName
                : existingOrder.customerName,
          );
          clearCart();
          return appendedOrder ?? existingOrder;
        }
      }

      // Membuat open tab baru jika meja belum aktif
      orderToSave = OrderModel(
        id: 'ord_${_uuid.v4().substring(0, 8)}',
        shiftId: shiftId,
        tableNo: _selectedTableNo,
        customerName: _customerName,
        items: List.from(_cartItems),
        status: 'open',
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        kitchenStatus: 'pending',
        createdAt: DateTime.now(),
      );
      orders.add(orderToSave);

      // Kurangi stok segera saat pesanan meja dibuka untuk mencegah overselling
      await _deductStock(orderToSave.items);
    }

    await _storageService.saveOrders(orders);
    clearCart();
    notifyListeners();
    return orderToSave;
  }

  /// Helper normalisasi nama meja (menghilangkan spasi ganda, case-insensitive)
  String _normalizeTable(String table) {
    return table.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Helper publik normalisasi nama meja
  String normalizeTable(String table) => _normalizeTable(table);

  /// Membuat Open Tab baru langsung dari pesanan online meja tanpa menyentuh atau menghapus keranjang kasir aktif
  Future<OrderModel> createOpenTabDirectly({
    required String shiftId,
    required String tableNo,
    required String customerName,
    required List<OrderItem> items,
    String? onlineOrderId,
    int paidAmount = 0,
  }) async {
    final orders = _storageService.getOrders();
    final newOrder = OrderModel(
      id: 'ord_${_uuid.v4().substring(0, 8)}',
      shiftId: shiftId,
      tableNo: tableNo,
      customerName: customerName,
      items: List.from(items),
      status: 'open',
      paidAmount: paidAmount,
      onlineOrderId: onlineOrderId,
      createdAt: DateTime.now(),
    );

    orders.add(newOrder);
    await _storageService.saveOrders(orders);

    // Deduksi stok bahan / produk segera saat pesanan online meja dibuat
    await _deductStock(newOrder.items);

    notifyListeners();
    return newOrder;
  }

  /// Menggabungkan item pesanan tambahan (Round 2 / Add-on) ke Open Tab meja yang sudah aktif
  Future<OrderModel?> appendItemsToOpenTab({
    required String tableNo,
    required List<OrderItem> newItems,
    String? customerName,
    int additionalPaidAmount = 0,
    String? onlineOrderId,
  }) async {
    final orders = _storageService.getOrders();
    final targetNorm = _normalizeTable(tableNo);

    final index = orders.indexWhere(
      (o) => o.status == 'open' && (o.tableNo != null && _normalizeTable(o.tableNo!) == targetNorm),
    );

    if (index < 0) {
      return null;
    }

    final existingOrder = orders[index];
    final updatedItems = List<OrderItem>.from(existingOrder.items);

    for (final newItem in newItems) {
      final itemIndex = updatedItems.indexWhere(
        (i) => i.name.toLowerCase().trim() == newItem.name.toLowerCase().trim() &&
               i.notes.trim() == newItem.notes.trim(),
      );

      if (itemIndex >= 0) {
        final old = updatedItems[itemIndex];
        updatedItems[itemIndex] = OrderItem(
          productId: old.productId,
          name: old.name,
          price: old.price,
          qty: old.qty + newItem.qty,
          notes: old.notes,
        );
      } else {
        updatedItems.add(newItem);
      }
    }

    final updatedOrder = existingOrder.copyWith(
      customerName: (customerName != null && customerName.trim().isNotEmpty && customerName != 'Pelanggan')
          ? customerName
          : existingOrder.customerName,
      items: updatedItems,
      paidAmount: existingOrder.paidAmount + additionalPaidAmount,
      onlineOrderId: onlineOrderId ?? existingOrder.onlineOrderId,
      kitchenStatus: 'pending',
      cookingStartedAt: null,
      completedItemIds: const [],
    );

    orders[index] = updatedOrder;
    await _storageService.saveOrders(orders);

    // Deduksi stok untuk item tambahan yang baru dipesan (Round 2)
    await _deductStock(newItems);

    if (_activeEditingTab?.id == existingOrder.id) {
      loadOpenTabForEdit(updatedOrder);
    } else {
      notifyListeners();
    }

    return updatedOrder;
  }

  /// Memperbarui status pembayaran lunas pada pesanan lokal ketika pembayaran online (QRIS) berhasil diverifikasi
  Future<bool> markOnlineOrderAsPaid({
    required String onlineOrderId,
    String? tableNo,
    int? paidAmount,
  }) async {
    final orders = _storageService.getOrders();
    final targetNorm = tableNo != null && tableNo.trim().isNotEmpty
        ? _normalizeTable(tableNo)
        : null;

    final index = orders.indexWhere(
      (o) =>
          o.status == 'open' &&
          (o.onlineOrderId == onlineOrderId ||
              (targetNorm != null &&
                  o.tableNo != null &&
                  _normalizeTable(o.tableNo!) == targetNorm)),
    );

    if (index >= 0) {
      final existing = orders[index];
      final amountToAdd = paidAmount ?? existing.total;
      final newPaidAmount =
          (existing.paidAmount + amountToAdd).clamp(0, existing.total);

      orders[index] = existing.copyWith(
        paidAmount: newPaidAmount > 0 ? newPaidAmount : existing.total,
      );
      await _storageService.saveOrders(orders);

      if (_activeEditingTab?.id == existing.id) {
        _activeEditingTab = orders[index];
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Memindahkan pesanan aktif dari satu meja ke meja tujuan yang kosong
  /// Menolak perpindahan jika meja tujuan sudah terisi pesanan aktif lain
  Future<bool> moveTable(String currentTable, String newTable) async {
    final orders = _storageService.getOrders();
    final currentNorm = _normalizeTable(currentTable);
    final newNorm = _normalizeTable(newTable);

    final index = orders.indexWhere(
      (o) => o.status == 'open' && (o.tableNo != null && _normalizeTable(o.tableNo!) == currentNorm),
    );

    if (index < 0) return false;

    // Validasi meja tujuan: jika sudah terisi open tab aktif, tolak perpindahan!
    final isTargetOccupied = orders.any(
      (o) => o.status == 'open' && o.tableNo != null && _normalizeTable(o.tableNo!) == newNorm,
    );
    if (isTargetOccupied) return false;

    final existingOrder = orders[index];
    final updatedOrder = existingOrder.copyWith(tableNo: newTable);
    orders[index] = updatedOrder;
    await _storageService.saveOrders(orders);

    if (_activeEditingTab?.id == existingOrder.id) {
      _selectedTableNo = newTable;
      _activeEditingTab = updatedOrder;
    }
    notifyListeners();
    return true;
  }

  /// Memperbarui status siklus masak di dapur ('pending' -> 'cooking' -> 'ready' -> 'served')
  Future<void> updateKitchenStatus(String orderId, String newStatus) async {
    final orders = _storageService.getOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;

    DateTime? cookingStarted = orders[index].cookingStartedAt;
    if (newStatus == 'cooking' && cookingStarted == null) {
      cookingStarted = DateTime.now();
    }

    final updated = orders[index].copyWith(
      kitchenStatus: newStatus,
      cookingStartedAt: cookingStarted,
    );
    orders[index] = updated;
    await _storageService.saveOrders(orders);
    notifyListeners();
  }

  /// Menandai item di dalam tiket KOT telah selesai dimasak oleh koki (checklist strike-through)
  Future<void> toggleKitchenItemCompleted(String orderId, String itemIdentifier) async {
    final orders = _storageService.getOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;

    final current = orders[index];
    final completed = List<String>.from(current.completedItemIds);
    if (completed.contains(itemIdentifier)) {
      completed.remove(itemIdentifier);
    } else {
      completed.add(itemIdentifier);
    }

    final updated = current.copyWith(completedItemIds: completed);
    orders[index] = updated;
    await _storageService.saveOrders(orders);
    notifyListeners();
  }

  /// Memuat pesanan gantung ke dalam keranjang kasir untuk penambahan menu atau checkout
  void loadOpenTabForEdit(OrderModel order) {
    _activeEditingTab = order;
    _selectedTableNo = order.tableNo;
    _customerName = order.customerName;
    _cartDiscountAmount = order.discountAmount;
    _cartDiscountPercent = order.discountPercent;
    _cartItems.clear();
    for (final item in order.items) {
      _cartItems.add(
        OrderItem(
          productId: item.productId,
          name: item.name,
          price: item.price,
          qty: item.qty,
          notes: item.notes,
        ),
      );
    }
    notifyListeners();
  }

  /// Membatalkan pesanan gantung dan mengembalikan stok fisik
  Future<void> cancelOpenOrder(String orderId) async {
    final orders = _storageService.getOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final cancelled = orders[index];
      orders[index] = cancelled.copyWith(status: 'cancelled');
      await _storageService.saveOrders(orders);

      // Kembalikan stok bahan / produk yang tadinya dipesan
      await _restoreStock(cancelled.items);

      if (_activeEditingTab?.id == orderId) {
        clearCart();
      }
      notifyListeners();
    }
  }

  /// Menyelesaikan pembayaran transaksi dari keranjang POS kasir
  /// Mendukung pencatatan diskon transaksi, biaya layanan (service charge), pajak PB1,
  /// dan mencegah distorsi pembayaran jika terdapat DP QRIS awal & pelunasan kasir.
  Future<TransactionModel> completeCheckout({
    required String shiftId,
    required String cashierId,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    String? customerId,
    String? customerName,
    int? discountAmount,
    double? discountPercent,
    int? taxAmount,
    int? serviceChargeAmount,
  }) async {
    final orderId = _activeEditingTab?.id ?? 'ord_${_uuid.v4().substring(0, 8)}';
    final orders = _storageService.getOrders();
    final sub = cartSubtotal;
    final disc = discountAmount ?? _cartDiscountAmount;
    final discPct = discountPercent ?? _cartDiscountPercent;
    final svc = serviceChargeAmount ?? 0;
    final tax = taxAmount ?? 0;
    final totalBill = (sub - disc + svc + tax).clamp(0, 999999999);
    final initialPaid = _activeEditingTab?.paidAmount ?? 0;

    // 1. Simpan atau perbarui status order menjadi completed
    final completedOrder = OrderModel(
      id: orderId,
      shiftId: shiftId,
      tableNo: _selectedTableNo,
      customerName: customerName ?? _customerName,
      items: List.from(_cartItems),
      status: 'completed',
      discountAmount: disc,
      discountPercent: discPct,
      taxAmount: tax,
      serviceChargeAmount: svc,
      paidAmount: totalBill,
      onlineOrderId: _activeEditingTab?.onlineOrderId,
      createdAt: _activeEditingTab?.createdAt ?? DateTime.now(),
      completedAt: DateTime.now(),
      kitchenStatus: _activeEditingTab?.kitchenStatus ?? 'pending',
      cookingStartedAt: _activeEditingTab?.cookingStartedAt,
      completedItemIds: List.from(_activeEditingTab?.completedItemIds ?? const []),
    );

    final orderIndex = orders.indexWhere((o) => o.id == orderId);
    if (orderIndex >= 0) {
      orders[orderIndex] = completedOrder;
    } else {
      orders.add(completedOrder);
    }
    await _storageService.saveOrders(orders);

    // 2. Buat rekaman transaksi pembayaran (tangani kombinasi DP QRIS + Pelunasan Kasir)
    final transactions = _storageService.getTransactions();
    TransactionModel primaryTrx;

    if (initialPaid > 0 && initialPaid < totalBill) {
      // Pembayaran kombinasi: DP QRIS + Pelunasan Kasir
      final dpTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: orderId,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: 'Self-Order (QRIS)',
        paymentMethod: 'qris',
        subtotal: initialPaid,
        totalAmount: initialPaid,
        amountPaid: initialPaid,
        change: 0,
        customerId: customerId,
        customerName: customerName ?? _customerName,
        timestamp: _activeEditingTab?.createdAt ?? DateTime.now(),
      );
      transactions.add(dpTrx);

      final settlementAmount = totalBill - initialPaid;
      primaryTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: orderId,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: cashierName,
        paymentMethod: paymentMethod,
        subtotal: sub,
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        totalAmount: settlementAmount,
        amountPaid: amountPaid,
        change: change,
        customerId: customerId,
        customerName: customerName ?? _customerName,
        timestamp: DateTime.now(),
      );
      transactions.add(primaryTrx);
    } else {
      // Pembayaran reguler
      primaryTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: orderId,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: cashierName,
        paymentMethod: paymentMethod,
        subtotal: sub,
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        totalAmount: totalBill,
        amountPaid: amountPaid,
        change: change,
        customerId: customerId,
        customerName: customerName ?? _customerName,
        timestamp: DateTime.now(),
      );
      transactions.add(primaryTrx);
    }

    await _storageService.saveTransactions(transactions);

    // 3. Kurangi stok produk jika transaksi langsung counter (bukan open tab yang sudah dikurangi saat dipesan)
    if (_activeEditingTab == null) {
      await _deductStock(completedOrder.items);
    }

    clearCart();
    notifyListeners();
    return primaryTrx;
  }

  /// Menyelesaikan pembayaran pesanan meja (Open Tab) secara langsung tanpa
  /// mengganggu atau menghapus keranjang belanja kasir aktif di POS.
  Future<TransactionModel> completeOrderDirectly({
    required OrderModel order,
    required String shiftId,
    required String cashierId,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    String? customerId,
    String? customerName,
    int? discountAmount,
    double? discountPercent,
    int? taxAmount,
    int? serviceChargeAmount,
  }) async {
    final orders = _storageService.getOrders();
    final orderIndex = orders.indexWhere((o) => o.id == order.id);
    final disc = discountAmount ?? order.discountAmount;
    final discPct = discountPercent ?? order.discountPercent;
    final svc = serviceChargeAmount ?? order.serviceChargeAmount;
    final tax = taxAmount ?? order.taxAmount;
    final sub = order.subtotal;
    final totalBill = (sub - disc + svc + tax).clamp(0, 999999999);
    final initialPaid = order.paidAmount;

    // 1. Simpan pesanan selesai
    final completedOrder = order.copyWith(
      customerName: customerName ?? order.customerName,
      status: 'completed',
      discountAmount: disc,
      discountPercent: discPct,
      taxAmount: tax,
      serviceChargeAmount: svc,
      paidAmount: totalBill,
      completedAt: DateTime.now(),
    );

    if (orderIndex >= 0) {
      orders[orderIndex] = completedOrder;
    } else {
      orders.add(completedOrder);
    }
    await _storageService.saveOrders(orders);

    // 2. Buat rekaman transaksi pembayaran (tangani kombinasi DP QRIS + Pelunasan Kasir)
    final transactions = _storageService.getTransactions();
    TransactionModel primaryTrx;

    if (initialPaid > 0 && initialPaid < totalBill) {
      // Pembayaran kombinasi: DP QRIS + Pelunasan Kasir
      final dpTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: order.id,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: 'Self-Order (QRIS)',
        paymentMethod: 'qris',
        subtotal: initialPaid,
        totalAmount: initialPaid,
        amountPaid: initialPaid,
        change: 0,
        customerId: customerId,
        customerName: customerName ?? order.customerName,
        timestamp: order.createdAt,
      );
      transactions.add(dpTrx);

      final settlementAmount = totalBill - initialPaid;
      primaryTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: order.id,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: cashierName,
        paymentMethod: paymentMethod,
        subtotal: sub,
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        totalAmount: settlementAmount,
        amountPaid: amountPaid,
        change: change,
        customerId: customerId,
        customerName: customerName ?? order.customerName,
        timestamp: DateTime.now(),
      );
      transactions.add(primaryTrx);
    } else {
      primaryTrx = TransactionModel(
        id: 'trx_${_uuid.v4().substring(0, 8)}',
        orderId: order.id,
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: cashierName,
        paymentMethod: paymentMethod,
        subtotal: sub,
        discountAmount: disc,
        discountPercent: discPct,
        taxAmount: tax,
        serviceChargeAmount: svc,
        totalAmount: totalBill,
        amountPaid: amountPaid,
        change: change,
        customerId: customerId,
        customerName: customerName ?? order.customerName,
        timestamp: DateTime.now(),
      );
      transactions.add(primaryTrx);
    }

    await _storageService.saveTransactions(transactions);

    // HANYA reset keranjang jika tab yang sedang diselesaikan adalah yang sedang aktif diedit di POS
    if (_activeEditingTab?.id == order.id) {
      clearCart();
    } else {
      notifyListeners();
    }

    return primaryTrx;
  }

  /// Memisahkan item terpilih dari pesanan meja (Split Bill) menjadi meja / Open Tab baru.
  /// Mengurangi kuantitas item dari meja asal atau menghapusnya jika seluruh kuantitas dipindahkan.
  Future<OrderModel?> splitOrderToNewTab({
    required String sourceOrderId,
    required List<OrderItem> itemsToSplit,
    required String newTableNo,
    String? newCustomerName,
    required String shiftId,
  }) async {
    final orders = _storageService.getOrders();
    final index = orders.indexWhere((o) => o.id == sourceOrderId);
    if (index < 0) return null;

    final sourceOrder = orders[index];
    final remainingItems = <OrderItem>[];

    // Kurangi kuantitas item dari meja asal
    for (final srcItem in sourceOrder.items) {
      final splitMatch = itemsToSplit.where(
        (i) => i.productId == srcItem.productId && i.notes == srcItem.notes,
      );
      final splitQty = splitMatch.fold<int>(0, (sum, i) => sum + i.qty);
      final remQty = srcItem.qty - splitQty;
      if (remQty > 0) {
        remainingItems.add(srcItem.copyWith(qty: remQty));
      }
    }

    // Update pesanan asal
    final updatedSourceOrder = sourceOrder.copyWith(
      items: remainingItems,
      status: remainingItems.isEmpty ? 'completed' : sourceOrder.status,
      completedAt: remainingItems.isEmpty ? DateTime.now() : sourceOrder.completedAt,
    );
    orders[index] = updatedSourceOrder;

    // Buat pesanan baru untuk item yang dipisah
    final newOrder = OrderModel(
      id: 'ord_${_uuid.v4().substring(0, 8)}',
      shiftId: shiftId,
      tableNo: newTableNo,
      customerName: newCustomerName ?? '${sourceOrder.customerName} (Bill B)',
      items: List.from(itemsToSplit),
      status: 'open',
      kitchenStatus: sourceOrder.kitchenStatus,
      createdAt: DateTime.now(),
    );
    orders.add(newOrder);

    await _storageService.saveOrders(orders);
    notifyListeners();
    return newOrder;
  }

  /// Memisahkan item terpilih dari pesanan meja (Split Bill) dan langsung menyelesaikan pembayarannya di kasir.
  /// Item yang dibayar dipotong dari meja asal. Jika semua item lunas, meja asal otomatis berstatus completed.
  Future<TransactionModel> splitOrderAndCheckoutDirectly({
    required String sourceOrderId,
    required List<OrderItem> itemsToPay,
    required String shiftId,
    required String cashierId,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    int? discountAmount,
    double? discountPercent,
    int? taxAmount,
    int? serviceChargeAmount,
    String? customerId,
    String? customerName,
  }) async {
    final orders = _storageService.getOrders();
    final index = orders.indexWhere((o) => o.id == sourceOrderId);
    if (index < 0) {
      throw Exception('Pesanan asal dengan ID $sourceOrderId tidak ditemukan.');
    }

    final sourceOrder = orders[index];
    final remainingItems = <OrderItem>[];

    for (final srcItem in sourceOrder.items) {
      final splitMatch = itemsToPay.where(
        (i) => i.productId == srcItem.productId && i.notes == srcItem.notes,
      );
      final splitQty = splitMatch.fold<int>(0, (sum, i) => sum + i.qty);
      final remQty = srcItem.qty - splitQty;
      if (remQty > 0) {
        remainingItems.add(srcItem.copyWith(qty: remQty));
      }
    }

    // Hitung total bayar untuk item yang di-split
    final sub = itemsToPay.fold<int>(0, (sum, i) => sum + i.total);
    final disc = discountAmount ?? 0;
    final discPct = discountPercent ?? 0.0;
    final svc = serviceChargeAmount ?? 0;
    final tax = taxAmount ?? 0;
    final totalBill = (sub - disc + svc + tax).clamp(0, 999999999);

    final splitCompletedOrderId = 'ord_${_uuid.v4().substring(0, 8)}';
    final splitCompletedOrder = OrderModel(
      id: splitCompletedOrderId,
      shiftId: shiftId,
      tableNo: sourceOrder.tableNo,
      customerName: customerName ?? '${sourceOrder.customerName} (Split)',
      items: List.from(itemsToPay),
      status: 'completed',
      discountAmount: disc,
      discountPercent: discPct,
      taxAmount: tax,
      serviceChargeAmount: svc,
      paidAmount: totalBill,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      kitchenStatus: sourceOrder.kitchenStatus,
    );
    orders.add(splitCompletedOrder);

    // Perbarui pesanan asal: jika sisa item habis, tandai completed
    final updatedSource = sourceOrder.copyWith(
      items: remainingItems,
      status: remainingItems.isEmpty ? 'completed' : sourceOrder.status,
      completedAt: remainingItems.isEmpty ? DateTime.now() : sourceOrder.completedAt,
    );
    orders[index] = updatedSource;
    await _storageService.saveOrders(orders);

    // Rekam transaksi pembayaran
    final transactions = _storageService.getTransactions();
    final splitTrx = TransactionModel(
      id: 'trx_${_uuid.v4().substring(0, 8)}',
      orderId: splitCompletedOrderId,
      shiftId: shiftId,
      cashierId: cashierId,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      subtotal: sub,
      discountAmount: disc,
      discountPercent: discPct,
      taxAmount: tax,
      serviceChargeAmount: svc,
      totalAmount: totalBill,
      amountPaid: amountPaid,
      change: change,
      customerId: customerId,
      customerName: customerName ?? '${sourceOrder.customerName} (Split)',
      timestamp: DateTime.now(),
    );
    transactions.add(splitTrx);
    await _storageService.saveTransactions(transactions);

    notifyListeners();
    return splitTrx;
  }

  /// Mencatat transaksi pelunasan kasbon pelanggan ke dalam log transaksi dan arsip pesanan
  Future<TransactionModel> recordDebtRepaymentTransaction({
    required String customerId,
    required String customerName,
    required int amountPaid,
    required String paymentMethod,
    required String shiftId,
    required String cashierId,
    required String cashierName,
  }) async {
    final orderId = 'ord_repay_${_uuid.v4().substring(0, 8)}';
    final repayOrder = OrderModel(
      id: orderId,
      shiftId: shiftId,
      tableNo: null,
      customerName: customerName,
      items: [
        OrderItem(
          productId: 'item_repay',
          name: 'Pelunasan Kasbon / Hutang',
          price: amountPaid,
          qty: 1,
          notes: 'Pelunasan kasbon a/n $customerName',
        ),
      ],
      status: 'completed',
      paidAmount: amountPaid,
      kitchenStatus: 'served',
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );

    final orders = _storageService.getOrders();
    orders.add(repayOrder);
    await _storageService.saveOrders(orders);

    final trx = TransactionModel(
      id: 'trx_${_uuid.v4().substring(0, 8)}',
      orderId: orderId,
      shiftId: shiftId,
      cashierId: cashierId,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      totalAmount: amountPaid,
      amountPaid: amountPaid,
      change: 0,
      customerId: customerId,
      customerName: customerName,
      timestamp: DateTime.now(),
    );

    final transactions = _storageService.getTransactions();
    transactions.add(trx);
    await _storageService.saveTransactions(transactions);

    notifyListeners();
    return trx;
  }

  /// Pengurangan stok otomatis saat pesanan dibuat atau menu ditambahkan
  Future<void> _deductStock(List<OrderItem> items) async {
    final products = _storageService.getProducts();
    bool modified = false;

    for (final item in items) {
      final idx = products.indexWhere((p) => p.id == item.productId);
      if (idx >= 0 && products[idx].trackStock) {
        final newStock = (products[idx].stock - item.qty).clamp(0, 999999);
        products[idx] = products[idx].copyWith(stock: newStock);
        modified = true;
      }
    }

    if (modified) {
      await _storageService.saveProducts(products);
      loadData();
    }
  }

  /// Mengembalikan stok fisik produk jika pesanan dibatalkan atau dikurangi
  Future<void> _restoreStock(List<OrderItem> items) async {
    final products = _storageService.getProducts();
    bool modified = false;

    for (final item in items) {
      final idx = products.indexWhere((p) => p.id == item.productId);
      if (idx >= 0 && products[idx].trackStock) {
        final newStock = (products[idx].stock + item.qty).clamp(0, 999999);
        products[idx] = products[idx].copyWith(stock: newStock);
        modified = true;
      }
    }

    if (modified) {
      await _storageService.saveProducts(products);
      loadData();
    }
  }

  /// Menambahkan produk menu baru ke katalog resto
  Future<void> addProduct(ProductModel product) async {
    final products = _storageService.getProducts();
    products.add(product);
    await _storageService.saveProducts(products);
    loadData();
  }

  /// Memperbarui rincian produk (nama, harga jual, harga modal, stok, dsb.)
  Future<void> updateProduct(ProductModel product) async {
    final products = _storageService.getProducts();
    final index = products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      products[index] = product;
      await _storageService.saveProducts(products);
      loadData();
    }
  }

  /// Menghapus menu produk dari katalog
  Future<void> deleteProduct(String productId) async {
    final products = _storageService.getProducts();
    products.removeWhere((p) => p.id == productId);
    await _storageService.saveProducts(products);
    loadData();
  }
}
