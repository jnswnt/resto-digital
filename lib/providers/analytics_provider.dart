import 'package:flutter/material.dart';
import '../models/sales_analytics_model.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../services/csv_export_service.dart';

/// Opsi Rentang Waktu Analitik
enum AnalyticsDateFilter {
  today,
  yesterday,
  last7Days,
  thisMonth,
  custom,
}

/// Provider Pengelolaan Analisis Penjualan Resto, Margin Keuntungan & Laporan Owner
class AnalyticsProvider with ChangeNotifier {
  final StorageService _storageService;

  AnalyticsDateFilter _selectedFilter = AnalyticsDateFilter.today;
  DateTimeRange? _customDateRange;

  SalesSummary _summary = SalesSummary.empty();
  bool _isLoading = false;

  AnalyticsProvider(this._storageService) {
    calculateSummary();
  }

  AnalyticsDateFilter get selectedFilter => _selectedFilter;
  DateTimeRange? get customDateRange => _customDateRange;
  SalesSummary get summary => _summary;
  bool get isLoading => _isLoading;

  /// Mengubah filter waktu cepat (Hari ini, Kemarin, 7 Hari, Bulan Ini)
  void setFilter(AnalyticsDateFilter filter) {
    if (_selectedFilter == filter && filter != AnalyticsDateFilter.custom) return;
    _selectedFilter = filter;
    calculateSummary();
  }

  /// Mengatur rentang tanggal khusus dari kalender
  void setCustomRange(DateTimeRange range) {
    _selectedFilter = AnalyticsDateFilter.custom;
    _customDateRange = range;
    calculateSummary();
  }

