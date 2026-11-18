import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../theme/app_theme.dart';

/// Halaman Sub-Menu Khusus: Pengaturan Integrasi Cloud & Multi-Tenant Resto.
/// Memungkinkan pemilik resto mengatur kredensial Firebase mandiri,
/// menentukan Resto/Tenant ID unik untuk mengisolasi data antar cabang/pembeli,
/// serta mengatur domain Web Self-Ordering meja.
class CloudConfigScreen extends StatefulWidget {
  const CloudConfigScreen({super.key});

  @override
  State<CloudConfigScreen> createState() => _CloudConfigScreenState();
}

class _CloudConfigScreenState extends State<CloudConfigScreen> {
  late final TextEditingController _restoIdCtrl;
  late final TextEditingController _projectIdCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _webUrlCtrl;
  late bool _isCloudSyncEnabled;

  bool _isSaving = false;
  bool _isTestingSync = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _restoIdCtrl = TextEditingController(text: settings.restoId);
    _projectIdCtrl = TextEditingController(text: settings.firebaseProjectId);
    _apiKeyCtrl = TextEditingController(text: settings.firebaseApiKey);
    _webUrlCtrl = TextEditingController(text: settings.webOrderBaseUrl);
    _isCloudSyncEnabled = settings.isCloudSyncEnabled;
  }

  @override
  void dispose() {
    _restoIdCtrl.dispose();
    _projectIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    _webUrlCtrl.dispose();
    super.dispose();
  }

  /// Menyimpan seluruh konfigurasi cloud dan menyelaraskannya ke provider aktif
  Future<void> _saveConfig() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final settingsProv = context.read<SettingsProvider>();
      final cleanRestoId = _restoIdCtrl.text.trim().isEmpty ? 'default' : _restoIdCtrl.text.trim();
      final cleanProjId = _projectIdCtrl.text.trim().isEmpty ? 'restodigital-pos' : _projectIdCtrl.text.trim();
      final cleanApiKey = _apiKeyCtrl.text.trim();
      final cleanWebUrl = _webUrlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');

      await settingsProv.updateCloudConfig(
        restoId: cleanRestoId,
        firebaseProjectId: cleanProjId,
        firebaseApiKey: cleanApiKey,
        webOrderBaseUrl: cleanWebUrl,
        isCloudSyncEnabled: _isCloudSyncEnabled,
      );

      // Sinkronkan ke OnlineOrderProvider agar listener langsung berganti target cloud
      if (mounted) {
        final updatedSettings = settingsProv.settings;
        context.read<OnlineOrderProvider>().syncWithSettings(updatedSettings);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi Cloud & Multi-Tenant berhasil disimpan! ✅'),
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

  /// Menguji koneksi cloud dengan menyinkronkan katalog menu resto ke Firebase
  Future<void> _testSyncMenu() async {
    FocusScope.of(context).unfocus();
    setState(() => _isTestingSync = true);

    try {
      final pos = context.read<PosProvider>();
      final online = context.read<OnlineOrderProvider>();
      final settingsProv = context.read<SettingsProvider>();

      // Pastikan service memakai konfigurasi terbaru dari form
      online.syncWithSettings(settingsProv.settings.copyWith(
        restoId: _restoIdCtrl.text.trim(),
        firebaseProjectId: _projectIdCtrl.text.trim(),
        firebaseApiKey: _apiKeyCtrl.text.trim(),
        webOrderBaseUrl: _webUrlCtrl.text.trim(),
        isCloudSyncEnabled: _isCloudSyncEnabled,
      ));

      final success = await online.syncMenuCatalog(pos.products);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Koneksi berhasil! ${pos.products.length} menu sukses tersinkron ke cloud. 🚀'),
              backgroundColor: AppTheme.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final err = online.syncError ?? 'Periksa kembali Project ID dan API Key Anda.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal sinkron ke cloud: $err ⚠️'),
              backgroundColor: AppTheme.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingSync = false);
      }
    }
  }

  /// Mengembalikan nilai konfigurasi ke bawaan pabrik (Default Starter)
  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Pengaturan Cloud?'),
        content: const Text(
          'Konfigurasi akan dikembalikan ke Firebase bawaan proyek (restodigital-pos) dengan Resto ID "default".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _restoIdCtrl.text = 'default';
                _projectIdCtrl.text = 'restodigital-pos';
                _apiKeyCtrl.text = 'AIzaSyBL9UgLYEtq32Upsp38Xa_C_Vt2Fgzwy6w';
                _webUrlCtrl.text = 'https://restodigital-pos.web.app';
                _isCloudSyncEnabled = true;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        title: const Text('Integrasi Cloud & Multi-Tenant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
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
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Edukasi Multi-Tenant
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Isolasi Data Antar Restoran (Multi-Tenant)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Resto ID menjamin pesanan meja, katalog menu, dan panggilan pelayan tidak tertukar dengan restoran lain meskipun menggunakan database cloud yang sama.',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU 1: STATUS SINKRONISASI CLOUD
                  _buildSectionHeader('STATUS CLOUD & SELF-ORDERING', textColor),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: SwitchListTile.adaptive(
                      title: const Text('Aktifkan Sinkronisasi Cloud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text(
                        _isCloudSyncEnabled
                            ? 'Aplikasi aktif menerima pesanan mandiri tamu meja secara online.'
                            : 'Mode Offline Saja: Kasir hanya beroperasi lokal tanpa web order.',
                        style: TextStyle(fontSize: 11.5, color: textMuted),
                      ),
                      value: _isCloudSyncEnabled,
                      activeTrackColor: AppTheme.emeraldGreen,
                      onChanged: (val) => setState(() => _isCloudSyncEnabled = val),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU 2: IDENTITAS TENANT & OUTLET RESTO
                  _buildSectionHeader('IDENTITAS RESTO (TENANT ID)', textColor),
                  const SizedBox(height: 8),
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
                        TextField(
                          controller: _restoIdCtrl,
                          decoration: InputDecoration(
                            labelText: 'Resto / Tenant ID',
                            hintText: 'Contoh: warkop_berkah_01 atau default',
                            prefixIcon: const Icon(Icons.store_rounded),
                            helperText: 'Gunakan huruf kecil tanpa spasi. Ini adalah namespace unik outlet Anda.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _webUrlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Domain URL Web Self-Ordering',
                            hintText: 'https://restodigital-pos.web.app',
                            prefixIcon: const Icon(Icons.language_rounded),
                            helperText: 'Alamat web yang dibuka tamu saat memindai kode QR meja.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU 3: KONEKSI DATABASE FIREBASE CLOUD
                  _buildSectionHeader('FIREBASE CLOUD FIRESTORE', textColor),
                  const SizedBox(height: 8),
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
                        TextField(
                          controller: _projectIdCtrl,
                          decoration: InputDecoration(
                            labelText: 'Firebase Project ID',
                            hintText: 'restodigital-pos',
                            prefixIcon: const Icon(Icons.cloud_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            labelText: 'Firebase Web API Key',
                            hintText: 'AIzaSy...',
                            prefixIcon: const Icon(Icons.vpn_key_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isTestingSync ? null : _testSyncMenu,
                                icon: _isTestingSync
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.sync_rounded, size: 16),
                                label: Text(
                                  _isTestingSync ? 'Menguji...' : 'Uji Koneksi & Sinkronkan Menu',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.restore_rounded),
                              tooltip: 'Reset ke Default',
                              onPressed: _resetToDefault,
                              style: IconButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: textColor.withValues(alpha: 0.7),
      ),
    );
  }
}
