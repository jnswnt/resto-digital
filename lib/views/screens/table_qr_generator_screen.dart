import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Generator & Pencetakan Kode QR Meja Resto (Self-Ordering).
/// Memudahkan pemilik resto membuat dan mencetak stiker/tent-card QR untuk tiap nomor meja.
class TableQrGeneratorScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TableQrGeneratorScreen({super.key, this.onBack});

  @override
  State<TableQrGeneratorScreen> createState() => _TableQrGeneratorScreenState();
}

class _TableQrGeneratorScreenState extends State<TableQrGeneratorScreen> {
  int _selectedTableNum = 1;
  final int _totalTables = 20;
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://restodigital-pos.web.app',
  );

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  String _getTableUrl(int tableNum) {
    final base = _baseUrlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    final tableStr = tableNum.toString().padLeft(2, '0');
    return '$base/?table=$tableStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final settings = context.watch<SettingsProvider>().settings;

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final currentTableStr = _selectedTableNum.toString().padLeft(2, '0');
    final currentUrl = _getTableUrl(_selectedTableNum);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        title: const Text('Cetak Kode QR Meja Resto', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryAmber, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stiker QR Self-Ordering Meja',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Cetak dan tempelkan QR ini di tiap meja tamu resto. Saat tamu memindai dengan kamera HP, menu makanan akan langsung terbuka otomatis dengan nomor meja terisi.',
                                style: TextStyle(fontSize: 12.5, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Konfigurasi Web Base URL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alamat Web Pemesanan (URL Hosting):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _baseUrlController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.link, size: 18),
                                  hintText: 'https://restodigital-pos.web.app',
                                  filled: true,
                                  fillColor: isDark ? AppTheme.darkSearchBg : AppTheme.lightSearchBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _baseUrlController.text = 'https://restodigital-pos.web.app';
                                });
                              },
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Reset Default'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF282B38) : Colors.grey.shade200,
                                foregroundColor: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pilihan Nomor Meja (Selector Grid/Chips)
                  Text('Pilih Nomor Meja:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _totalTables,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final tNum = idx + 1;
                        final isSelected = tNum == _selectedTableNum;
                        return ChoiceChip(
                          label: Text('Meja ${tNum.toString().padLeft(2, '0')}'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedTableNum = tNum);
                          },
                          selectedColor: AppTheme.primaryAmber,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // PREVIEW TENT-CARD / STIKER MEJA SIAP CETAK
                  Center(
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: Colors.amber.shade300, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Resto
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('🍽️', style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settings.storeName.isNotEmpty ? settings.storeName : 'Resto Digital',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Text(
                                    'Pesan Mandiri (Self-Ordering)',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Badge Nomor Meja
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade800,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'MEJA $currentTableStr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Kode QR
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            ),
                            child: QrImageView(
                              data: currentUrl,
                              version: QrVersions.auto,
                              size: 190.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1E293B),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Petunjuk Tamu
                          const Text(
                            'Scan QR untuk Memesan Menu',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Buka kamera HP Anda, arahkan ke kode QR di atas untuk memilih makanan & minuman langsung dari meja.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10.5,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text(
                            currentUrl,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 8.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action Buttons
                  Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link pesanan Meja $currentTableStr disalin: $currentUrl'),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Salin Tautan Meja'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAmber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Silakan gunakan fungsi Print / Screenshot untuk mencetak standee meja.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Cetak Standee Meja Ini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF282B38) : Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
