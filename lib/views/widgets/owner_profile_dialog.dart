import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Dialog Modal Khusus untuk Mengubah Profil Pemilik Restoran (Owner) & PIN Master.
/// Dapat dipanggil dari Halaman Pengaturan maupun langsung dari Sidebar Navigasi.
class OwnerProfileDialog extends StatefulWidget {
  const OwnerProfileDialog({super.key});

  /// Helper statis untuk menampilkan dialog secara seragam di seluruh aplikasi
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const OwnerProfileDialog(),
    );
  }

  @override
  State<OwnerProfileDialog> createState() => _OwnerProfileDialogState();
}

class _OwnerProfileDialogState extends State<OwnerProfileDialog> {
  late final TextEditingController _nameCtrl;
  final TextEditingController _oldPinCtrl = TextEditingController();
  final TextEditingController _newPinCtrl = TextEditingController();
  final TextEditingController _confirmPinCtrl = TextEditingController();

  bool _changePin = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    final authProvider = context.read<AuthProvider>();

    final initialName = settingsProvider.ownerUser?.name ??
        authProvider.currentUser?.name ??
        'H. Sukri (Owner)';
    _nameCtrl = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama pemilik resto tidak boleh kosong!'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    String? newPinToSave;
    if (_changePin) {
      final oldPin = _oldPinCtrl.text.trim();
      final newPin = _newPinCtrl.text.trim();
      final confirmPin = _confirmPinCtrl.text.trim();
      final auth = context.read<AuthProvider>();

      // Validasi PIN lama jika user login bukan mode owner aktif
      if (!auth.isOwnerMode && !auth.verifyOwnerPin(oldPin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN lama saat ini tidak sesuai!'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        return;
      }

      if (newPin.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN baru minimal harus 4 digit angka!'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        return;
      }

      if (newPin != confirmPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfirmasi PIN baru tidak cocok!'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        return;
      }

      newPinToSave = newPin;
    }

    setState(() => _isLoading = true);

    try {
      final settings = context.read<SettingsProvider>();
      final auth = context.read<AuthProvider>();

      // Update profil owner di SQLite / local storage via SettingsProvider
      final updatedOwner = await settings.updateOwnerProfile(
        name: name,
        newPin: newPinToSave,
      );

      // Selaraskan sesi AuthProvider yang sedang aktif
      if (updatedOwner != null) {
        auth.updateCurrentUserName(updatedOwner.name);
      } else {
        auth.updateCurrentUserName(name);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil Pemilik ($name) berhasil diperbarui!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.manage_accounts_rounded, color: AppTheme.primaryAmber, size: 24),
          SizedBox(width: 10),
          Text(
            'Profil Pemilik (Owner)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keterangan Ringkas
            Text(
              'Ubah nama tampilan pemilik toko dan kode PIN master.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Input Nama Lengkap Owner
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap Pemilik (Owner)',
                hintText: 'Contoh: H. Sukri, Budi Santoso',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Toggle Ganti PIN Master
            InkWell(
              onTap: () => setState(() => _changePin = !_changePin),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _changePin
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _changePin ? AppTheme.primaryAmber : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ubah PIN Master Owner juga?',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Form Ganti PIN (Jika dicentang)
            if (_changePin) ...[
              const SizedBox(height: 12),
              if (!auth.isOwnerMode) ...[
                TextField(
                  controller: _oldPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'PIN Lama Saat Ini',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.lock_clock_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _newPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN Baru (4–6 Digit)',
                  hintText: '••••',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi PIN Baru',
                  hintText: '••••',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAmber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Simpan Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
