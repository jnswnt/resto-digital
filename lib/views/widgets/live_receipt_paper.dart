import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/settings_model.dart';
import '../../theme/app_theme.dart';

/// ============================================================================
/// KOMPONEN VISUAL KERTAS STRUK THERMAL (LIVE RECEIPT PAPER)
/// ============================================================================
/// Komponen reusable yang menyajikan tampilan fisik nota belanja restoran
/// secara autentik, elegan, dan profesional (sama seperti Panel Live Nota di Kasir POS).
/// Digunakan pada:
/// 1. Panel Kasir POS (Live Nota Cart).
/// 2. Dialog Pratinjau Struk Kasir & Uji Coba Cetak Thermal.
/// 3. Layar Pengaturan Printer (Live Dynamic Receipt Preview).
/// 4. Dialog Pengiriman Nota Digital via WhatsApp (Diekspor ke Gambar PNG).
/// ============================================================================

class LiveReceiptPaper extends StatelessWidget {
  final SettingsModel settings;
  final OrderModel order;
  final String receiptNo;
  final DateTime orderTime;
  final String cashierName;
  final String paymentMethod;
  final int amountPaid;
  final int change;
  final bool isSample;
  final String? statusBadgeText;
  final Color? statusBadgeColor;
  final bool forceLightMode;
  final bool showNotch;
  final bool showSawtooth;
  final double? width;

  const LiveReceiptPaper({
    super.key,
    required this.settings,
    required this.order,
    required this.receiptNo,
    required this.orderTime,
    required this.cashierName,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    this.isSample = false,
    this.statusBadgeText,
    this.statusBadgeColor,
    this.forceLightMode = false,
    this.showNotch = true,
    this.showSawtooth = true,
    this.width,
  });

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final themeIsDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = forceLightMode ? false : themeIsDark;

