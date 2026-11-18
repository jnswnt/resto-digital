import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/app_theme.dart';

/// Halaman Pengaturan Integrasi Cloud SaaS & Multi-Tenant Resto.
/// 
/// Mengelola sinkronisasi pesanan meja online, konfigurasi Resto ID untuk cabang,
/// serta pemantauan koneksi ke Server SaaS Mandiri (resto-api.ipankhub.web.id).
class CloudConfigScreen extends StatefulWidget {
  const CloudConfigScreen({super.key});

  @override
  State<CloudConfigScreen> createState() => _CloudConfigScreenState();
}

class _CloudConfigScreenState extends State<CloudConfigScreen> {
  late final TextEditingController _restoIdCtrl;
  late final TextEditingController _serverUrlCtrl;
  late final TextEditingController _webUrlCtrl;
  late bool _isCloudSyncEnabled;

  bool _isSaving = false;
  bool _isTestingSync = false;
  bool _isTestingConnection = false;
  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _restoIdCtrl = TextEditingController(text: settings.restoId);
    _serverUrlCtrl = TextEditingController(text: CloudSyncService.defaultServerUrl);
    _webUrlCtrl = TextEditingController(text: settings.webOrderBaseUrl);
    _isCloudSyncEnabled = settings.isCloudSyncEnabled;

