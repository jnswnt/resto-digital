import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../theme/app_theme.dart';

/// Halaman Sub Menu Khusus: Profil Restoran & Format Struk Belanja
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _footerCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _storeNameCtrl = TextEditingController(text: settings.storeName);
    _addressCtrl = TextEditingController(text: settings.address);
    _phoneCtrl = TextEditingController(text: settings.phoneWA);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Hapus fokus aktif dan sembunyikan keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      final provider = context.read<SettingsProvider>();
      await provider.updateStoreProfile(
        storeName: _storeNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phoneWA: _phoneCtrl.text.trim(),
        receiptFooter: _footerCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil restoran & struk berhasil disimpan!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Resto & Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // KARTU NOTIFIKASI SUARA ORDER MASUK
                Consumer<OnlineOrderProvider>(
                  builder: (context, onlineProvider, _) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_rounded,
                                    color: AppTheme.emeraldGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Suara Notifikasi Pesanan Masuk',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        'Putar audio bel saat ada pesanan web atau panggilan pelayan.',
                                        style: TextStyle(fontSize: 11, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: onlineProvider.isSoundEnabled,
                                  activeThumbColor: AppTheme.emeraldGreen,
                                  onChanged: (val) => onlineProvider.setSoundEnabled(val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await onlineProvider.testNotificationSound();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Memutar uji coba suara notifikasi... 🔔'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: AppTheme.emeraldGreen,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.volume_up_rounded, size: 15),
                              label: const Text('Uji Coba Suara', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emeraldGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  'Identitas Restoran & Format Struk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),

                // FORM INFORMASI TOKO
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _storeNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nama Restoran / Cafe',
                            hintText: 'Contoh: Resto Digital Nusantara',
                            prefixIcon: const Icon(Icons.storefront_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Alamat Resto Lengkap',
                            hintText: 'Contoh: Jl. Sudirman No. 45, Jakarta',
                            prefixIcon: const Icon(Icons.location_on_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp Toko',
                            hintText: 'Contoh: 0812-3456-7890',
                            prefixIcon: const Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _footerCtrl,
                          decoration: InputDecoration(
                            labelText: 'Pesan Footer Struk Belanja',
                            hintText: 'Contoh: Terima kasih atas kunjungan Anda!',
                            prefixIcon: const Icon(Icons.message_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan Profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
