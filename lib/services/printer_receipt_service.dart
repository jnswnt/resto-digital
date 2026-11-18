import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/settings_model.dart';
import '../theme/app_theme.dart';
import '../views/widgets/live_receipt_paper.dart';
import 'image_download_helper.dart';
import 'printer_helper.dart';

/// Layanan Pembuatan Struk Kasir & Pengendalian Cetak Thermal POS.
/// Mendukung format teks ASCII monospaced untuk printer 58mm (32 kolom) & 80mm (48 kolom),
/// serta format HTML cetak thermal cross-platform (Web browser print & dialog pratinjau).
class PrinterReceiptService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Menghitung lebar kolom karakter berdasarkan ukuran kertas yang dipilih
  static int getColumnWidth(String paperSize) {
    return paperSize == '80mm' ? 48 : 32;
  }

  /// Format teks rata tengah (Center align)
  static String centerText(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final leftPadding = (width - text.length) ~/ 2;
    final rightPadding = width - text.length - leftPadding;
    return ' ' * leftPadding + text + ' ' * rightPadding;
  }

  /// Format teks rata kiri dan rata kanan (Left-Right align)
  static String twoColumnText(String left, String right, int width) {
    final available = width - right.length;
    if (available <= 0) {
      return '$left $right';
    }
    if (left.length > available - 1) {
      left = left.substring(0, available - 1);
    }
    return left.padRight(available) + right;
  }

  /// Garis pembatas putus-putus atau garis ganda
  static String dividerLine(int width, [String char = '-']) {
    return char * width;
  }

  /// Menghasilkan representasi string teks struk thermal monospaced
  static String buildTextReceipt({
    required SettingsModel settings,
    required OrderModel order,
    required String receiptNo,
    required DateTime orderTime,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    bool isSample = false,
  }) {
    final width = getColumnWidth(settings.paperSize);
    final buffer = StringBuffer();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(orderTime);

    // 1. Header Toko
    buffer.writeln(dividerLine(width, '='));
    buffer.writeln(centerText(settings.storeName.toUpperCase(), width));
    if (settings.address.isNotEmpty) {
      buffer.writeln(centerText(settings.address, width));
    }
    if (settings.phoneWA.isNotEmpty) {
      buffer.writeln(centerText('Telp/WA: ${settings.phoneWA}', width));
    }
    if (settings.receiptHeader.isNotEmpty) {
      buffer.writeln(centerText(settings.receiptHeader, width));
    }
    buffer.writeln(dividerLine(width, '='));

    // 2. Info Transaksi & Kasir
    buffer.writeln(twoColumnText('No. Struk:', '#$receiptNo', width));
    buffer.writeln(twoColumnText('Tanggal  :', timeStr, width));
    if (settings.showCashierName && cashierName.isNotEmpty) {
      buffer.writeln(twoColumnText('Kasir    :', cashierName, width));
    }

    if (settings.showCustomerInfo) {
      if (order.tableNo != null && order.tableNo!.isNotEmpty) {
        final tableLabel = order.tableNo!.startsWith('Meja')
            ? order.tableNo!
            : 'Meja ${order.tableNo}';
        buffer.writeln(twoColumnText('Lokasi   :', tableLabel, width));
      }
      if (order.customerName.isNotEmpty && order.customerName != 'Pelanggan Umum') {
        buffer.writeln(twoColumnText('Pelanggan:', order.customerName, width));
      }
    }
    buffer.writeln(dividerLine(width, '-'));

    // 3. Header Kolom Menu
    buffer.writeln(twoColumnText('Item Pesanan', 'Total', width));
    buffer.writeln(dividerLine(width, '-'));

    // 4. Daftar Item Pesanan
    int totalQty = 0;
    for (final item in order.items) {
      totalQty += item.qty;
      final itemTotalStr = _currencyFormat.format(item.price * item.qty);
      // Baris nama menu
      buffer.writeln(item.name);
      // Baris Qty x Harga dan Subtotal
      final qtyPriceStr = '  ${item.qty} x ${_currencyFormat.format(item.price)}';
      buffer.writeln(twoColumnText(qtyPriceStr, itemTotalStr, width));

      // Catatan khusus per menu jika diaktifkan
      if (settings.showOrderNotes && item.notes.isNotEmpty) {
        buffer.writeln('  * [${item.notes}]');
      }
    }
    buffer.writeln(dividerLine(width, '-'));

    // 5. Total dan Pembayaran
    buffer.writeln(twoColumnText('Subtotal ($totalQty item):', _currencyFormat.format(order.subtotal), width));
    if (order.discountAmount > 0) {
      final discLabel = order.discountPercent > 0
          ? 'Diskon (${order.discountPercent.toStringAsFixed(0)}%):'
          : 'Diskon Transaksi:';
      buffer.writeln(twoColumnText(discLabel, '-${_currencyFormat.format(order.discountAmount)}', width));
    }
    if (order.serviceChargeAmount > 0) {
      buffer.writeln(twoColumnText('Biaya Layanan:', _currencyFormat.format(order.serviceChargeAmount), width));
    }
    if (order.taxAmount > 0) {
      final taxLabel = 'Pajak Resto (${settings.taxPercentage.toStringAsFixed(0)}%):';
      buffer.writeln(twoColumnText(taxLabel, _currencyFormat.format(order.taxAmount), width));
    }
    buffer.writeln(dividerLine(width, '-'));
    buffer.writeln(twoColumnText('TOTAL AKHIR:', _currencyFormat.format(order.total), width));
    if (order.paidAmount > 0 && order.paidAmount < order.total) {
      buffer.writeln(twoColumnText('Uang Muka (QRIS):', '-${_currencyFormat.format(order.paidAmount)}', width));
      buffer.writeln(twoColumnText('Sisa Tagihan:', _currencyFormat.format(order.total - order.paidAmount), width));
    }
    buffer.writeln(twoColumnText('Metode Bayar:', paymentMethod.toUpperCase(), width));
    buffer.writeln(twoColumnText('Uang Diterima:', _currencyFormat.format(amountPaid), width));
    buffer.writeln(twoColumnText('Kembalian:', _currencyFormat.format(change), width));
    buffer.writeln(dividerLine(width, '='));

    // 6. Barcode Simulasi (jika diaktifkan)
    if (settings.showQrFooter) {
      buffer.writeln(centerText('||| | || |||| | ||| || |||', width));
      buffer.writeln(centerText('*$receiptNo*', width));
      buffer.writeln(dividerLine(width, '-'));
    }

    // 7. Footer Struk
    if (settings.receiptFooter.isNotEmpty) {
      buffer.writeln(centerText(settings.receiptFooter, width));
    }
    if (isSample) {
      buffer.writeln(centerText('** STRUK SAMPEL UJI COBA **', width));
    }
    buffer.writeln(dividerLine(width, '='));
    buffer.writeln('\n\n'); // Feed kertas untuk printer thermal

    return buffer.toString();
  }

  /// Menghasilkan format dokumen HTML siap cetak untuk printer thermal (58mm/80mm)
  static String buildHtmlReceipt({
    required SettingsModel settings,
    required OrderModel order,
    required String receiptNo,
    required DateTime orderTime,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    bool isSample = false,
  }) {
    final widthMm = settings.paperSize == '80mm' ? '80mm' : '58mm';
    final fontSize = settings.paperSize == '80mm' ? '12px' : '10.5px';
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(orderTime);

    final itemsHtml = StringBuffer();
    int totalQty = 0;
    for (final item in order.items) {
      totalQty += item.qty;
      final itemTotalStr = _currencyFormat.format(item.price * item.qty);
      itemsHtml.writeln('''
        <div style="margin-top: 4px; font-weight: bold;">${item.name}</div>
        <div style="display: flex; justify-content: space-between;">
          <span>&nbsp;&nbsp;${item.qty} x ${_currencyFormat.format(item.price)}</span>
          <span>$itemTotalStr</span>
        </div>
      ''');
      if (settings.showOrderNotes && item.notes.isNotEmpty) {
        itemsHtml.writeln('''
          <div style="font-size: 85%; font-style: italic; color: #444; margin-left: 8px;">* [${item.notes}]</div>
        ''');
      }
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Struk #$receiptNo</title>
  <style>
    @page {
      size: $widthMm auto;
      margin: 0;
    }
    body {
      font-family: 'Courier New', Courier, monospace;
      font-size: $fontSize;
      line-height: 1.3;
      margin: 0;
      padding: 6px 8px;
      color: #000;
      background: #fff;
      width: $widthMm;
      box-sizing: border-box;
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    .divider-double { border-top: 2px dashed #000; margin: 6px 0; }
    .divider-single { border-top: 1px dashed #000; margin: 4px 0; }
    .row { display: flex; justify-content: space-between; }
    .barcode {
      font-family: 'Courier New', Courier, monospace;
      letter-spacing: 2px;
      font-weight: 900;
      font-size: 14px;
      margin-top: 4px;
    }
  </style>
</head>
<body>
  <div class="divider-double"></div>
  <div class="text-center bold" style="font-size: 120%;">${settings.storeName}</div>
  ${settings.address.isNotEmpty ? '<div class="text-center">${settings.address}</div>' : ''}
  ${settings.phoneWA.isNotEmpty ? '<div class="text-center">Telp/WA: ${settings.phoneWA}</div>' : ''}
  ${settings.receiptHeader.isNotEmpty ? '<div class="text-center" style="font-style: italic; margin-top: 2px;">${settings.receiptHeader}</div>' : ''}
  <div class="divider-double"></div>

  <div class="row"><span>No. Struk:</span><span class="bold">#$receiptNo</span></div>
  <div class="row"><span>Tanggal  :</span><span>$timeStr</span></div>
  ${settings.showCashierName && cashierName.isNotEmpty ? '<div class="row"><span>Kasir    :</span><span>$cashierName</span></div>' : ''}
  ${settings.showCustomerInfo && order.tableNo != null && order.tableNo!.isNotEmpty ? '<div class="row"><span>Lokasi   :</span><span class="bold">${order.tableNo}</span></div>' : ''}
  ${settings.showCustomerInfo && order.customerName.isNotEmpty && order.customerName != 'Pelanggan Umum' ? '<div class="row"><span>Tamu     :</span><span>${order.customerName}</span></div>' : ''}

  <div class="divider-single"></div>
  <div class="row bold"><span>Item Pesanan</span><span>Total</span></div>
  <div class="divider-single"></div>

  $itemsHtml

  <div class="divider-single"></div>
  <div class="row"><span>Subtotal ($totalQty item):</span><span>${_currencyFormat.format(order.subtotal)}</span></div>
  ${order.discountAmount > 0 ? '''
  <div class="row" style="color: #dc2626;">
    <span>Diskon ${order.discountPercent > 0 ? '(${order.discountPercent.toStringAsFixed(0)}%)' : ''}:</span>
    <span>-${_currencyFormat.format(order.discountAmount)}</span>
  </div>
  ''' : ''}
  ${order.serviceChargeAmount > 0 ? '''
  <div class="row">
    <span>Biaya Layanan:</span>
    <span>${_currencyFormat.format(order.serviceChargeAmount)}</span>
  </div>
  ''' : ''}
  ${order.taxAmount > 0 ? '''
  <div class="row">
    <span>Pajak Resto (${settings.taxPercentage.toStringAsFixed(0)}%):</span>
    <span>${_currencyFormat.format(order.taxAmount)}</span>
  </div>
  ''' : ''}
  <div class="divider-single"></div>
  <div class="row bold" style="font-size: 110%;">
    <span>TOTAL TAGIHAN:</span>
    <span>${_currencyFormat.format(order.total)}</span>
  </div>
  ${order.paidAmount > 0 && order.paidAmount < order.total ? '''
  <div class="row" style="color: #0284c7;">
    <span>Uang Muka (QRIS):</span>
    <span>-${_currencyFormat.format(order.paidAmount)}</span>
  </div>
  <div class="row bold">
    <span>Sisa Tagihan:</span>
    <span>${_currencyFormat.format(order.total - order.paidAmount)}</span>
  </div>
  ''' : ''}
  <div class="row"><span>Metode Bayar:</span><span class="bold">${paymentMethod.toUpperCase()}</span></div>
  <div class="row"><span>Diterima:</span><span>${_currencyFormat.format(amountPaid)}</span></div>
  <div class="row"><span>Kembalian:</span><span>${_currencyFormat.format(change)}</span></div>
  <div class="divider-double"></div>

  ${settings.showQrFooter ? '''
    <div class="text-center barcode">||| | || |||| | ||| || |||</div>
    <div class="text-center" style="font-size: 80%;">*$receiptNo*</div>
    <div class="divider-single"></div>
  ''' : ''}

  ${settings.receiptFooter.isNotEmpty ? '<div class="text-center" style="margin-top: 4px;">${settings.receiptFooter}</div>' : ''}
  ${isSample ? '<div class="text-center bold" style="margin-top: 4px;">** STRUK SAMPEL UJI COBA **</div>' : ''}
  <div class="divider-double"></div>
  <div style="height: 18px;"></div>
</body>
</html>
''';
  }

  /// Eksekusi langsung cetak struk (memanggil browser print atau driver thermal)
  static void printReceiptDirect({
    required SettingsModel settings,
    required OrderModel order,
    required String receiptNo,
    required DateTime orderTime,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    bool isSample = false,
  }) {
    final html = buildHtmlReceipt(
      settings: settings,
      order: order,
      receiptNo: receiptNo,
      orderTime: orderTime,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      change: change,
      isSample: isSample,
    );

    // Cetak sebanyak jumlah rangkap yang dikonfigurasi
    final copies = settings.numberOfCopies.clamp(1, 3);
    for (int i = 0; i < copies; i++) {
      printThermalHtmlCrossPlatform(html);
    }
  }

  /// Menghasilkan contoh data order untuk uji coba cetak struk sampel
  static OrderModel generateSampleOrder() {
    return OrderModel(
      id: 'ord_sample',
      shiftId: 'shift_active',
      tableNo: 'Meja 08',
      customerName: 'Kak Budi (Tamu)',
      items: [
        OrderItem(
          productId: 'prod_1',
          name: 'Nasi Goreng Spesial Resto',
          price: 25000,
          qty: 2,
          notes: 'Pedas sedang, telor ceplok setengah matang',
        ),
        OrderItem(
          productId: 'prod_2',
          name: 'Es Teh Manis Jumbo',
          price: 6000,
          qty: 2,
          notes: 'Gula sedikit',
        ),
        OrderItem(
          productId: 'prod_3',
          name: 'Tahu Crispy Cabai Garam',
          price: 15000,
          qty: 1,
        ),
      ],
      paidAmount: 77000,
      createdAt: DateTime.now(),
    );
  }

  /// Membuka dialog modal Pratinjau Struk Thermal POS interaktif (Live Nota Visual)
  static void showReceiptPreviewDialog(
    BuildContext context, {
    required SettingsModel settings,
    required OrderModel order,
    required String receiptNo,
    required DateTime orderTime,
    required String cashierName,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    bool isSample = false,
  }) {
    final receiptText = buildTextReceipt(
      settings: settings,
      order: order,
      receiptNo: receiptNo,
      orderTime: orderTime,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      change: change,
      isSample: isSample,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final is80mm = settings.paperSize == '80mm';
    final receiptKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: is80mm ? 480 : 420,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E202B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Dialog
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppTheme.emeraldGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSample ? 'Pratinjau Struk Uji Coba' : 'Pratinjau Nota Digital',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Format Live Nota Thermal ${settings.paperSize.toUpperCase()} (${settings.printerType.toUpperCase()})',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Area Kertas Struk Thermal Live Nota
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Center(
                      child: RepaintBoundary(
                        key: receiptKey,
                        child: LiveReceiptPaper(
                          settings: settings,
                          order: order,
                          receiptNo: receiptNo,
                          orderTime: orderTime,
                          cashierName: cashierName,
                          paymentMethod: paymentMethod,
                          amountPaid: amountPaid,
                          change: change,
                          isSample: isSample,
                          forceLightMode: false,
                          showNotch: true,
                          showSawtooth: true,
                          width: is80mm ? 380 : 330,
                        ),
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Tombol Aksi
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      // Tombol Unduh Gambar Nota PNG
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final boundary = receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                            if (boundary != null) {
                              final image = await boundary.toImage(pixelRatio: 2.5);
                              final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                              if (byteData != null) {
                                final pngBytes = byteData.buffer.asUint8List();
                                await saveOrDownloadImageCrossPlatform(
                                  bytes: pngBytes,
                                  fileName: 'Nota_${receiptNo.replaceAll(' ', '_')}.png',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Gambar nota digital berhasil diunduh! 📥'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: AppTheme.emeraldGreen,
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            debugPrint('Gagal unduh gambar nota: $e');
                          }
                        },
                        icon: const Icon(Icons.image_rounded, size: 16),
                        label: const Text('Unduh Gambar', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // Tombol Salin Teks
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: receiptText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Teks struk berhasil disalin ke clipboard! 📋'),
                              duration: Duration(seconds: 2),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Salin Teks', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // Tombol Cetak Sekarang
                      ElevatedButton.icon(
                        onPressed: () {
                          printReceiptDirect(
                            settings: settings,
                            order: order,
                            receiptNo: receiptNo,
                            orderTime: orderTime,
                            cashierName: cashierName,
                            paymentMethod: paymentMethod,
                            amountPaid: amountPaid,
                            change: change,
                            isSample: isSample,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mengirim ${settings.numberOfCopies}x struk ke printer (${settings.paperSize})... 🖨️'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 17),
                        label: const Text('Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
