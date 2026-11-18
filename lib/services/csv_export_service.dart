import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/sales_analytics_model.dart';
import '../models/transaction_model.dart';

/// Layanan Generator Laporan CSV (Comma Separated Values)
/// Format standar RFC 4180 yang siap diimpor langsung ke Google Sheets / Microsoft Excel.
class CsvExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Membuat teks CSV untuk rincian seluruh item dari transaksi yang difilter
  static String generateTransactionsCsv({
    required List<TransactionModel> transactions,
    required List<OrderModel> orders,
    required List<ProductModel> products,
  }) {
    final buffer = StringBuffer();

    // Map order by id & product by id untuk lookup cepat
    final orderMap = {for (final o in orders) o.id: o};
    final productMap = {for (final p in products) p.id: p};

    // Header CSV
    buffer.writeln(
      'ID Transaksi,Waktu,Kasir,ID Order,Nomor Meja,Pelanggan,Metode Bayar,Total Transaksi,ID Menu,Nama Menu,Qty,Harga Jual Satuan,Modal HPP Satuan,Subtotal Jual,Subtotal Modal,Laba Kotor Item,Catatan',
    );

    for (final tx in transactions) {
      final order = orderMap[tx.orderId];
      final timeStr = _dateFormat.format(tx.timestamp);
      final cashier = _escapeCsv(tx.cashierName);
      final table = _escapeCsv(order?.tableNo ?? '-');
      final customer = _escapeCsv(tx.customerName ?? order?.customerName ?? 'Pelanggan');
      final payMethod = tx.paymentMethod.toUpperCase();

      if (order != null && order.items.isNotEmpty) {
        for (final item in order.items) {
          final prod = productMap[item.productId];
          final buyPrice = prod?.buyPrice ?? 0;
          final sellPrice = item.price;
          final subtotalSell = item.total;
          final subtotalCogs = buyPrice * item.qty;
          final itemProfit = subtotalSell - subtotalCogs;
          final note = _escapeCsv(item.notes);

          buffer.writeln(
            '${tx.id},$timeStr,$cashier,${tx.orderId},$table,$customer,$payMethod,${tx.totalAmount},${item.productId},${_escapeCsv(item.name)},${item.qty},$sellPrice,$buyPrice,$subtotalSell,$subtotalCogs,$itemProfit,$note',
          );
        }
      } else {
        // Baris transaksi tunggal jika detail item order tidak ditemukan
        buffer.writeln(
          '${tx.id},$timeStr,$cashier,${tx.orderId},$table,$customer,$payMethod,${tx.totalAmount},-,-,0,0,0,${tx.totalAmount},0,${tx.totalAmount},-',
        );
      }
    }

    return buffer.toString();
  }

  /// Membuat teks CSV untuk ringkasan performa penjualan produk / menu terlaris
  static String generateMenuRankingCsv({
    required SalesSummary summary,
  }) {
    final buffer = StringBuffer();

    // Header CSV
    buffer.writeln(
      'Peringkat,ID Menu,Nama Menu,Kategori,Porsi Terjual,Total Omzet,Total Modal HPP,Total Laba Kotor,Margin Laba (%)',
    );

    for (int i = 0; i < summary.topSellingItems.length; i++) {
      final item = summary.topSellingItems[i];
      buffer.writeln(
        '${i + 1},${item.productId},${_escapeCsv(item.name)},${_escapeCsv(item.category)},${item.qtySold},${item.totalRevenue},${item.totalCogs},${item.totalProfit},${item.profitMargin.toStringAsFixed(1)}%',
      );
    }

    return buffer.toString();
  }

  /// Menyalin isi teks CSV ke clipboard sistem (Mobile & Tablet Friendly)
  static Future<bool> copyToClipboard(String csvContent) async {
    try {
      await Clipboard.setData(ClipboardData(text: csvContent));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Menghasilkan nama file standar untuk berkas yang diekspor
  static String generateFileName(String prefix) {
    final timestamp = _fileDateFormat.format(DateTime.now());
    return '${prefix}_$timestamp.csv';
  }

  /// Helper untuk meng-escape teks yang mengandung tanda koma, petik dua, atau baris baru
  static String _escapeCsv(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }
}