  /// Menentukan waktu awal dan akhir berdasarkan filter yang aktif
  DateTimeRange _getDateRangeForFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedFilter) {
      case AnalyticsDateFilter.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case AnalyticsDateFilter.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59);
        return DateTimeRange(start: yStart, end: yEnd);

      case AnalyticsDateFilter.last7Days:
        final start7 = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: start7, end: todayEnd);

      case AnalyticsDateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
        return DateTimeRange(start: monthStart, end: todayEnd);

      case AnalyticsDateFilter.custom:
        if (_customDateRange != null) {
          final cStart = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
            0,
            0,
            0,
          );
          final cEnd = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
          return DateTimeRange(start: cStart, end: cEnd);
        }
        return DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  /// Melakukan agregasi data finansial, perhitungan HPP dan laba kotor
  void calculateSummary() {
    _isLoading = true;
    notifyListeners();

    final range = _getDateRangeForFilter();
    final allTransactions = _storageService.getTransactions();
    final allOrders = _storageService.getOrders();
    final allProducts = _storageService.getProducts();

    // 1. Filter transaksi berdasarkan rentang tanggal
    final filteredTxs = allTransactions.where((tx) {
      return !tx.timestamp.isBefore(range.start) && !tx.timestamp.isAfter(range.end);
    }).toList();

    // Map lookup
    final orderMap = {for (final o in allOrders) o.id: o};
    final productMap = {for (final p in allProducts) p.id: p};

    int totalRevenue = 0;
    int cashTotal = 0;
    int qrisTotal = 0;
    int debtTotal = 0;
    int totalCogs = 0;

    // Peta penjualan menu: productId -> {name, category, qty, revenue, cogs}
    final Map<String, _ItemAggregator> itemAggregators = {};
    final Map<String, _DailyAggregator> dailyAggregators = {};

    for (final tx in filteredTxs) {
      final txAmount = tx.totalAmount;
      final isDebtRepayment = tx.orderId.startsWith('ord_repay_');

      if (isDebtRepayment) {
        // Pelunasan kasbon: kas bertambah, piutang berkurang, omzet tidak diduplikasi
        if (tx.paymentMethod == 'cash') {
          cashTotal += txAmount;
        } else if (tx.paymentMethod == 'qris') {
          qrisTotal += txAmount;
        }
        debtTotal -= txAmount;
      } else {
        totalRevenue += txAmount;

        if (tx.paymentMethod == 'cash') {
          cashTotal += txAmount;
        } else if (tx.paymentMethod == 'qris') {
          qrisTotal += txAmount;
        } else if (tx.paymentMethod == 'debt') {
          debtTotal += txAmount;
        }
      }

      // Hitung metrik harian untuk grafik tren
      final dayKey = '${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}-${tx.timestamp.day.toString().padLeft(2, '0')}';
      final daily = dailyAggregators.putIfAbsent(
        dayKey,
        () => _DailyAggregator(date: DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day)),
      );
      if (!isDebtRepayment) {
        daily.revenue += txAmount;
      }
      daily.transactionCount++;

      // Rincian per item dari order (hanya untuk pesanan menu, abaikan dummy pelunasan kasbon)
      if (!isDebtRepayment) {
        final order = orderMap[tx.orderId];
        if (order != null && order.items.isNotEmpty) {
          for (final item in order.items) {
            final prod = productMap[item.productId];
            final buyPrice = prod?.buyPrice ?? 0;
            final itemRev = item.total;
            final itemCost = buyPrice * item.qty;

            totalCogs += itemCost;
            daily.cogs += itemCost;

            final agg = itemAggregators.putIfAbsent(
              item.productId,
              () => _ItemAggregator(
                productId: item.productId,
                name: item.name,
                category: prod?.categoryId ?? 'Menu',
              ),
            );
            agg.qtySold += item.qty;
            agg.totalRevenue += itemRev;
            agg.totalCogs += itemCost;
          }
        }
      }
    }

    final int netRevenue = totalRevenue;
    final int grossProfit = netRevenue - totalCogs;
    final double profitMargin = netRevenue > 0 ? (grossProfit / netRevenue) * 100.0 : 0.0;
    final int txCount = filteredTxs.length;
    final double aov = txCount > 0 ? (netRevenue / txCount) : 0.0;

    // Urutkan item terlaris berdasarkan kuantitas terbanyak, kemudian omzet
    final List<ItemSalesRank> ranks = itemAggregators.values.map((agg) {
      final profit = agg.totalRevenue - agg.totalCogs;
      final margin = agg.totalRevenue > 0 ? (profit / agg.totalRevenue) * 100.0 : 0.0;
      return ItemSalesRank(
        productId: agg.productId,
        name: agg.name,
        category: agg.category,
        qtySold: agg.qtySold,
        totalRevenue: agg.totalRevenue,
        totalCogs: agg.totalCogs,
        totalProfit: profit,
        profitMargin: margin,
      );
    }).toList();

    ranks.sort((a, b) {
      final cmp = b.qtySold.compareTo(a.qtySold);
      if (cmp != 0) return cmp;
      return b.totalRevenue.compareTo(a.totalRevenue);
    });

    // Metrik harian terurut kronologis
    final dailyList = dailyAggregators.values.map((d) {
      return DailySalesMetric(
        date: d.date,
        revenue: d.revenue,
        profit: d.revenue - d.cogs,
        transactionCount: d.transactionCount,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    _summary = SalesSummary(
      startDate: range.start,
      endDate: range.end,
      totalRevenue: totalRevenue,
      netRevenue: netRevenue,
      totalCogs: totalCogs,
      grossProfit: grossProfit,
      profitMargin: profitMargin,
      transactionCount: txCount,
      averageOrderValue: aov,
      cashTotal: cashTotal,
      qrisTotal: qrisTotal,
      debtTotal: debtTotal,
      topSellingItems: ranks,
      dailyMetrics: dailyList,
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Mengirimkan laporan penutupan kasir EOD ke WhatsApp Pemilik Resto
  Future<bool> sendEodReportToWhatsApp({
    required String cashierName,
    String? shiftName,
    String? note,
  }) async {
    final settings = _storageService.getSettings();
    final ownerPhone = settings.phoneWA;
    final storeName = settings.storeName;

    final message = WhatsappService.formatEodReportMessage(
      storeName: storeName,
      summary: _summary,
      cashierName: cashierName,
      closingTime: DateTime.now(),
      shiftName: shiftName,
      note: note,
    );

    return await WhatsappService.openWhatsApp(
      phone: ownerPhone,
      message: message,
    );
  }

  /// Menghasilkan dan menyalin teks CSV transaksi ke clipboard sistem
  Future<bool> copyTransactionsCsvToClipboard() async {
    final range = _getDateRangeForFilter();
    final allTransactions = _storageService.getTransactions();
    final allOrders = _storageService.getOrders();
    final allProducts = _storageService.getProducts();

    final filteredTxs = allTransactions.where((tx) {
      return !tx.timestamp.isBefore(range.start) && !tx.timestamp.isAfter(range.end);
    }).toList();

    final csvText = CsvExportService.generateTransactionsCsv(
      transactions: filteredTxs,
      orders: allOrders,
      products: allProducts,
    );

    return await CsvExportService.copyToClipboard(csvText);
  }

  /// Menghasilkan dan menyalin teks CSV peringkat menu ke clipboard sistem
  Future<bool> copyMenuRankingCsvToClipboard() async {
    final csvText = CsvExportService.generateMenuRankingCsv(summary: _summary);
    return await CsvExportService.copyToClipboard(csvText);
  }
}

class _ItemAggregator {
  final String productId;
  final String name;
  final String category;
  int qtySold = 0;
  int totalRevenue = 0;
  int totalCogs = 0;

  _ItemAggregator({
    required this.productId,
    required this.name,
    required this.category,
  });
}

class _DailyAggregator {
  final DateTime date;
  int revenue = 0;
  int cogs = 0;
  int transactionCount = 0;

  _DailyAggregator({required this.date});
}
