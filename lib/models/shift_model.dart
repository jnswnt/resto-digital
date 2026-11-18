/// Model data Sesi Shift Kerja Kasir.
/// Mengelola uang modal awal, penjualan tunai/qris/kasbon, kas keluar, dan rekonsiliasi kas fisik.
class ShiftModel {
  final String id;
  final String userId;
  final String cashierName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int initialCash; // Modal awal di laci
  final int totalCashSales; // Penjualan tunai
  final int totalQrisSales; // Penjualan QRIS
  final int totalDebtSales; // Penjualan kasbon
  final int totalDebtRepaidCash; // Uang tunai dari pelunasan kasbon
  final int totalCashOut; // Pengeluaran kas laci (petty cash)
  final int expectedCash; // Kas yang seharusnya ada di laci
  final int actualCash; // Uang fisik aktual saat tutup shift
  final int difference; // actualCash - expectedCash (0 = Sesuai, <0 = Kurang, >0 = Lebih)
  final String status; // 'open' atau 'closed'

  ShiftModel({
    required this.id,
    required this.userId,
    required this.cashierName,
    required this.startedAt,
    this.endedAt,
    required this.initialCash,
    this.totalCashSales = 0,
    this.totalQrisSales = 0,
    this.totalDebtSales = 0,
    this.totalDebtRepaidCash = 0,
    this.totalCashOut = 0,
    this.expectedCash = 0,
    this.actualCash = 0,
    this.difference = 0,
    this.status = 'open',
  });

  /// Menghitung kas sistem yang seharusnya ada di laci
  static int calculateExpectedCash({
    required int initialCash,
    required int totalCashSales,
    required int totalDebtRepaidCash,
    required int totalCashOut,
  }) {
    return initialCash + totalCashSales + totalDebtRepaidCash - totalCashOut;
  }

  /// Status selisih: 'balance', 'shortage' (kurang), 'overage' (lebih)
  String get differenceStatus {
    if (difference == 0) return 'balance';
    if (difference < 0) return 'shortage';
    return 'overage';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'cashierName': cashierName,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'endedAt': endedAt?.millisecondsSinceEpoch,
      'initialCash': initialCash,
      'totalCashSales': totalCashSales,
      'totalQrisSales': totalQrisSales,
      'totalDebtSales': totalDebtSales,
      'totalDebtRepaidCash': totalDebtRepaidCash,
      'totalCashOut': totalCashOut,
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'difference': difference,
      'status': status,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      startedAt: map['startedAt'] != null
          ? (map['startedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int)
              : (DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()))
          : DateTime.now(),
      endedAt: map['endedAt'] != null
          ? (map['endedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int)
              : DateTime.tryParse(map['endedAt'].toString()))
          : null,
      initialCash: (map['initialCash'] as num?)?.toInt() ?? 0,
      totalCashSales: (map['totalCashSales'] as num?)?.toInt() ?? 0,
      totalQrisSales: (map['totalQrisSales'] as num?)?.toInt() ?? 0,
      totalDebtSales: (map['totalDebtSales'] as num?)?.toInt() ?? 0,
      totalDebtRepaidCash: (map['totalDebtRepaidCash'] as num?)?.toInt() ?? 0,
      totalCashOut: (map['totalCashOut'] as num?)?.toInt() ?? 0,
      expectedCash: (map['expectedCash'] as num?)?.toInt() ?? 0,
      actualCash: (map['actualCash'] as num?)?.toInt() ?? 0,
      difference: (map['difference'] as num?)?.toInt() ?? 0,
      status: map['status'] ?? 'open',
    );
  }

  ShiftModel copyWith({
    String? id,
    String? userId,
    String? cashierName,
    DateTime? startedAt,
    DateTime? endedAt,
    int? initialCash,
    int? totalCashSales,
    int? totalQrisSales,
    int? totalDebtSales,
    int? totalDebtRepaidCash,
    int? totalCashOut,
    int? expectedCash,
    int? actualCash,
    int? difference,
    String? status,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cashierName: cashierName ?? this.cashierName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      initialCash: initialCash ?? this.initialCash,
      totalCashSales: totalCashSales ?? this.totalCashSales,
      totalQrisSales: totalQrisSales ?? this.totalQrisSales,
      totalDebtSales: totalDebtSales ?? this.totalDebtSales,
      totalDebtRepaidCash: totalDebtRepaidCash ?? this.totalDebtRepaidCash,
      totalCashOut: totalCashOut ?? this.totalCashOut,
      expectedCash: expectedCash ?? this.expectedCash,
      actualCash: actualCash ?? this.actualCash,
      difference: difference ?? this.difference,
      status: status ?? this.status,
    );
  }
}
