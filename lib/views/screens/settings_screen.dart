import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'store_profile_screen.dart';
import 'table_management_screen.dart';
import 'cashier_management_screen.dart';
import 'qris_config_screen.dart';
import 'table_qr_generator_screen.dart';
import 'printer_settings_screen.dart';
import 'cloud_config_screen.dart';
import '../widgets/owner_profile_dialog.dart';

/// Layar Pengaturan Utama (List Sub Menu - Bebas Tab)
/// Menyajikan navigasi pengaturan yang rapi, modular, dan memisahkan Profil Resto dengan Meja.
class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onCancel;

  const SettingsScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
    this.onCancel,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  String? _pinError;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    // Keamanan Akses Owner:
    // Jika user login bukan Owner atau mode Owner belum dibuka, tampilkan inline lock card.
    // Tidak menggunakan popup dialog agar tidak bocor otomatis saat login kasir.
    if (!auth.isOwnerMode) {
      return _buildOwnerLockScreen(context, isDark, auth);
    }

    final settingsProvider = context.watch<SettingsProvider>();

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER PROFIL RESTORAN RINGKAS
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => OwnerProfileDialog.show(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAmber,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.black, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settingsProvider.settings.storeName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settingsProvider.settings.address.isNotEmpty
                                    ? settingsProvider.settings.address
                                    : 'Restoran Belum Diisi Alamat',
                                style: TextStyle(fontSize: 11.5, color: textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Owner: ${settingsProvider.ownerUser?.name ?? auth.currentUser?.name ?? "H. Sukri (Owner)"}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryAmber,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit_rounded, size: 12, color: AppTheme.primaryAmber),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OWNER',
                            style: TextStyle(
                              color: AppTheme.emeraldGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==============================================================
              // GRUP 1: OPERASIONAL RESTORAN & DENAH MEJA
              // ==============================================================
              _buildSectionHeader('OPERASIONAL RESTO & MEJA', textColor),
              const SizedBox(height: 8),

              _buildMenuCard(
                context: context,
                icon: Icons.store_rounded,
                iconBg: const Color(0xFF3B82F6),
                title: 'Profil Restoran & Struk',
                subtitle: 'Nama resto, alamat, nomor WhatsApp, suara notifikasi, dan pesan footer nota belanja.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildMenuCard(
                context: context,
                icon: Icons.print_rounded,
                iconBg: const Color(0xFF0EA5E9),
                title: 'Pengaturan Printer & Struk',
                subtitle: 'Konfigurasi printer thermal (58mm/80mm), koneksi bluetooth/USB/LAN, auto-print, dan format nota.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildMenuCard(
                context: context,
                icon: Icons.table_restaurant_rounded,
                iconBg: const Color(0xFF10B981),
                title: 'Denah Meja & Area Resto',
                subtitle: 'Aktifkan fitur meja, kelola denah fisik (VIP/Lesehan), kapasitas kursi, dan zona.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TableManagementScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildMenuCard(
                context: context,
                icon: Icons.qr_code_2_rounded,
                iconBg: AppTheme.primaryAmber,
                iconColor: Colors.black,
                title: 'Cetak Stiker QR Meja Tamu',
                subtitle: 'Generator barcode QR meja untuk pemesanan mandiri tamu (Self-Ordering).',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TableQrGeneratorScreen()),
                  );
                },
              ),

              const SizedBox(height: 22),

              // ==============================================================
              // GRUP 2: PEMBAYARAN & INTEGRASI
              // ==============================================================
              _buildSectionHeader('PEMBAYARAN & TRANSAKSI', textColor),
              const SizedBox(height: 8),

              _buildMenuCard(
                context: context,
                icon: Icons.qr_code_scanner_rounded,
                iconBg: const Color(0xFF8B5CF6),
                title: 'QRIS Pembayaran Toko',
                subtitle: 'Konfigurasi stiker QRIS resmi, upload foto QRIS, dan payload EMVCo.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrisConfigScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildMenuCard(
                context: context,
                icon: Icons.cloud_sync_rounded,
                iconBg: const Color(0xFF0284C7),
                title: 'Integrasi Cloud & Multi-Tenant',
                subtitle: 'Pengaturan Firebase, Resto ID (isolasi data antar cabang), dan domain Web Self-Ordering.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CloudConfigScreen()),
                  );
                },
              ),

              const SizedBox(height: 22),

              // ==============================================================
              // GRUP 3: PENGGUNA & KEAMANAN OWNER
              // ==============================================================
              _buildSectionHeader('PENGGUNA & KEAMANAN', textColor),
              const SizedBox(height: 8),

              _buildMenuCard(
                context: context,
                icon: Icons.people_rounded,
                iconBg: const Color(0xFFF97316),
                title: 'Manajemen Akun Kasir',
                subtitle: 'Kelola akun kasir bertugas, tambah kasir, ganti PIN, dan aktif/nonaktifkan.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashierManagementScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildMenuCard(
                context: context,
                icon: Icons.manage_accounts_rounded,
                iconBg: const Color(0xFF64748B),
                title: 'Profil & PIN Pemilik (Owner)',
                subtitle: 'Ubah nama pemilik resto (${settingsProvider.ownerUser?.name ?? auth.currentUser?.name ?? "Owner"}) dan PIN rahasia master owner.',
                onTap: () => OwnerProfileDialog.show(context),
              ),

              const SizedBox(height: 28),

              // TOMBOL KUNCI PENGATURAN
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    auth.lockOwnerMode();
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    } else if (!widget.embedded && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text('Kunci Halaman Pengaturan'),
                  style: TextButton.styleFrom(
                    foregroundColor: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSidebar : Colors.white,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (widget.onOpenMenuDrawer != null) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: widget.onOpenMenuDrawer,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan Sistem',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Pilih sub menu pengaturan di bawah untuk mengelola resto',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Resto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: content,
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
          color: textColor.withValues(alpha: 0.6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    Color iconColor = Colors.white,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textMuted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Memverifikasi PIN Owner yang dimasukkan kasir/pengguna
  void _submitOwnerPin(AuthProvider auth) {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinError = 'Masukkan PIN Owner');
      return;
    }
    final isValid = auth.unlockOwnerMode(pin);
    if (isValid) {
      _pinCtrl.clear();
      setState(() => _pinError = null);
    } else {
      setState(() => _pinError = 'PIN Owner tidak valid!');
    }
  }

  /// Tampilan proteksi inline untuk halaman pengaturan toko
  Widget _buildOwnerLockScreen(BuildContext context, bool isDark, AuthProvider auth) {
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: widget.embedded
          ? AppBar(
              title: const Text('Pengaturan Resto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              leading: widget.onOpenMenuDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onOpenMenuDrawer,
                    )
                  : null,
            )
          : AppBar(
              title: const Text('Pengaturan Resto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 40,
                      color: AppTheme.primaryAmber,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Proteksi Hak Akses Owner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Halaman pengaturan memuat konfigurasi sensitif resto (meja, kasir, profil, QRIS). Masukkan PIN Owner untuk melanjutkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input PIN
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 22,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: TextStyle(
                        letterSpacing: 8,
                        color: textMuted.withValues(alpha: 0.5),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primaryAmber, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _submitOwnerPin(auth),
                  ),

                  if (_pinError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _pinError!,
                      style: const TextStyle(
                        color: AppTheme.dangerRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Tombol Buka Akses
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _submitOwnerPin(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Buka Pengaturan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tombol Batal / Kembali ke Halaman Sebelumnya
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _pinCtrl.clear();
                        setState(() => _pinError = null);
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Batal / Kembali'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMuted,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
