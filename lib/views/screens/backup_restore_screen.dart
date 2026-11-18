import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/backup_restore_service.dart';
import '../../services/storage_service.dart';
import '../../providers/pos_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Pencadangan & Pemulihan Database Manual (Backup & Restore Screen)
/// Menyediakan fitur ekspor data offline ke file JSON atau clipboard
/// dan pemulihan data untuk keamanan atau migrasi perangkat.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final TextEditingController _restoreJsonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _restoreJsonController.dispose();
    super.dispose();
  }

  Future<void> _handleExportFile() async {
    setState(() => _isLoading = true);
    try {
      final storage = await StorageService.init();
      final dbHelper = storage.dbHelper;

      final success = await BackupRestoreService.exportBackupFile(
        dbHelper: dbHelper,
        storageService: storage,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File cadangan database (.json) berhasil diunduh / disimpan!'),
              backgroundColor: AppTheme.emeraldGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengekspor file cadangan.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCopyClipboard() async {
    setState(() => _isLoading = true);
    try {
      final storage = await StorageService.init();
      final dbHelper = storage.dbHelper;

      final success = await BackupRestoreService.copyBackupToClipboard(
        dbHelper: dbHelper,
        storageService: storage,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seluruh data cadangan JSON berhasil disalin ke clipboard!'),
              backgroundColor: AppTheme.emeraldGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyalin data cadangan.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final rawText = _restoreJsonController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan tempel (paste) data JSON cadangan terlebih dahulu.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 10),
              Text('Konfirmasi Pemulihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'PERINGATAN: Memulihkan cadangan ini akan MENIMPA dan MENGGANTIKAN seluruh data menu, pesanan, transaksi, dan pengaturan saat ini dengan isi file cadangan.\n\nApakah Anda yakin ingin melanjutkan?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Pulihkan Database'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final storage = await StorageService.init();
      final dbHelper = storage.dbHelper;

      final success = await BackupRestoreService.restoreFromBackupJson(
        jsonContent: rawText,
        dbHelper: dbHelper,
        storageService: storage,
      );

      if (mounted) {
        if (success) {
          // Muat ulang SQLite ke cache StorageService
          await storage.reloadFromDatabase();

          // Muat ulang seluruh provider dengan data yang baru dipulihkan
          if (mounted) {
            context.read<PosProvider>().loadData();
            context.read<ShiftProvider>().loadActiveShift();
            context.read<SettingsProvider>().loadSettings();
            context.read<SettingsProvider>().loadUsers();
            context.read<CustomerDebtProvider>().loadCustomers();

            _restoreJsonController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database berhasil dipulihkan dengan sukses!'),
                backgroundColor: AppTheme.emeraldGreen,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format data JSON cadangan tidak valid atau rusak.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat memulihkan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final pos = context.watch<PosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Pemulihan Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  // KARTU STATUS DATABASE SAAT INI
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
                                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.storage_rounded, color: Color(0xFF0D9488), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Database Lokal Offline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                  Text('Statistik data tersimpan di perangkat ini', style: TextStyle(fontSize: 11.5, color: textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Kategori', '${pos.categories.length}', textColor, textMuted),
                            _buildStatItem('Menu / Produk', '${pos.products.length}', textColor, textMuted),
                            _buildStatItem('Transaksi', '${pos.transactions.length}', textColor, textMuted),
                            _buildStatItem('Arsip Order', '${pos.allOrders.length}', textColor, textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // BAGIAN 1: EKSPOR CADANGAN (BACKUP)
                  Text('1. EKSPOR FILE CADANGAN (BACKUP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textMuted)),
                  const SizedBox(height: 8),
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
                        Text(
                          'Ekspor seluruh database (menu, stok, pesanan, transaksi, shift, dan pengaturan) ke dalam satu berkas cadangan JSON yang aman.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleCopyClipboard,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Salin JSON', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleExportFile,
                                icon: const Icon(Icons.download_rounded, size: 17),
                                label: const Text('Download File (.json)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
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

                  const SizedBox(height: 24),

                  // BAGIAN 2: PEMULIHAN DATABASE (RESTORE)
                  Text('2. PEMULIHAN DATABASE (RESTORE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textMuted)),
                  const SizedBox(height: 8),
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
                        Text(
                          'Tempelkan (paste) teks isi berkas cadangan .json ke kotak di bawah ini untuk memulihkan seluruh data resto ke perangkat ini.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _restoreJsonController,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: '{\n  "app": "mini_resto_pos",\n  "data": { ... }\n}',
                            hintStyle: TextStyle(fontSize: 11, color: textMuted.withValues(alpha: 0.5)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleRestore,
                            icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                            label: const Text('Pulihkan Seluruh Database', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
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
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color textColor, Color textMuted) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: textMuted)),
      ],
    );
  }
}