    _checkServerHealth();
  }

  @override
  void dispose() {
    _restoIdCtrl.dispose();
    _serverUrlCtrl.dispose();
    _webUrlCtrl.dispose();
    super.dispose();
  }

  /// Mengecek status kesehatan server backend SaaS
  Future<void> _checkServerHealth() async {
    setState(() => _isTestingConnection = true);
    final service = CloudSyncService(serverUrl: _serverUrlCtrl.text.trim());
    final isOnline = await service.testConnection();
    if (mounted) {
      setState(() {
        _isServerOnline = isOnline;
        _isTestingConnection = false;
      });
    }
  }

  /// Menyimpan seluruh konfigurasi SaaS dan menyelaraskannya ke provider aktif
  Future<void> _saveConfig() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final settingsProv = context.read<SettingsProvider>();
      final cleanRestoId = _restoIdCtrl.text.trim().isEmpty ? 'default' : _restoIdCtrl.text.trim();
      final cleanWebUrl = _webUrlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');

      await settingsProv.updateCloudConfig(
        restoId: cleanRestoId,
        firebaseProjectId: 'saas-resto',
        firebaseApiKey: '',
        webOrderBaseUrl: cleanWebUrl,
        isCloudSyncEnabled: _isCloudSyncEnabled,
      );

      if (mounted) {
        final updatedSettings = settingsProv.settings;
        context.read<OnlineOrderProvider>().syncWithSettings(updatedSettings);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi Cloud SaaS berhasil disimpan! ✅'),
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

  /// Menguji koneksi cloud dengan menyinkronkan katalog menu resto ke server SaaS
  Future<void> _testSyncMenu() async {
    FocusScope.of(context).unfocus();
    setState(() => _isTestingSync = true);

    try {
      final pos = context.read<PosProvider>();
      final online = context.read<OnlineOrderProvider>();
      final settingsProv = context.read<SettingsProvider>();

      online.syncWithSettings(settingsProv.settings.copyWith(
        restoId: _restoIdCtrl.text.trim(),
        webOrderBaseUrl: _webUrlCtrl.text.trim(),
        isCloudSyncEnabled: _isCloudSyncEnabled,
      ));

      final categoryMap = {
        for (final c in pos.categories) c.id: c.name,
      };

      final success = await online.syncMenuCatalog(
        pos.products,
        categoryNames: categoryMap,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Koneksi berhasil! ${pos.products.length} menu sukses tersinkronkan ke server SaaS. 🚀'),
              backgroundColor: AppTheme.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final err = online.syncError ?? 'Periksa koneksi server SaaS Anda.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal sinkron ke server: $err ⚠️'),
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
        title: const Text('Integrasi Cloud SaaS Resto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  // Banner Status Server SaaS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_isServerOnline == true ? AppTheme.emeraldGreen : const Color(0xFF0284C7))
                          .withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_isServerOnline == true ? AppTheme.emeraldGreen : const Color(0xFF0284C7))
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isServerOnline == true ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                          color: _isServerOnline == true ? AppTheme.emeraldGreen : const Color(0xFF0284C7),
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Server Backend SaaS Mandiri',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_isTestingConnection)
                                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (_isServerOnline == true ? AppTheme.emeraldGreen : Colors.orange)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (_isServerOnline == true ? AppTheme.emeraldGreen : Colors.orange)
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        _isServerOnline == true ? 'ONLINE' : 'CEK KONEKSI',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _isServerOnline == true ? AppTheme.emeraldGreen : Colors.orange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aplikasi kasir terhubung langsung ke server cloud Anda di https://resto-api.ipankhub.web.id tanpa ketergantungan pihak ketiga.',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU LISENSI SAAS
                  _buildSectionHeader('STATUS LISENSI SAAS (TRIAL 14 HARI)', textColor),
                  const SizedBox(height: 8),
                  Consumer<SettingsProvider>(
                    builder: (context, prov, _) {
                      final settings = prov.settings;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      settings.storeName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Resto ID: ${settings.restoId}',
                                      style: TextStyle(fontSize: 12, color: textMuted),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    'Trial: ${settings.trialDaysRemaining} Hari Tersisa',
                                    style: const TextStyle(
                                      color: AppTheme.emeraldGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pendaftaran Kafe / Tenant Baru',
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Setup Kafe Baru'),
                                        content: const Text(
                                          'Buka wizard onboarding pendaftaran kafe baru?\n'
                                          'Aplikasi akan kembali ke tampilan setup awal.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryAmber,
                                              foregroundColor: Colors.black,
                                            ),
                                            child: const Text('Buka Onboarding'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && mounted) {
                                      await context.read<SettingsProvider>().resetToOnboarding();
                                      if (mounted) Navigator.pop(context);
                                    }
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 14),
                                  label: const Text('Setup Kafe Baru', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
                      title: const Text('Aktifkan Sinkronisasi Pesanan Meja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text(
                        _isCloudSyncEnabled
                            ? 'Aplikasi kasir aktif menerima pesanan mandiri tamu meja secara real-time.'
                            : 'Mode Offline: Kasir hanya beroperasi lokal tanpa web self-ordering.',
                        style: TextStyle(fontSize: 11.5, color: textMuted),
                      ),
                      value: _isCloudSyncEnabled,
                      activeTrackColor: AppTheme.emeraldGreen,
                      onChanged: (val) => setState(() => _isCloudSyncEnabled = val),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU 2: IDENTITAS RESTO & DOMAIN SELF-ORDERING
                  _buildSectionHeader('IDENTITAS OUTLET & WEB ORDERING MEJA', textColor),
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
                            hintText: 'default atau nama_cabang',
                            prefixIcon: const Icon(Icons.store_rounded),
                            helperText: 'ID unik cabang/outlet restoran Anda (gunakan huruf kecil tanpa spasi).',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _webUrlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Domain URL Web Self-Ordering Meja',
                            hintText: 'https://order.ipankhub.web.id',
                            prefixIcon: const Icon(Icons.language_rounded),
                            helperText: 'Alamat web menu yang dibuka tamu saat memindai kode QR meja.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _serverUrlCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Endpoint API Server SaaS',
                            prefixIcon: const Icon(Icons.dns_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Uji Koneksi Server',
                              onPressed: _checkServerHealth,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // KARTU 3: AKSI SINKRONISASI KATALOG MENU
                  _buildSectionHeader('SINKRONISASI KATALOG MENU KE CLOUD', textColor),
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
                        Text(
                          'Unggah seluruh daftar kategori dan produk kasir ke server SaaS agar menu makanan dan minuman pada Web QR Meja selalu terbarui secara instan.',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isTestingSync ? null : _testSyncMenu,
                            icon: _isTestingSync
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(_isTestingSync ? 'Menyinkronkan...' : 'Sinkronkan Menu ke Server SaaS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emeraldGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: color.withValues(alpha: 0.7),
      ),
    );
  }
}
