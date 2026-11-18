import 'order_model.dart';

/// Model Pesanan Meja Online (Self-Ordering Pelanggan melalui Web QR)
class OnlineOrderModel {
  final String orderId;
  final String tableNo; // Contoh: "01", "Meja 03"
  final String customerName;
  final List<OrderItem> items;
  final int totalAmount;
  
  /// Status siklus hidup pesanan:
  /// - 'pending'    : Menunggu Konfirmasi dari kasir
  /// - 'processing' : Diproses (diterima & diteruskan ke dapur)
  /// - 'completed'  : Disajikan / Selesai
  /// - 'rejected'   : Ditolak kasir (misal menu habis)
  /// - 'paid'       : Lunas dibayar di kasir atau QRIS
  final String status;
  final String paymentMethod; // 'cashier' | 'qris'
  final String paymentStatus; // 'unpaid' | 'waiting_verification' | 'paid'
  final bool isAdditionalOrder;
  final String? parentOrderId;
  final int roundNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  OnlineOrderModel({
    required this.orderId,
    required this.tableNo,
    required this.customerName,
    required this.items,
    required this.totalAmount,
    this.status = 'pending',
    this.paymentMethod = 'cashier',
    this.paymentStatus = 'unpaid',
    this.isAdditionalOrder = false,
    this.parentOrderId,
    this.roundNumber = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Menampilkan label status dalam Bahasa Indonesia yang ramah pengguna
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'processing':
        return 'Diproses';
      case 'completed':
      case 'served':
        return 'Disajikan / Selesai';
      case 'paid':
        return 'Lunas';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  /// Label putaran pesanan (Pesanan Awal vs Pesanan Tambahan Round 2)
  String get roundLabel => roundNumber > 1 ? 'Round $roundNumber (Tambahan)' : 'Pesanan Utama';

  /// Mengecek apakah pesanan masih baru dan memerlukan tindakan kasir
  bool get isPending => status == 'pending';

  /// Mengecek apakah pesanan sedang diproses di dapur
  bool get isProcessing => status == 'processing';

  /// Mengecek apakah pesanan sudah selesai
  bool get isCompleted => status == 'completed' || status == 'served';

  /// Mengecek apakah pesanan sudah lunas dibayar
  bool get isPaid => status == 'paid' || paymentStatus == 'paid';

  /// Mengecek apakah tamu memilih QRIS dan menunggu verifikasi kasir
  bool get isQrisWaitingVerification =>
      paymentMethod == 'qris' && paymentStatus == 'waiting_verification';

  /// Mengecek apakah pembayaran QRIS sudah terverifikasi lunas
  bool get isQrisPaid => paymentMethod == 'qris' && paymentStatus == 'paid';

  /// Total seluruh kuantitas item dalam pesanan ini
  int get totalItems => items.fold<int>(0, (sum, i) => sum + i.qty);

  OnlineOrderModel copyWith({
    String? orderId,
    String? tableNo,
    String? customerName,
    List<OrderItem>? items,
    int? totalAmount,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    bool? isAdditionalOrder,
    String? parentOrderId,
    int? roundNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OnlineOrderModel(
      orderId: orderId ?? this.orderId,
      tableNo: tableNo ?? this.tableNo,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isAdditionalOrder: isAdditionalOrder ?? this.isAdditionalOrder,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      roundNumber: roundNumber ?? this.roundNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'tableNo': tableNo,
      'customerName': customerName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'isAdditionalOrder': isAdditionalOrder,
      'parentOrderId': parentOrderId,
      'roundNumber': roundNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OnlineOrderModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems.map((item) {
      if (item is Map<String, dynamic>) {
        return OrderItem(
          productId: item['id'] ?? item['productId'] ?? '',
          name: item['name'] ?? item['productName'] ?? 'Menu',
          price: (item['price'] as num?)?.toInt() ?? 0,
          qty: (item['qty'] ?? item['quantity'] as num?)?.toInt() ?? 1,
          notes: item['note'] ?? item['notes'] ?? '',
        );
      }
      return OrderItem(productId: '', name: 'Menu', price: 0);
    }).toList();

    DateTime parseDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      } else if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      return DateTime.now();
    }

    final total = (map['totalAmount'] ?? map['totalPrice'] as num?)?.toInt() ?? 0;

    return OnlineOrderModel(
      orderId: map['orderId'] ?? map['id'] ?? docId ?? '',
      tableNo: (map['tableNo'] ?? '').toString(),
      customerName: map['customerName'] ?? 'Pelanggan Meja',
      items: parsedItems,
      totalAmount: total,
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'cashier',
      paymentStatus: map['paymentStatus'] ?? 'unpaid',
      isAdditionalOrder: map['isAdditionalOrder'] == true,
      parentOrderId: map['parentOrderId'],
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? (map['isAdditionalOrder'] == true ? 2 : 1),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  /// Parsing dokumen dari Firebase Firestore REST API response format:
  /// `fields: { orderId: { stringValue: ... }, ... }`
  factory OnlineOrderModel.fromFirestoreRest(String docName, Map<String, dynamic> fields) {
    final docId = docName.split('/').last;

    String getString(String key, [String def = '']) {
      return fields[key]?['stringValue'] ?? def;
    }

    int getInt(String key, [int def = 0]) {
      final f = fields[key];
      if (f == null) return def;
      if (f['integerValue'] != null) return int.tryParse(f['integerValue'].toString()) ?? def;
      if (f['doubleValue'] != null) return (f['doubleValue'] as num).toInt();
      return def;
    }

    bool getBool(String key, [bool def = false]) {
      final f = fields[key];
      if (f == null) return def;
      if (f['booleanValue'] != null) return f['booleanValue'] as bool;
      return def;
    }

    final rawItemsArray = fields['items']?['arrayValue']?['values'] as List<dynamic>? ?? [];
    final List<OrderItem> items = [];

    for (final itemVal in rawItemsArray) {
      final itemMap = itemVal['mapValue']?['fields'] as Map<String, dynamic>?;
      if (itemMap != null) {
        final prodId = itemMap['id']?['stringValue'] ?? itemMap['productId']?['stringValue'] ?? '';
        final name = itemMap['name']?['stringValue'] ?? '';
        final price = int.tryParse(itemMap['price']?['integerValue']?.toString() ?? '') ??
            (itemMap['price']?['doubleValue'] as num?)?.toInt() ?? 0;
        final qty = int.tryParse(itemMap['qty']?['integerValue']?.toString() ?? '') ?? 1;
        final note = itemMap['note']?['stringValue'] ?? itemMap['notes']?['stringValue'] ?? '';

        items.add(OrderItem(
          productId: prodId,
          name: name,
          price: price,
          qty: qty,
          notes: note,
        ));
      }
    }

    DateTime parseIso(String str) => DateTime.tryParse(str) ?? DateTime.now();

    final isAdd = getBool('isAdditionalOrder', false);
    final round = getInt('roundNumber', isAdd ? 2 : 1);

    return OnlineOrderModel(
      orderId: getString('orderId', docId),
      tableNo: getString('tableNo', '01'),
      customerName: getString('customerName', 'Pelanggan Meja'),
      items: items,
      totalAmount: getInt('totalAmount', 0),
      status: getString('status', 'pending'),
      paymentMethod: getString('paymentMethod', 'cashier'),
      paymentStatus: getString('paymentStatus', 'unpaid'),
      isAdditionalOrder: isAdd,
      parentOrderId: fields['parentOrderId']?['stringValue'],
      roundNumber: round,
      createdAt: parseIso(getString('createdAt')),
      updatedAt: parseIso(getString('updatedAt')),
    );
  }
}
