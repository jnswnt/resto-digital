/// Model data Transaksi Pembayaran (Selesai).
/// Menyimpan metode bayar (cash, qris, debt), rincian diskon, pajak, biaya layanan,
/// jumlah bayar, kembalian, dan referensi pelanggan / kasbon.
class TransactionModel {
  final String id;
  final String orderId;
  final String shiftId;
  final String cashierId;
  final String cashierName;
  final String paymentMethod; // 'cash', 'qris', 'debt'
  final int subtotal; // Nilai kotor pesanan sebelum diskon, service charge & pajak
  final int discountAmount; // Nilai potongan diskon nominal rupiah
  final double discountPercent; // Persentase diskon yang diterapkan
  final int taxAmount; // Nilai Pajak Restoran (PB1)
  final int serviceChargeAmount; // Nilai Biaya Layanan (Service Charge)
  final int totalAmount; // Total tagihan final yang harus dibayar
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
    int? subtotal,
    this.discountAmount = 0,
    this.discountPercent = 0.0,
    this.taxAmount = 0,
    this.serviceChargeAmount = 0,
    required this.totalAmount,
    required this.amountPaid,
    this.change = 0,
    this.customerId,
    this.customerName,
    DateTime? timestamp,
  })  : subtotal = subtotal ?? totalAmount,
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'shiftId': shiftId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'taxAmount': taxAmount,
      'serviceChargeAmount': serviceChargeAmount,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'change': change,
      'customerId': customerId,
      'customerName': customerName,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final tot = (map['totalAmount'] as num?)?.toInt() ?? 0;
    return TransactionModel(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      shiftId: map['shiftId'] ?? '',
      cashierId: map['cashierId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      subtotal: (map['subtotal'] as num?)?.toInt() ?? tot,
      discountAmount: (map['discountAmount'] as num?)?.toInt() ?? 0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toInt() ?? 0,
      serviceChargeAmount: (map['serviceChargeAmount'] as num?)?.toInt() ?? 0,
      totalAmount: tot,
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

  TransactionModel copyWith({
    String? id,
    String? orderId,
    String? shiftId,
    String? cashierId,
    String? cashierName,
    String? paymentMethod,
    int? subtotal,
    int? discountAmount,
    double? discountPercent,
    int? taxAmount,
    int? serviceChargeAmount,
    int? totalAmount,
    int? amountPaid,
    int? change,
    String? customerId,
    String? customerName,
    DateTime? timestamp,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      shiftId: shiftId ?? this.shiftId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      change: change ?? this.change,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
