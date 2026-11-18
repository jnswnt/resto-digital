import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../services/printer_receipt_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/live_receipt_paper.dart';

/// Halaman Sub-Menu Khusus: Pengaturan Printer Thermal & Format Struk Belanja.
/// Menyediakan konfigurasi hardware printer (58mm/80mm, Bluetooth/USB/LAN/Browser),
/// otomatisasi cetak kasir & dapur, format header/footer struk, serta live thermal preview interaktif.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late String _printerType;
  late String _paperSize;
  late final TextEditingController _printerNameCtrl;
  late final TextEditingController _printerIpCtrl;
  late final TextEditingController _printerPortCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;

  late bool _autoPrintReceipt;
  late bool _autoPrintKitchen;
  late bool _autoCut;
  late int _numberOfCopies;
  late bool _showCustomerInfo;
  late bool _showCashierName;
  late bool _showOrderNotes;
  late bool _showQrFooter;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _printerType = settings.printerType;
    _paperSize = settings.paperSize;
    _printerNameCtrl = TextEditingController(text: settings.printerName);
    _printerIpCtrl = TextEditingController(text: settings.printerIpAddress);
    _printerPortCtrl = TextEditingController(text: settings.printerPort.toString());
    _headerCtrl = TextEditingController(text: settings.receiptHeader);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);

    _autoPrintReceipt = settings.autoPrintReceipt;
    _autoPrintKitchen = settings.autoPrintKitchen;
    _autoCut = settings.autoCut;
    _numberOfCopies = settings.numberOfCopies;
    _showCustomerInfo = settings.showCustomerInfo;
    _showCashierName = settings.showCashierName;
    _showOrderNotes = settings.showOrderNotes;
    _showQrFooter = settings.showQrFooter;

    // Tambahkan listener untuk live preview saat teks berubah
    _headerCtrl.addListener(() => setState(() {}));
    _footerCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _printerNameCtrl.dispose();
    _printerIpCtrl.dispose();
    _printerPortCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  /// Membuat model temporer berdasarkan state input form saat ini untuk live preview
  SettingsModel _buildCurrentPreviewSettings(SettingsModel baseSettings) {
    return baseSettings.copyWith(
      printerType: _printerType,
      paperSize: _paperSize,
      printerName: _printerNameCtrl.text.trim(),
      printerIpAddress: _printerIpCtrl.text.trim(),
      printerPort: int.tryParse(_printerPortCtrl.text.trim()) ?? 9100,
      autoPrintReceipt: _autoPrintReceipt,
      autoPrintKitchen: _autoPrintKitchen,
      autoCut: _autoCut,
      numberOfCopies: _numberOfCopies,
      receiptHeader: _headerCtrl.text.trim(),
      receiptFooter: _footerCtrl.text.trim(),
      showCustomerInfo: _showCustomerInfo,
      showCashierName: _showCashierName,
      showOrderNotes: _showOrderNotes,
      showQrFooter: _showQrFooter,
    );
  }

  /// Menyimpan seluruh konfigurasi printer & format struk
  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final port = int.tryParse(_printerPortCtrl.text.trim()) ?? 9100;
      await context.read<SettingsProvider>().updatePrinterReceiptSettings(
            printerType: _printerType,
            paperSize: _paperSize,
            printerName: _printerNameCtrl.text.trim(),
            printerIpAddress: _printerIpCtrl.text.trim(),
            printerPort: port,
            autoPrintReceipt: _autoPrintReceipt,
            autoPrintKitchen: _autoPrintKitchen,
            autoCut: _autoCut,
            numberOfCopies: _numberOfCopies,
            receiptHeader: _headerCtrl.text.trim(),
            receiptFooter: _footerCtrl.text.trim(),
            showCustomerInfo: _showCustomerInfo,
            showCashierName: _showCashierName,
            showOrderNotes: _showOrderNotes,
            showQrFooter: _showQrFooter,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi printer dan format struk berhasil disimpan! ✅'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Menguji cetak struk sampel langsung ke printer
  void _testPrintDirect(SettingsModel previewSettings) {
    final sampleOrder = PrinterReceiptService.generateSampleOrder();
    PrinterReceiptService.printReceiptDirect(
      settings: previewSettings,
      order: sampleOrder,
      receiptNo: 'TEST-001',
      orderTime: DateTime.now(),
      cashierName: 'Kasir Uji Coba',
      paymentMethod: 'Tunai (Cash)',
      amountPaid: 100000,
      change: 23000,
      isSample: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mencetak struk uji coba (${previewSettings.paperSize.toUpperCase()})... 🖨️'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    final settings = context.watch<SettingsProvider>().settings;
    final currentPreviewSettings = _buildCurrentPreviewSettings(settings);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        title: const Text('Pengaturan Printer & Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kolom Kiri: Form Konfigurasi (Lebar 58%)
                        Expanded(
                          flex: 6,
                          child: _buildConfigurationForm(isDark, textColor, textMuted, borderColor),
                        ),
                        const SizedBox(width: 24),
                        // Kolom Kanan: Live Thermal Preview (Lebar 42%)
                        Expanded(
                          flex: 4,
                          child: _buildLivePreviewPanel(isDark, textColor, textMuted, borderColor, currentPreviewSettings),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildConfigurationForm(isDark, textColor, textMuted, borderColor),
                        const SizedBox(height: 24),
                        _buildLivePreviewPanel(isDark, textColor, textMuted, borderColor, currentPreviewSettings),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Membangun Form Konfigurasi Printer & Struk
  Widget _buildConfigurationForm(bool isDark, Color textColor, Color textMuted, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------------------------------------------------------------
        // 1. KARTU HARDWARE PRINTER & UKURAN KERTAS
        // -------------------------------------------------------------
        _buildSectionHeader('HARDWARE & KONEKSI PRINTER', textColor),
        const SizedBox(height: 10),
        _buildCard(
          isDark: isDark,
          borderColor: borderColor,
          children: [
            // Pilihan Tipe Printer
            const Text('Tipe Koneksi Printer:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildConnectionChip(
                  label: 'Browser / Sistem',
                  icon: Icons.language_rounded,
                  value: 'browser',
                  desc: 'Universal web & dialog print sistem',
                ),
                _buildConnectionChip(
                  label: 'Bluetooth POS',
                  icon: Icons.bluetooth_rounded,
                  value: 'bluetooth',
                  desc: 'Printer thermal portabel kasir',
                ),
                _buildConnectionChip(
                  label: 'USB Thermal',
                  icon: Icons.usb_rounded,
                  value: 'usb',
                  desc: 'Kabel USB kasir desktop',
                ),
                _buildConnectionChip(
                  label: 'LAN / WiFi Network',
                  icon: Icons.wifi_rounded,
                  value: 'network',
                  desc: 'Printer jaringan IP dapur / kasir',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Pilihan Ukuran Kertas Thermal
            const Text('Ukuran Kertas Thermal:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaperSizeOption(
                    title: '58 mm',
                    subtitle: 'Standar Kasir (32 Karakter)',
                    icon: Icons.receipt_rounded,
                    value: '58mm',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaperSizeOption(
                    title: '80 mm',
                    subtitle: 'Lebar / KOT Dapur (48 Karakter)',
                    icon: Icons.newspaper_rounded,
                    value: '80mm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input Nama Printer
            TextField(
              controller: _printerNameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama / Alias Printer',
                hintText: 'Contoh: POS-58 Thermal Kasir Depan',
                prefixIcon: const Icon(Icons.print_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // Input IP & Port (jika koneksi network)
            if (_printerType == 'network') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _printerIpCtrl,
                      decoration: InputDecoration(
                        labelText: 'Alamat IP Printer',
                        hintText: 'Contoh: 192.168.1.200',
                        prefixIcon: const Icon(Icons.settings_ethernet_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _printerPortCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Port (Default 9100)',
                        hintText: '9100',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        const SizedBox(height: 22),

        // -------------------------------------------------------------
        // 2. KARTU OTOMATISASI PENCETAKAN POS
        // -------------------------------------------------------------
        _buildSectionHeader('OTOMATISASI CETAK POS', textColor),
        const SizedBox(height: 10),
        _buildCard(
          isDark: isDark,
          borderColor: borderColor,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Otomatis Struk Kasir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Mencetak struk pembayaran seketika saat tombol Bayar selesai ditekan.',
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
              value: _autoPrintReceipt,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _autoPrintReceipt = val),
            ),
            const Divider(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Otomatis Tiket Dapur (KOT)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Kirim tiket pesanan baru ke printer dapur secara instan untuk segera dimasak.',
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
              value: _autoPrintKitchen,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _autoPrintKitchen = val),
            ),
            const Divider(height: 16),
            // Auto-Cut Kertas (Ditempatkan di Section Otomatisasi)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Cut Kertas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Kirim sinyal potong kertas otomatis setelah mencetak (jika didukung hardware).',
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
              value: _autoCut,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _autoCut = val),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumlah Rangkap Cetak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Jumlah lembar nota yang dicetak per transaksi.', style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1x Rangkap')),
                    ButtonSegment(value: 2, label: Text('2x Rangkap')),
                  ],
                  selected: {_numberOfCopies},
                  onSelectionChanged: (val) => setState(() => _numberOfCopies = val.first),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 22),

        // -------------------------------------------------------------
        // 3. KARTU FORMAT & TAMPILAN STRUK
        // -------------------------------------------------------------
        _buildSectionHeader('FORMAT & DESAIN STRUK BELANJA', textColor),
        const SizedBox(height: 10),
        _buildCard(
          isDark: isDark,
          borderColor: borderColor,
          children: [
            TextField(
              controller: _headerCtrl,
              decoration: InputDecoration(
                labelText: 'Pesan Header / Slogan Resto',
                hintText: 'Contoh: Selamat Menikmati Hidangan Kami',
                prefixIcon: const Icon(Icons.short_text_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _footerCtrl,
              decoration: InputDecoration(
                labelText: 'Pesan Footer Struk',
                hintText: 'Contoh: Terima kasih atas kunjungannya!',
                prefixIcon: const Icon(Icons.message_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Elemen Tampilan pada Struk:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Info Tamu & Meja', style: TextStyle(fontSize: 12.5)),
              subtitle: Text('Sertakan nomor meja dan nama pemesan di struk.', style: TextStyle(fontSize: 11, color: textMuted)),
              value: _showCustomerInfo,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _showCustomerInfo = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nama Kasir Bertugas', style: TextStyle(fontSize: 12.5)),
              subtitle: Text('Tampilkan nama kasir yang melayani transaksi.', style: TextStyle(fontSize: 11, color: textMuted)),
              value: _showCashierName,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _showCashierName = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Catatan Menu Khusus (*Notes*)', style: TextStyle(fontSize: 12.5)),
              subtitle: Text('Cetak rincian rasa (pedas/manis/ceplok) di bawah item menu.', style: TextStyle(fontSize: 11, color: textMuted)),
              value: _showOrderNotes,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _showOrderNotes = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Barcode / QR Simulasi Nota', style: TextStyle(fontSize: 12.5)),
              subtitle: Text('Cetak grafis barcode di bagian bawah nota untuk verifikasi kasir.', style: TextStyle(fontSize: 11, color: textMuted)),
              value: _showQrFooter,
              activeThumbColor: AppTheme.emeraldGreen,
              onChanged: (val) => setState(() => _showQrFooter = val),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // TOMBOL SIMPAN BESAR DI BAWAH
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Semua Pengaturan Printer & Struk'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Membangun Panel Pratinjau Kertas Thermal Interaktif
  Widget _buildLivePreviewPanel(
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
    SettingsModel previewSettings,
  ) {
    final sampleOrder = PrinterReceiptService.generateSampleOrder();
    final is80mm = _paperSize == '80mm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('PRATINJAU STRUK THERMAL NYATA', textColor),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Info Banner Ukuran Kertas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: is80mm
                      ? Colors.blue.withValues(alpha: 0.12)
                      : AppTheme.primaryAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      is80mm ? Icons.aspect_ratio_rounded : Icons.crop_portrait_rounded,
                      size: 18,
                      color: is80mm ? Colors.blue : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Format Kertas: ${_paperSize.toUpperCase()} (${PrinterReceiptService.getColumnWidth(_paperSize)} Kolom)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: is80mm ? Colors.blue : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Visual Kertas Struk Thermal Fisik (Live Nota Persis Kasir POS)
              Center(
                child: LiveReceiptPaper(
                  settings: previewSettings,
                  order: sampleOrder,
                  receiptNo: 'SAMPLE-01',
                  orderTime: DateTime.now(),
                  cashierName: 'H. Sukri (Kasir)',
                  paymentMethod: 'Tunai',
                  amountPaid: 100000,
                  change: 23000,
                  isSample: true,
                  forceLightMode: false,
                  showNotch: true,
                  showSawtooth: true,
                  width: is80mm ? 380 : 330,
                ),
              ),

              const SizedBox(height: 18),

              // Tombol Uji Cetak Langsung
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        PrinterReceiptService.showReceiptPreviewDialog(
                          context,
                          settings: previewSettings,
                          order: sampleOrder,
                          receiptNo: 'SAMPLE-01',
                          orderTime: DateTime.now(),
                          cashierName: 'H. Sukri (Kasir)',
                          paymentMethod: 'Tunai',
                          amountPaid: 100000,
                          change: 23000,
                          isSample: true,
                        );
                      },
                      icon: const Icon(Icons.fullscreen_rounded, size: 16),
                      label: const Text('Dialog Modal', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _testPrintDirect(previewSettings),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Uji Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chip Pilihan Tipe Koneksi
  Widget _buildConnectionChip({
    required String label,
    required IconData icon,
    required String value,
    required String desc,
  }) {
    final isSelected = _printerType == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.grey),
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primaryAmber,
      onSelected: (selected) {
        if (selected) setState(() => _printerType = value);
      },
    );
  }

  /// Opsi Kartu Pemilihan Ukuran Kertas
  Widget _buildPaperSizeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _paperSize == value;
    return InkWell(
      onTap: () => setState(() => _paperSize = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAmber.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAmber : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryAmber : Colors.grey, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppTheme.primaryAmber : null)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor.withValues(alpha: 0.65),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
