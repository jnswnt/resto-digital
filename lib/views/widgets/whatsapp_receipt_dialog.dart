import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../models/order_model.dart';
import '../../models/settings_model.dart';
import '../../services/whatsapp_service.dart';
import '../../services/image_download_helper.dart';
import '../../theme/app_theme.dart';
import 'live_receipt_paper.dart';

/// ============================================================================
/// DIALOG PRATINJAU NOTA DIGITAL & PENGIRIMAN VIA WHATSAPP (GAMBAR & TEKS)
/// ============================================================================
/// Menggantikan dialog teks konvensional dengan tampilan Nota Digital fisik nyata
/// (sama persis dengan Panel Live Nota Kasir POS).
/// Mendukung ekspor instan ke Gambar PNG beresolusi tinggi untuk dikirimkan
/// ke pelanggan melalui WhatsApp atau disimpan ke galeri/perangkat.
/// ============================================================================

class WhatsappReceiptDialog extends StatefulWidget {
  final String initialPhone;
  final String receiptMessage;
  final VoidCallback? onPrintThermal;
  final SettingsModel? settings;
  final OrderModel? order;
  final String? receiptNo;
  final String? cashierName;
  final String? paymentMethod;
  final int? amountPaid;
  final int? change;
  final DateTime? orderTime;

  const WhatsappReceiptDialog({
    super.key,
    this.initialPhone = '',
    this.receiptMessage = '',
    this.onPrintThermal,
    this.settings,
    this.order,
    this.receiptNo,
    this.cashierName,
    this.paymentMethod,
    this.amountPaid,
    this.change,
    this.orderTime,
  });

  @override
  State<WhatsappReceiptDialog> createState() => _WhatsappReceiptDialogState();
}

class _WhatsappReceiptDialogState extends State<WhatsappReceiptDialog> {
  late final TextEditingController _phoneController;
  final GlobalKey _receiptCaptureKey = GlobalKey();
  bool _isProcessingImage = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Meng-capture widget nota menjadi byte gambar PNG beresolusi tinggi (HD)
  Future<Uint8List?> _captureReceiptPng() async {
    try {
      final boundary =
          _receiptCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      // Gunakan pixelRatio 2.5 untuk hasil gambar struk yang sangat jernih dan tajam
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[WhatsappReceiptDialog] Gagal meng-capture gambar nota: $e');
      return null;
    }
  }

