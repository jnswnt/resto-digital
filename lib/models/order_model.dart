/// Item individual di dalam pesanan / keranjang belanja.
class OrderItem {
  final String productId;
  final String name;
  final int price;
  int qty;
  String notes; // Catatan pesanan khusus (misal: "Gula sedikit, es banyak")

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    this.qty = 1,
    this.notes = '',
  });

  int get total => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'qty': qty,
      'notes': notes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      notes: map['notes'] ?? '',
    );
  }

  OrderItem copyWith({
    String? productId,
    String? name,
    int? price,
    int? qty,
    String? notes,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      notes: notes ?? this.notes,
    );
  }
}

/// Model data Pesanan (Mendukung transaksi langsung, Open Tab / Meja, & Kitchen Display System)
class OrderModel {
  final String id;
  final String shiftId;
  final String? tableNo; // Contoh: "Meja 03" atau null jika mode meja nonaktif
  final String customerName; // Nama pemesan / panggilan
  final List<OrderItem> items;
  final String status; // 'open' (gantung/nongkrong), 'completed', 'cancelled'
  final int paidAmount; // Jumlah yang telah dibayar (misal pelunasan di muka QRIS mandiri)
  final String? onlineOrderId; // ID referensi pesanan online di Firestore jika ada
  final DateTime createdAt;
  final DateTime? completedAt;

  // --- Pelacakan Siklus Kitchen Display System (KDS) ---
  final String kitchenStatus; // 'pending' (menunggu), 'cooking' (dimasak), 'ready' (siap saji), 'served' (disajikan)
  final DateTime? cookingStartedAt;
  final List<String> completedItemIds; // Daftar productId atau nama item yang sudah dicentang selesai oleh koki

  OrderModel({
    required this.id,
    required this.shiftId,
    this.tableNo,
    this.customerName = 'Pelanggan',
    required this.items,
    this.status = 'open',
    this.paidAmount = 0,
    this.onlineOrderId,
    DateTime? createdAt,
    this.completedAt,
    this.kitchenStatus = 'pending',
    this.cookingStartedAt,
    this.completedItemIds = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  int get subtotal => items.fold(0, (sum, item) => sum + item.total);
  int get total => subtotal;
  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  /// Sisa tagihan yang harus dibayar kasir setelah dipotong pembayaran di muka (misal QRIS mandiri)
  int get remainingAmount => (total - paidAmount).clamp(0, 999999999);

  // Status dapur helper
  bool get isKitchenPending => kitchenStatus == 'pending';
  bool get isKitchenCooking => kitchenStatus == 'cooking';
  bool get isKitchenReady => kitchenStatus == 'ready';
  bool get isKitchenServed => kitchenStatus == 'served';

  /// Durasi sejak pesanan dibuat hingga saat ini
  Duration get elapsedOrderTime => DateTime.now().difference(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'tableNo': tableNo,
      'customerName': customerName,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status,
      'paidAmount': paidAmount,
      'onlineOrderId': onlineOrderId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'kitchenStatus': kitchenStatus,
      'cookingStartedAt': cookingStartedAt?.millisecondsSinceEpoch,
      'completedItemIds': completedItemIds,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      shiftId: map['shiftId'] ?? '',
      tableNo: map['tableNo'],
      customerName: map['customerName'] ?? 'Pelanggan',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: map['status'] ?? 'open',
      paidAmount: (map['paidAmount'] as num?)?.toInt() ?? 0,
      onlineOrderId: map['onlineOrderId'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()))
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
              : DateTime.tryParse(map['completedAt'].toString()))
          : null,
      kitchenStatus: map['kitchenStatus'] ?? 'pending',
      cookingStartedAt: map['cookingStartedAt'] != null
          ? (map['cookingStartedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['cookingStartedAt'] as int)
              : DateTime.tryParse(map['cookingStartedAt'].toString()))
          : null,
      completedItemIds: (map['completedItemIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  OrderModel copyWith({
    String? id,
    String? shiftId,
    String? tableNo,
    String? customerName,
    List<OrderItem>? items,
    String? status,
    int? paidAmount,
    String? onlineOrderId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? kitchenStatus,
    DateTime? cookingStartedAt,
    List<String>? completedItemIds,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      tableNo: tableNo ?? this.tableNo,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      onlineOrderId: onlineOrderId ?? this.onlineOrderId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
      cookingStartedAt: cookingStartedAt ?? this.cookingStartedAt,
      completedItemIds: completedItemIds ?? this.completedItemIds,
    );
  }
}
