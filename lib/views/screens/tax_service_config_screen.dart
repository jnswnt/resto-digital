import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Konfigurasi Pajak Restoran (PB1) & Biaya Layanan (Service Charge)
/// Memungkinkan pemilik resto mengaktifkan/menonaktifkan regulasi pajak restoran
/// dan service charge beserta penyesuaian persentasenya.
class TaxServiceConfigScreen extends StatefulWidget {
  const TaxServiceConfigScreen({super.key});

  @override
  State<TaxServiceConfigScreen> createState() => _TaxServiceConfigScreenState();
}

class _TaxServiceConfigScreenState extends State<TaxServiceConfigScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late bool _enableTax;
  late TextEditingController _taxPercentCtrl;
  late bool _enableServiceCharge;
  late TextEditingController _serviceChargePercentCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _enableTax = settings.enableTax;
    _taxPercentCtrl = TextEditingController(
      text: settings.taxPercentage.toStringAsFixed(settings.taxPercentage.truncateToDouble() == settings.taxPercentage ? 0 : 1),
    );
    _enableServiceCharge = settings.enableServiceCharge;
    _serviceChargePercentCtrl = TextEditingController(
      text: settings.serviceChargePercentage.toStringAsFixed(settings.serviceChargePercentage.truncateToDouble() == settings.serviceChargePercentage ? 0 : 1),
    );
  }

  @override
  void dispose() {
    _taxPercentCtrl.dispose();
    _serviceChargePercentCtrl.dispose();
    super.dispose();
  }

  double get _currentTaxPercent => double.tryParse(_taxPercentCtrl.text.trim()) ?? 10.0;
  double get _currentServiceChargePercent => double.tryParse(_serviceChargePercentCtrl.text.trim()) ?? 5.0;

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.updateTaxAndServiceSettings(
        enableTax: _enableTax,
        taxPercentage: _currentTaxPercent,
        enableServiceCharge: _enableServiceCharge,
        serviceChargePercentage: _currentServiceChargePercent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan Pajak Restoran & Service Charge berhasil disimpan!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    // Hitung simulasi tagihan contoh pesanan Rp 100.000
    const sampleSubtotal = 100000;
    final sampleService = _enableServiceCharge ? ((sampleSubtotal * _currentServiceChargePercent) / 100).round() : 0;
    final sampleTax = _enableTax ? (((sampleSubtotal + sampleService) * _currentTaxPercent) / 100).round() : 0;
    final sampleTotal = sampleSubtotal + sampleService + sampleTax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pajak PB1 & Service Charge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BANNER INFORMASI REGULASI
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pajak Restoran (PB1) adalah pajak daerah yang dipungut atas pelayanan restoran/kafe di Indonesia (umumnya 10%). Biaya layanan (Service Charge) merupakan uang jasa operasional pramusaji (umumnya 5%).',
                            style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU PENGATURAN PAJAK RESTORAN PB1
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFE11D48), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pajak Restoran (PB1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                  Text('Cantumkan pajak makan di struk transaksi', style: TextStyle(fontSize: 11.5, color: textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enableTax,
                              activeThumbColor: AppTheme.emeraldGreen,
                              onChanged: (val) {
                                setState(() => _enableTax = val);
                              },
                            ),
                          ],
                        ),
                        if (_enableTax) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tarif Persentase Pajak (%):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                                    Text('Standar daerah: 10%', style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _taxPercentCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // KARTU PENGATURAN SERVICE CHARGE
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.room_service_rounded, color: Color(0xFF0284C7), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Biaya Layanan (Service Charge)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                  Text('Uang jasa layanan restoran/kafe', style: TextStyle(fontSize: 11.5, color: textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enableServiceCharge,
                              activeThumbColor: AppTheme.emeraldGreen,
                              onChanged: (val) {
                                setState(() => _enableServiceCharge = val);
                              },
                            ),
                          ],
                        ),
                        if (_enableServiceCharge) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tarif Persentase Layanan (%):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                                    Text('Umumnya 5% - 7%', style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _serviceChargePercentCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // KARTU SIMULASI PERHITUNGAN STRUK
                  Text('SIMULASI PERHITUNGAN STRUK KASIR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Contoh Subtotal Menu:', style: TextStyle(fontSize: 12, color: textMuted)),
                            Text(_currencyFormat.format(sampleSubtotal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                          ],
                        ),
                        if (_enableServiceCharge) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Charge ($_currentServiceChargePercent%):', style: TextStyle(fontSize: 12, color: textMuted)),
                              Text(_currencyFormat.format(sampleService), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                            ],
                          ),
                        ],
                        if (_enableTax) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pajak Restoran PB1 ($_currentTaxPercent%):', style: TextStyle(fontSize: 12, color: textMuted)),
                              Text(_currencyFormat.format(sampleTax), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Tagihan Akhir:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                            Text(
                              _currencyFormat.format(sampleTotal),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // TOMBOL SIMPAN
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan Pajak & Layanan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