    // Skema warna kertas struk autentik
    final paperBg = isDark ? const Color(0xFF1E2232) : Colors.white;
    final paperBorder = isDark ? const Color(0xFF2C3246) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF171A26) : const Color(0xFFF8FAFC);
    final dashedColor = isDark ? const Color(0xFF3E455E) : const Color(0xFFCBD5E1);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final totalItemsCount = order.items.fold<int>(0, (sum, i) => sum + i.qty);
    final is80mm = settings.paperSize == '80mm';
    final paperWidth = width ?? (is80mm ? 380.0 : 330.0);
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(orderTime);

    // Teks dan warna badge status
    final badgeText = statusBadgeText ??
        (isSample
            ? 'SAMPEL'
            : (amountPaid >= order.total && order.total > 0 ? 'LUNAS' : 'LIVE NOTA'));
    final badgeColor = statusBadgeColor ??
        (isSample
            ? const Color(0xFFEA580C)
            : (amountPaid >= order.total && order.total > 0
                ? AppTheme.emeraldGreen
                : AppTheme.primaryAmber));
    final showWatermark = isSample ||
        (amountPaid >= order.total && order.total > 0) ||
        statusBadgeText != null;

    return Container(
      width: paperWidth,
      decoration: BoxDecoration(
        color: paperBg,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(16),
          bottom: Radius.circular(showSawtooth ? 0 : 16),
        ),
        border: Border.all(color: paperBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -----------------------------------------------------------------
          // 1. KEPALA STRUK & IDENTITAS TOKO
          // -----------------------------------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              children: [
                if (showNotch) ...[
                  // Notch / Penjepit Rel Struk Logam
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3E455E) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],

                // Nama Restoran di Tengah Struk
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🍽️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          settings.storeName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: is80mm ? 16 : 14.5,
                            letterSpacing: 1.0,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Alamat Toko
                if (settings.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    settings.address,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: textMuted, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Slogan Header Toko
                if (settings.receiptHeader.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    settings.receiptHeader,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textMuted,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Baris Info Kasir, Tanggal & Jam
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (settings.showCashierName)
                      Text(
                        'Kasir: $cashierName',
                        style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w500),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),

                // Baris Info Meja & Nama Tamu
                if (settings.showCustomerInfo &&
                    ((order.tableNo != null && order.tableNo!.isNotEmpty) ||
                        (order.customerName.isNotEmpty && order.customerName != 'Pelanggan'))) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.tableNo != null ? 'Meja: ${order.tableNo}' : 'Pesanan: Takeaway',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        'Tamu: ${order.customerName}',
                        style: TextStyle(fontSize: 10.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Garis Putus-putus Struk
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DashedDivider(color: dashedColor, height: 1.2),
          ),

          // -----------------------------------------------------------------
          // 2. JUDUL KOLOM STRUK (TABLE HEADER NOTA)
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'MENU / PESANAN',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DashedDivider(color: dashedColor, height: 1.2),
          ),

          // -----------------------------------------------------------------
          // 3. DAFTAR ITEM PESANAN NOTA
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < order.items.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: DashedDivider(color: dashedColor.withValues(alpha: 0.35), height: 1),
                    ),
                  _buildReceiptItemRow(order.items[i], textColor, textMuted, isDark),
                ],
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // 4. RINGKASAN TAGIHAN & PEMBAYARAN
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DashedDivider(color: dashedColor, height: 1.5),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Watermark Status Tagihan Miring (SAMPEL / LUNAS) Sebagai Penanda di Belakang Bagian Tagihan
                if (showWatermark)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.22, // Kemiringan stempel watermark (~ -12.5 derajat)
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: badgeColor.withValues(alpha: isDark ? 0.32 : 0.22),
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText.toUpperCase(),
                              style: TextStyle(
                                fontSize: is80mm ? 32 : 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: badgeColor.withValues(alpha: isDark ? 0.32 : 0.22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Konten Rincian Tagihan & Informasi Pembayaran
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Menu / Qty:', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        Text(
                          '${order.items.length} Menu ($totalItemsCount Pcs)',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal Tagihan:', style: TextStyle(fontSize: 11, color: textMuted)),
                        Text(
                          _currencyFormat.format(order.subtotal),
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),

                    // Jika ada pembayaran uang muka QRIS sebelumnya
                    if (order.paidAmount > 0 && order.paidAmount < order.total) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Uang Muka QRIS (Lunas):',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '- ${_currencyFormat.format(order.paidAmount)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 7),
                    // Garis tebal penutup total
                    DashedDivider(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), height: 1.8),
                    const SizedBox(height: 7),

                    // TOTAL TAGIHAN UTAMA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL TAGIHAN:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: textColor,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(order.total),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppTheme.primaryAmber : const Color(0xFFEA580C),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),
                    DashedDivider(color: dashedColor.withValues(alpha: 0.45), height: 1),
                    const SizedBox(height: 7),

                    // METODE BAYAR, DITERIMA, KEMBALIAN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Metode Bayar:', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        Text(
                          paymentMethod.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bayar / Diterima:', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        Text(
                          _currencyFormat.format(amountPaid),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kembalian:', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        Text(
                          _currencyFormat.format(change),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: change > 0 ? AppTheme.emeraldGreen : textColor,
                          ),
                        ),
                      ],
                    ),

                    // Pesan Footer Resto
                    if (settings.receiptFooter.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        settings.receiptFooter,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: textMuted),
                      ),
                    ],

                    // Barcode Simulasi Thermal
                    if (settings.showQrFooter) ...[
                      const SizedBox(height: 8),
                      _buildThermalBarcode(isDark, textMuted, receiptNo),
                    ],

                    const SizedBox(height: 4),
                    Text(
                      '*** TERIMA KASIH - ${settings.storeName.toUpperCase()} ***',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // 5. EFEK SOBEKAN GERIGI KERTAS STRUK (SAWTOOTH PAPER TEAR)
          // -----------------------------------------------------------------
          if (showSawtooth)
            CustomPaint(
              size: const Size(double.infinity, 6),
              painter: SawtoothPainter(
                color: paperBg,
                triangleWidth: 10,
                triangleHeight: 6,
              ),
            ),
        ],
      ),
    );
  }

  /// Membangun Baris Item Menu individual pada kertas struk
  Widget _buildReceiptItemRow(
    OrderItem item,
    Color textColor,
    Color textMuted,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama Menu
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Qty
            SizedBox(
              width: 45,
              child: Text(
                '${item.qty}x',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
            // Total Harga Menu
            SizedBox(
              width: 75,
              child: Text(
                _currencyFormat.format(item.total),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        // Rincian Harga Satuan
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '@ ${_currencyFormat.format(item.price)}',
            style: TextStyle(fontSize: 10, color: textMuted),
          ),
        ),
        // Catatan Khusus Modifiers
        if (settings.showOrderNotes && item.notes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '↳ Catatan: ${item.notes}',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFFFCD34D) : Colors.brown.shade700,
            ),
          ),
        ],
      ],
    );
  }

  /// Generator Barcode Dekoratif Struk Thermal
  Widget _buildThermalBarcode(bool isDark, Color textMuted, String no) {
    final barColor = isDark ? const Color(0xFF64748B) : const Color(0xFF334155);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(42, (idx) {
            final isThick = idx % 3 == 0 || idx % 7 == 0;
            final isSpace = idx % 5 == 0 && idx % 2 != 0;

            if (isSpace) return const SizedBox(width: 3.5);

            return Container(
              width: isThick ? 2.5 : 1.2,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              color: barColor,
            );
          }),
        ),
        const SizedBox(height: 3),
        Text(
          '* #$no *',
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

/// Widget Garis Putus-putus Struk Thermal (Dashed Divider)
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1.0,
    this.color = const Color(0xFF6B7280),
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        if (!boxWidth.isFinite || boxWidth <= 0) {
          return Divider(height: height, color: color);
        }
        final count = (boxWidth / (dashWidth + dashSpace)).floor();
        return SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// CustomPainter untuk menghasilkan efek gerigi sobekan kertas struk (Sawtooth Paper Tear)
class SawtoothPainter extends CustomPainter {
  final Color color;
  final double triangleWidth;
  final double triangleHeight;

  SawtoothPainter({
    required this.color,
    this.triangleWidth = 10,
    this.triangleHeight = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    double x = 0;
    while (x < size.width) {
      path.lineTo(x + triangleWidth / 2, triangleHeight);
      path.lineTo(x + triangleWidth, 0);
      x += triangleWidth;
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
