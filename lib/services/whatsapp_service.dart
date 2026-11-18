import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';

import '../models/sales_analytics_model.dart';

/// Layanan untuk menyusun pesan struk transaksi dan tagihan kasbon,
/// serta membuka aplikasi WhatsApp secara langsung melalui deep link wa.me.
class WhatsappService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String _formatDateTime(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (_) {
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  static String _formatDateOnly(DateTime date) {
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    }
  }

  static String _formatTimeOnly(DateTime date) {
    try {
      return DateFormat('HH:mm', 'id_ID').format(date);
    } catch (_) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Membersihkan format nomor telepon Indonesia menjadi format internasional (contoh: 0812 -> 62812)
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+62')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Membuka aplikasi WhatsApp dengan pesan terformat
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final formattedPhone = formatPhoneNumber(phone);
    final encodedMessage = Uri.encodeComponent(message);
    final urlString = 'https://wa.me/$formattedPhone?text=$encodedMessage';
    final uri = Uri.parse(urlString);

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Jika launchMode external gagal, coba mode platform default
      return await launchUrl(uri);
    }
  }

  /// Membuat teks nota transaksi resto
  static String generateReceiptMessage({
    required String storeName,
    required String storeAddress,
    required String receiptNo,
    required OrderModel order,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    String? receiptFooter,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🍽️ *$storeName*');
    if (storeAddress.isNotEmpty) {
      buffer.writeln(storeAddress);
    }
    buffer.writeln('================================');
    buffer.writeln('No. Nota : #$receiptNo');
    buffer.writeln('Waktu    : ${_formatDateTime(order.createdAt)} WIB');
    buffer.writeln('Kasir    : $cashierName');
    if (order.tableNo != null && order.tableNo!.isNotEmpty) {
      buffer.writeln('Meja     : ${order.tableNo}');
    }
    buffer.writeln('Pemesan  : ${order.customerName}');
    buffer.writeln('--------------------------------');

    for (final item in order.items) {
      final itemTotal = _currencyFormat.format(item.total);
      final itemPrice = _currencyFormat.format(item.price);
      buffer.writeln('${item.qty}x ${item.name}');
      buffer.writeln('   @$itemPrice = $itemTotal');
      if (item.notes.isNotEmpty) {
        buffer.writeln('   _(Catatan: ${item.notes})_');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Subtotal       : ${_currencyFormat.format(order.subtotal)}');
    buffer.writeln('TOTAL TAGIHAN  : *${_currencyFormat.format(order.total)}*');
    if (order.paidAmount > 0) {
      buffer.writeln('Sudah Dibayar  : ${_currencyFormat.format(order.paidAmount)}');
      buffer.writeln('Sisa Pelunasan : *${_currencyFormat.format(order.remainingAmount)}*');
    }

    String methodLabel = 'TUNAI';
    if (paymentMethod == 'qris') methodLabel = 'QRIS';
    if (paymentMethod == 'debt') methodLabel = 'KASBON';

    buffer.writeln('Metode Bayar   : $methodLabel');
    if (paymentMethod == 'cash') {
      buffer.writeln('Bayar Tunai    : ${_currencyFormat.format(amountPaid)}');
      buffer.writeln('Kembalian      : ${_currencyFormat.format(change)}');
    }

    buffer.writeln('================================');
    buffer.writeln(receiptFooter ??
        'Terima kasih telah berkunjung di $storeName! Selamat menikmati.');

    return buffer.toString();
  }

  /// Membuat teks rincian saldo dan tagihan kasbon pelanggan
  static String generateDebtMessage({
    required String storeName,
    required CustomerModel customer,
    required int latestTransactionAmount,
    String? dueDate,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📋 *$storeName - RINCIAN KASBON*');
    buffer.writeln('Yth. *${customer.name}*,');
    buffer.writeln('Berikut ringkasan saldo kasbon Anda per ${_formatDateTime(DateTime.now())} WIB:');
    buffer.writeln('--------------------------------');
    if (latestTransactionAmount > 0) {
      buffer.writeln('Transaksi Terakhir : ${_currencyFormat.format(latestTransactionAmount)}');
    }
    buffer.writeln('Total Saldo Kasbon : *${_currencyFormat.format(customer.totalDebt)}*');
    buffer.writeln('Batas Limit Kasbon : ${_currencyFormat.format(customer.debtLimit)}');
    if (dueDate != null && dueDate.isNotEmpty) {
      buffer.writeln('Perkiraan Tempo    : $dueDate');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Mohon pelunasan dapat dilakukan pada kunjungan berikutnya. Terima kasih atas kerja samanya!');

    return buffer.toString();
  }

  /// Membuat format teks laporan penutupan kasir harian (End of Day Closing Report)
  /// yang dikirimkan secara formal kepada WhatsApp Owner
  static String formatEodReportMessage({
    required String storeName,
    required SalesSummary summary,
    required String cashierName,
    required DateTime closingTime,
    String? shiftName,
    String? note,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('   📊 *LAPORAN TUTUP KASIR (END OF DAY)*');
    buffer.writeln('            *$storeName*');
    buffer.writeln('========================================');
    buffer.writeln('Tanggal    : ${_formatDateOnly(closingTime)}');
    buffer.writeln('Waktu Tutup: ${_formatTimeOnly(closingTime)} WIB');
    buffer.writeln('Kasir Duty : $cashierName');
    if (shiftName != null && shiftName.isNotEmpty) {
      buffer.writeln('Shift      : $shiftName');
    }
    buffer.writeln('');
    buffer.writeln('📈 *RINGKASAN PENJUALAN:*');
    buffer.writeln('• Total Transaksi : ${summary.transactionCount} Transaksi');
    buffer.writeln('• Total Omzet     : ${_currencyFormat.format(summary.totalRevenue)}');
    if (summary.totalDiscount > 0) {
      buffer.writeln('• Total Diskon    : ${_currencyFormat.format(summary.totalDiscount)}');
    }
    buffer.writeln('• Omzet Bersih    : *${_currencyFormat.format(summary.netRevenue)}*');
    buffer.writeln('• Estimasi HPP    : ${_currencyFormat.format(summary.totalCogs)}');
    buffer.writeln('• Estimasi Laba   : *${_currencyFormat.format(summary.grossProfit)}* (${summary.profitMargin.toStringAsFixed(1)}%)');
    buffer.writeln('• Rata-rata/Meja  : ${_currencyFormat.format(summary.averageOrderValue.round())}');
    buffer.writeln('');
    buffer.writeln('💵 *RINCIAN PEMBAYARAN KASIR:*');
    buffer.writeln('• Uang Tunai (Laci): *${_currencyFormat.format(summary.cashTotal)}* _[Fisik Laci]_');
    buffer.writeln('• QRIS Masuk       : ${_currencyFormat.format(summary.qrisTotal)} _[Rekening Toko]_');
    if (summary.debtTotal > 0) {
      buffer.writeln('• Kasbon Pelanggan : ${_currencyFormat.format(summary.debtTotal)} _[Piutang]_');
    }
    buffer.writeln('');
    if (summary.topSellingItems.isNotEmpty) {
      buffer.writeln('🏆 *TOP MENU TERLARIS:*');
      final topItems = summary.topSellingItems.take(5).toList();
      for (int i = 0; i < topItems.length; i++) {
        final item = topItems[i];
        buffer.writeln('${i + 1}. ${item.name} (${item.qtySold} porsi) - ${_currencyFormat.format(item.totalRevenue)}');
      }
      buffer.writeln('');
    }

    if (note != null && note.trim().isNotEmpty) {
      buffer.writeln('📝 *Catatan Kasir:*');
      buffer.writeln(note.trim());
      buffer.writeln('');
    }

    buffer.writeln('========================================');
    buffer.writeln('_Laporan ini dibuat otomatis oleh Sistem POS Resto Digital_');

    return buffer.toString();
  }
}
