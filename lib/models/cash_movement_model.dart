/// Model data Mutasi Kas Keluar / Masuk Laci (Petty Cash).
/// Digunakan kasir untuk mencatat belanja operasional harian resto (es batu, gas, galon).
class CashMovementModel {
  final String id;
  final String shiftId;
  final String userId;
  final String cashierName;
  final String type; // 'out' (kas keluar) atau 'in' (kas masuk tambahan)
  final int amount;
  final String notes; // Alasan/keperluan pengeluaran
  final DateTime timestamp;

  CashMovementModel({
    required this.id,
    required this.shiftId,
    required this.userId,
    required this.cashierName,
    this.type = 'out',
    required this.amount,
    required this.notes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'userId': userId,
      'cashierName': cashierName,
      'type': type,
      'amount': amount,
      'notes': notes,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory CashMovementModel.fromMap(Map<String, dynamic> map) {
    return CashMovementModel(
      id: map['id'] ?? '',
      shiftId: map['shiftId'] ?? '',
      userId: map['userId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      type: map['type'] ?? 'out',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      notes: map['notes'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
              : (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()))
          : DateTime.now(),
    );
  }
}
