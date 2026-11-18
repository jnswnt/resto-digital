library;

/// Model data Analitik Penjualan Resto.
/// Mengelola agregasi omzet, perhitungan HPP (Harga Pokok Penjualan),
/// laba kotor (Gross Profit), dan peringkat menu terlaris.

class SalesSummary {
  final DateTime startDate;
  final DateTime endDate;
  final int totalRevenue;       // Total omzet bruto
  final int totalDiscount;      // Total potongan diskon
  final int netRevenue;         // Total omzet bersih (totalRevenue - totalDiscount)
  final int totalCogs;          // Total modal bahan/HPP
  final int grossProfit;        // Laba kotor (netRevenue - totalCogs)
  final double profitMargin;     // Persentase margin laba kotor (%)
  final int transactionCount;   // Jumlah transaksi selesai
  final double averageOrderValue; // Nilai rata-rata belanja per transaksi (AOV)

  // Rincian Metode Pembayaran
  final int cashTotal;          // Uang tunai fisik di laci kasir
  final int qrisTotal;          // Saldo QRIS digital di rekening
  final int debtTotal;          // Total kasbon pelanggan (piutang belum lunas)

  // Peringkat Menu
  final List<ItemSalesRank> topSellingItems;
  final List<DailySalesMetric> dailyMetrics;

  SalesSummary({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    this.totalDiscount = 0,
    required this.netRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.profitMargin,
    required this.transactionCount,
    required this.averageOrderValue,
    required this.cashTotal,
    required this.qrisTotal,
    required this.debtTotal,
    required this.topSellingItems,
    this.dailyMetrics = const [],
  });

  factory SalesSummary.empty({DateTime? start, DateTime? end}) {
    final now = DateTime.now();
    final s = start ?? DateTime(now.year, now.month, now.day);
    final e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
    return SalesSummary(
      startDate: s,
      endDate: e,
      totalRevenue: 0,
      totalDiscount: 0,
      netRevenue: 0,
      totalCogs: 0,
      grossProfit: 0,
      profitMargin: 0.0,
      transactionCount: 0,
      averageOrderValue: 0.0,
      cashTotal: 0,
      qrisTotal: 0,
      debtTotal: 0,
      topSellingItems: const [],
      dailyMetrics: const [],
    );
  }
}

/// Representasi Peringkat Menu Berdasarkan Volume & Omzet Penjualan
class ItemSalesRank {
  final String productId;
  final String name;
  final String category;
  final int qtySold;
  final int totalRevenue;
  final int totalCogs;
  final int totalProfit;
  final double profitMargin;

  ItemSalesRank({
    required this.productId,
    required this.name,
    required this.category,
    required this.qtySold,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalProfit,
    required this.profitMargin,
  });
}

/// Metrik Penjualan Harian untuk Grafik Tren
class DailySalesMetric {
  final DateTime date;
  final int revenue;
  final int profit;
  final int transactionCount;

  DailySalesMetric({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.transactionCount,
  });
}
