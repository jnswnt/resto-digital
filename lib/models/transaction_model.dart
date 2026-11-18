/// Model data Transaksi Pembayaran (Selesai).
/// Menyimpan metode bayar (cash, qris, debt), jumlah bayar, kembalian, dan referensi kasbon.
class TransactionModel {
  final String id;
  final String orderId;
  final String shiftId;
  final String cashierId;
  final String cashierName;
  final String paymentMethod; // 'cash', 'qris', 'debt'
  final int totalAmount;
  final int amountPaid;
  final int change;
  final String? customerId; // Diisi jika bayar kasbon atau tercatat atas nama pelanggan
  final String? customerName;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.orderId,
    required this.shiftId,
    required this.cashierId,
    required this.cashierName,
    required this.paymentMethod,
    required this.totalAmount,
    required this.amountPaid,
    this.change = 0,
    this.customerId,
    this.customerName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'shiftId': shiftId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'change': change,
      'customerId': customerId,
      'customerName': customerName,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      shiftId: map['shiftId'] ?? '',
      cashierId: map['cashierId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      amountPaid: (map['amountPaid'] as num?)?.toInt() ?? 0,
      change: (map['change'] as num?)?.toInt() ?? 0,
      customerId: map['customerId'],
      customerName: map['customerName'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
              : (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()))
          : DateTime.now(),
    );
  }
}