  /// Mengunduh gambar nota digital ke perangkat kasir / pelanggan
  Future<void> _downloadReceiptImage() async {
    setState(() => _isProcessingImage = true);
    final pngBytes = await _captureReceiptPng();
    setState(() => _isProcessingImage = false);

    if (pngBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat gambar nota. Silakan coba lagi.')),
        );
      }
      return;
    }

    final safeNo = (widget.receiptNo ?? 'TRANSAKSI').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Nota_Digital_$safeNo.png';

    final success = await saveOrDownloadImageCrossPlatform(
      bytes: pngBytes,
      fileName: fileName,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gambar nota digital ($fileName) berhasil diunduh! 📥'),
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengunduhan gambar tidak didukung di browser ini.')),
        );
      }
    }
  }

  /// Menyalin gambar nota langsung ke clipboard sistem (agar kasir tinggal Ctrl+V di WhatsApp)
  Future<void> _copyReceiptImageToClipboard() async {
    setState(() => _isProcessingImage = true);
    final pngBytes = await _captureReceiptPng();
    setState(() => _isProcessingImage = false);

    if (pngBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyalin gambar nota.')),
        );
      }
      return;
    }

    final copied = await copyImageToClipboardCrossPlatform(pngBytes);

    if (mounted) {
      if (copied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar Nota Digital berhasil disalin ke clipboard! 📋 (Tinggal Paste/Ctrl+V di chat WhatsApp)'),
            backgroundColor: AppTheme.emeraldGreen,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        // Fallback jika API clipboard gambar browser belum aktif
        await _downloadReceiptImage();
      }
    }
  }

  /// Membuka WhatsApp ke nomor pelanggan dengan gambar nota terunduh/tersalin dan pesan pengantar resmi
  Future<void> _sendWhatsAppWithImagePrompt() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp pelanggan belum diisi!')),
      );
      return;
    }

    setState(() => _isSending = true);

    // 1. Salin gambar nota ke clipboard dan unduh otomatis file gambarnya
    final pngBytes = await _captureReceiptPng();
    if (pngBytes != null) {
      await copyImageToClipboardCrossPlatform(pngBytes);
      final safeNo = (widget.receiptNo ?? 'TRX').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await saveOrDownloadImageCrossPlatform(
        bytes: pngBytes,
        fileName: 'Nota_Digital_$safeNo.png',
      );
    }

    // 2. Format pesan pengantar WhatsApp yang elegan untuk nota bergambar
    final storeName = widget.settings?.storeName ?? 'Resto Digital';
    final custName = widget.order?.customerName ?? 'Pelanggan';
    final receiptNoStr = widget.receiptNo ?? '-';
    final totalStr = widget.order != null
        ? 'Rp ${widget.order!.total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'
        : '';

    final captionBuffer = StringBuffer();
    captionBuffer.writeln('Halo Kak *$custName*, terima kasih telah berkunjung ke *$storeName*! 🙏✨');
    captionBuffer.writeln('');
    captionBuffer.writeln('Berikut kami lampirkan *Nota Digital* untuk pesanan Anda:');
    captionBuffer.writeln('🧾 *No. Nota* : #$receiptNoStr');
    if (totalStr.isNotEmpty) {
      captionBuffer.writeln('💰 *Total*   : $totalStr');
    }
    captionBuffer.writeln('');
    captionBuffer.writeln('_(Nota digital berbentuk gambar telah kami siapkan, silakan kirimkan gambar nota ini kepada pelanggan)_');
    if (widget.settings?.receiptFooter.isNotEmpty == true) {
      captionBuffer.writeln('');
      captionBuffer.writeln(widget.settings!.receiptFooter);
    }

    // 3. Buka WhatsApp
    final success = await WhatsappService.openWhatsApp(
      phone: phone,
      message: captionBuffer.toString(),
    );

    setState(() => _isSending = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan browser atau aplikasi tersedia.')),
      );
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E202B) : Colors.white;

    final effectiveSettings = widget.settings ?? SettingsModel();
    final effectiveOrder = widget.order ??
        OrderModel(
          id: widget.receiptNo ?? 'ord_demo',
          shiftId: 'shift_active',
          items: [],
          paidAmount: 0,
        );
    final effectiveReceiptNo = widget.receiptNo ?? 'TRX-001';
    final effectiveTime = widget.orderTime ?? DateTime.now();
    final effectiveCashier = widget.cashierName ?? 'Kasir Resto';
    final effectivePayment = widget.paymentMethod ?? 'Tunai';
    final effectivePaid = widget.amountPaid ?? effectiveOrder.total;
    final effectiveChange = widget.change ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==============================================================
              // HEADER DIALOG
              // ==============================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.successGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nota Digital (WhatsApp)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Kirimkan nota bergambar kepada pelanggan atau cetak fisik',
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ==============================================================
              // ISI DIALOG: INPUT NO WA & PRATINJAU NOTA GAMBAR
              // ==============================================================
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Input Nomor WhatsApp
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Nomor WhatsApp Pelanggan',
                          hintText: 'Contoh: 081234567890',
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: AppTheme.successGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Baris Keterangan Preview & Tombol Cepat
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image_outlined, size: 16, color: AppTheme.primaryAmber),
                              const SizedBox(width: 6),
                              Text(
                                'Pratinjau Nota Digital:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          // Tombol Salin Gambar Cepat
                          TextButton.icon(
                            onPressed: _isProcessingImage ? null : _copyReceiptImageToClipboard,
                            icon: _isProcessingImage
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Salin Gambar', style: TextStyle(fontSize: 11.5)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // KERTAS STRUK THERMAL (LIVE NOTA PERSIS SEPERTI DI KASIR POS)
                      Center(
                        child: RepaintBoundary(
                          key: _receiptCaptureKey,
                          child: LiveReceiptPaper(
                            settings: effectiveSettings,
                            order: effectiveOrder,
                            receiptNo: effectiveReceiptNo,
                            orderTime: effectiveTime,
                            cashierName: effectiveCashier,
                            paymentMethod: effectivePayment,
                            amountPaid: effectivePaid,
                            change: effectiveChange,
                            isSample: false,
                            statusBadgeText: 'LUNAS',
                            statusBadgeColor: AppTheme.emeraldGreen,
                            forceLightMode: true, // Nota digital putih bersih agar sempurna saat dikirim ke WA
                            showNotch: true,
                            showSawtooth: true,
                            width: 350,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // ==============================================================
              // FOOTER TOMBOL AKSI
              // ==============================================================
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    // Tombol Unduh File Gambar PNG
                    OutlinedButton.icon(
                      onPressed: _isProcessingImage ? null : _downloadReceiptImage,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Unduh Gambar (PNG)', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // Tombol Cetak Fisik Thermal
                    if (widget.onPrintThermal != null)
                      OutlinedButton.icon(
                        onPressed: widget.onPrintThermal,
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Cetak Struk', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppTheme.primaryAmber : Colors.orange.shade900,
                          side: BorderSide(
                            color: isDark ? AppTheme.primaryAmber : Colors.orange.shade800,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                    // Tombol Utama: Kirim ke WhatsApp
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendWhatsAppWithImagePrompt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'Kirim via WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
