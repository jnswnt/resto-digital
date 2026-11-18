import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../services/qris_service.dart';
import '../../theme/app_theme.dart';

/// Halaman Sub Menu Khusus: Konfigurasi QRIS Toko (Statis & Dinamis)
class QrisConfigScreen extends StatefulWidget {
  const QrisConfigScreen({super.key});

  @override
  State<QrisConfigScreen> createState() => _QrisConfigScreenState();
}

class _QrisConfigScreenState extends State<QrisConfigScreen> {
  late final TextEditingController _qrisCtrl;
  bool _isDecoding = false;
  int _testAmount = 10000;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _qrisCtrl = TextEditingController(text: settings.qrisPayload);
  }

  @override
  void dispose() {
    _qrisCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndDecodeImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file == null) return;

      setState(() => _isDecoding = true);

      final bytes = await file.readAsBytes();
      final decodedPayload = await QrisService.decodeQrFromImageBytes(bytes);

      if (!mounted) return;

      if (decodedPayload != null && decodedPayload.isNotEmpty) {
        final info = QrisService.parseMerchantInfo(decodedPayload);
        if (info.isValid) {
          setState(() {
            _qrisCtrl.text = decodedPayload;
          });
          final settingsProvider = context.read<SettingsProvider>();
          final onlineProvider = context.read<OnlineOrderProvider>();
          await settingsProvider.updateQrisPayload(decodedPayload);
          final storeName = settingsProvider.settings.storeName;
          final synced = await onlineProvider.syncQrisConfig(decodedPayload, storeName);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: synced ? AppTheme.emeraldGreen : Colors.teal.shade700,
                duration: const Duration(seconds: 4),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        synced
                            ? 'QRIS Terpasang & Disinkronkan ke Web: ${info.merchantName}'
                            : 'QRIS Berhasil Terbaca: ${info.merchantName}',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar terbaca, namun format QR bukan QRIS merchant resmi yang valid.'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendeteksi barcode QR dari gambar. Pastikan foto QRIS jelas dan tegak.'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kendala saat membaca foto: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDecoding = false);
      }
    }
  }

  Future<void> _saveManualPayload() async {
    final payload = _qrisCtrl.text.trim();
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payload QRIS tidak boleh kosong!')),
      );
      return;
    }

    final info = QrisService.parseMerchantInfo(payload);
    if (!info.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format kode QRIS tidak valid. Pastikan format EMVCo standar diawali "000201...".'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    final onlineProvider = context.read<OnlineOrderProvider>();
    await settingsProvider.updateQrisPayload(payload);
    final storeName = settingsProvider.settings.storeName;
    final synced = await onlineProvider.syncQrisConfig(payload, storeName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'QRIS berhasil disimpan & terhubung ke Web Self-Ordering!'
                : 'QRIS berhasil disimpan secara lokal.',
          ),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final payload = _qrisCtrl.text.trim();
    final info = QrisService.parseMerchantInfo(payload);
    final String dynamicQris = info.isValid
        ? QrisService.generateDynamicQris(rawPayload: payload, amount: _testAmount)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan QRIS Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KARTU METODE CEPAT: SCAN / UPLOAD GAMBAR
                Card(
                  color: isDark ? const Color(0xFF23201A) : Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.primaryAmber.withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryAmber, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Pasang QRIS Otomatis dari Foto',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cukup ambil foto stiker QRIS resmi toko Anda (BCA, Mandiri, BRI, GoPay, Dana, dll). Sistem akan membaca kode otomatis.',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                        const SizedBox(height: 14),
                        if (_isDecoding)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAmber),
                                  SizedBox(width: 10),
                                  Text('Membaca barcode QRIS...', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _pickAndDecodeImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                                  label: const Text('Pilih dari Galeri', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryAmber,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickAndDecodeImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: const Text('Foto Kamera', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryAmber,
                                    side: const BorderSide(color: AppTheme.primaryAmber),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // INFORMASI MERCHANT JIKA VALID
                if (info.isValid) ...[
                  Card(
                    color: isDark ? const Color(0xFF132A24) : const Color(0xFFF0FDF4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.emeraldGreen),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.emeraldGreen, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.merchantName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Acquirer: ${info.acquirerName} • Kota: ${info.merchantCity}',
                                  style: TextStyle(fontSize: 11.5, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // INPUT MANUAL PAYLOAD
                Text('Kode Payload QRIS (EMVCo String):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: _qrisCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '00020101021126570011ID.DANA.WWW...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Salin Kode',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _qrisCtrl.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kode QRIS disalin!')),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _saveManualPayload,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Simpan & Sinkronkan ke Web Meja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // PRATINJAU GENERATOR QRIS DINAMIS
                if (info.isValid && dynamicQris.isNotEmpty) ...[
                  Text('Pratinjau QRIS Dinamis (Auto-Nominal):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor)),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: dynamicQris,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            info.merchantName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Nominal Uji Coba: ${currencyFormat.format(_testAmount)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryAmber),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [10000, 25000, 50000].map((amt) {
                              return ChoiceChip(
                                label: Text(currencyFormat.format(amt)),
                                selected: _testAmount == amt,
                                selectedColor: AppTheme.primaryAmber,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _testAmount == amt ? Colors.black : null,
                                  fontWeight: _testAmount == amt ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _testAmount = amt);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
