import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../models/user_model.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/owner_profile_dialog.dart';

/// Halaman Manajemen Akun Staf (Kasir & Koki Dapur).
/// Menyediakan manajemen staf yang lengkap: input Username, Nama Lengkap,
/// pemilihan Hak Akses (Kasir vs Koki Dapur), PIN rahasia, serta Kode QR Penautan HP Karyawan.
class CashierManagementScreen extends StatelessWidget {
  const CashierManagementScreen({super.key});

  /// Dialog formulir tambah / edit staf dengan desain modern dan input Username
  void _showStaffFormDialog({
    required BuildContext context,
    required SettingsProvider provider,
    UserModel? staffToEdit,
  }) {
    final isEdit = staffToEdit != null;
    final nameCtrl = TextEditingController(text: isEdit ? staffToEdit.name : '');
    final usernameCtrl = TextEditingController(text: isEdit ? staffToEdit.username : '');
    final pinCtrl = TextEditingController();
    String selectedRole = isEdit ? staffToEdit.role : 'cashier';
    bool obscurePin = true;
    String? localError;

    // Auto-generate username slug dari nama jika mode tambah staf baru
    if (!isEdit) {
      nameCtrl.addListener(() {
        final raw = nameCtrl.text.trim().toLowerCase();
        final slug = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
        usernameCtrl.text = slug;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF191B26) : Colors.white;
          final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
          final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
          final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: cardBg,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Dialog
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isEdit
                                ? (selectedRole == 'kitchen' ? Colors.orange.withValues(alpha: 0.16) : const Color(0xFF3B82F6).withValues(alpha: 0.16))
                                : AppTheme.primaryAmber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isEdit
                                ? (selectedRole == 'kitchen' ? Icons.soup_kitchen_rounded : Icons.point_of_sale_rounded)
                                : Icons.person_add_rounded,
                            color: isEdit
                                ? (selectedRole == 'kitchen' ? Colors.orange.shade700 : const Color(0xFF2563EB))
                                : AppTheme.primaryAmber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Edit Profil Staf' : 'Tambah Staf Baru',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEdit
                                    ? 'Perbarui identitas, username, dan akses staf @${staffToEdit.username}'
                                    : 'Daftarkan kasir toko atau koki dapur untuk bertugas',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                          onPressed: () => Navigator.pop(dlgCtx),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Input 1: Nama Lengkap Staf
                    Text(
                      'NAMA LENGKAP STAF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Siti Rahma, Lukman Hakim',
                        hintStyle: TextStyle(fontSize: 13, color: textMuted.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
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
                          borderSide: const BorderSide(color: AppTheme.primaryAmber, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input 2: Username Login (FITUR BARU)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'USERNAME LOGIN (UNIK)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: textMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'Huruf kecil & angka',
                          style: TextStyle(fontSize: 10.5, color: textMuted.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: usernameCtrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                      ],
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'contoh: sitikasir, lukmandapur',
                        hintStyle: TextStyle(fontSize: 13, color: textMuted.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20, color: AppTheme.primaryAmber),
                        helperText: 'Digunakan untuk login di Layar Kunci & penautan HP staf',
                        helperStyle: TextStyle(fontSize: 11, color: textMuted.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
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
                          borderSide: const BorderSide(color: AppTheme.primaryAmber, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Input 3: Pemilih Peran / Hak Akses Sistem (Interactive Cards)
                    Text(
                      'PERAN & HAK AKSES SISTEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Opsi 1: Kasir (POS)
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() => selectedRole = 'cashier'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedRole == 'cashier'
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.14)
                                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedRole == 'cashier'
                                      ? const Color(0xFF3B82F6)
                                      : borderColor,
                                  width: selectedRole == 'cashier' ? 1.8 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        Icons.point_of_sale_rounded,
                                        size: 22,
                                        color: selectedRole == 'cashier'
                                            ? const Color(0xFF2563EB)
                                            : textMuted,
                                      ),
                                      if (selectedRole == 'cashier')
                                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Kasir (POS)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedRole == 'cashier'
                                          ? textColor
                                          : textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Penjualan & kasir',
                                    style: TextStyle(fontSize: 10.5, color: textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Opsi 2: Koki Dapur (KDS)
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() => selectedRole = 'kitchen'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedRole == 'kitchen'
                                    ? Colors.orange.withValues(alpha: 0.16)
                                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedRole == 'kitchen'
                                      ? Colors.orange.shade700
                                      : borderColor,
                                  width: selectedRole == 'kitchen' ? 1.8 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        Icons.soup_kitchen_rounded,
                                        size: 22,
                                        color: selectedRole == 'kitchen'
                                            ? Colors.orange.shade700
                                            : textMuted,
                                      ),
                                      if (selectedRole == 'kitchen')
                                        Icon(Icons.check_circle_rounded, size: 16, color: Colors.orange.shade700),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Koki Dapur (KDS)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedRole == 'kitchen'
                                          ? textColor
                                          : textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Layar masak dapur',
                                    style: TextStyle(fontSize: 10.5, color: textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Input 4: PIN Staf (4-6 Digit)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'GANTI PIN BARU (OPSIONAL)' : 'PIN MASUK (4–6 DIGIT)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: textMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'Hanya angka',
                          style: TextStyle(fontSize: 10.5, color: textMuted.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 6,
                      obscureText: obscurePin,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: isEdit ? 'Kosongkan jika tidak ingin mengubah PIN' : 'Ketik 4–6 digit angka rahasia',
                        hintStyle: TextStyle(fontSize: 12.5, color: textMuted.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.password_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                            color: textMuted,
                          ),
                          onPressed: () => setDlgState(() => obscurePin = !obscurePin),
                          tooltip: obscurePin ? 'Lihat PIN' : 'Sembunyikan PIN',
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
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
                          borderSide: const BorderSide(color: AppTheme.primaryAmber, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),

                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Aksi Bawah
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textMuted,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final rawUsername = usernameCtrl.text.trim().toLowerCase();
                              final cleanUsername = rawUsername.replaceAll(RegExp(r'[^a-z0-9_]'), '');
                              final pin = pinCtrl.text.trim();

                              if (name.isEmpty) {
                                setDlgState(() => localError = 'Nama lengkap staf tidak boleh kosong.');
                                return;
                              }

                              if (cleanUsername.isEmpty) {
                                setDlgState(() => localError = 'Username staf tidak boleh kosong.');
                                return;
                              }

                              // Cek duplikasi username terhadap akun staf lain
                              final existing = provider.users.where((u) => u.username.toLowerCase() == cleanUsername);
                              if (isEdit) {
                                if (existing.any((u) => u.id != staffToEdit.id)) {
                                  setDlgState(() => localError = 'Username "@$cleanUsername" sudah digunakan staf lain.');
                                  return;
                                }
                              } else {
                                if (existing.isNotEmpty) {
                                  setDlgState(() => localError = 'Username "@$cleanUsername" sudah digunakan.');
                                  return;
                                }
                                if (pin.length < 4) {
                                  setDlgState(() => localError = 'PIN masuk staf minimal 4 digit angka.');
                                  return;
                                }
                              }

                              Navigator.pop(dlgCtx);

                              if (isEdit) {
                                await provider.updateStaff(
                                  id: staffToEdit.id,
                                  name: name,
                                  username: cleanUsername,
                                  role: selectedRole,
                                  newPin: pin.isNotEmpty ? pin : null,
                                );
                              } else {
                                await provider.addStaff(
                                  name: name,
                                  username: cleanUsername,
                                  pin: pin,
                                  role: selectedRole,
                                );
                              }

                              // Sinkronkan ke cloud backend SaaS
                              CloudSyncService(restoId: provider.settings.restoId).syncStaffToCloud(provider.allStaff);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEdit
                                        ? '✓ Data staf $name (@$cleanUsername) berhasil diperbarui.'
                                        : '✓ Staf $name (@$cleanUsername) berhasil ditambahkan.'),
                                    backgroundColor: AppTheme.emeraldGreen,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              isEdit ? 'Simpan Perubahan' : 'Simpan Staf Baru',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

    final provider = context.watch<SettingsProvider>();
    final allStaff = provider.allStaff;
    final ownerUser = provider.ownerUser;

    final cashierCount = allStaff.where((s) => s.isCashier && s.isActive).length;
    final kitchenCount = allStaff.where((s) => s.isKitchen && s.isActive).length;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manajemen Kasir & Staf Dapur',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${allStaff.length} staf terdaftar • Kelola akun, username, peran & PIN staf',
              style: TextStyle(fontSize: 11, color: textMuted),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffFormDialog(context: context, provider: provider),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Staf', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryAmber,
        foregroundColor: Colors.black,
        elevation: 3,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. STATISTIK RINGKASAN STAF
                _buildSummaryBar(
                  allStaff.length,
                  cashierCount,
                  kitchenCount,
                  isDark,
                  borderColor,
                  textColor,
                  textMuted,
                ),
                const SizedBox(height: 20),

                // 2. KARTU IDENTITAS OWNER (MASTER ADMIN)
                if (ownerUser != null) ...[
                  _buildOwnerCard(context, ownerUser, isDark, cardBg, borderColor, textColor, textMuted),
                  const SizedBox(height: 22),
                ],

                // 3. HEADER DAFTAR KRU TOKO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAFTAR KRU & OPERASIONAL TOKO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: textColor.withValues(alpha: 0.7),
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      '${allStaff.length} Akun',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. DAFTAR KARTU STAF KASIR & DAPUR
                if (allStaff.isEmpty)
                  _buildEmptyState(textMuted, isDark, cardBg, borderColor)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allStaff.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final staff = allStaff[index];
                      return _buildStaffItemCard(
                        context,
                        provider,
                        staff,
                        isDark,
                        cardBg,
                        borderColor,
                        textColor,
                        textMuted,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ringkasan statistik staf toko (Total, Kasir, Dapur)
  Widget _buildSummaryBar(
    int totalCount,
    int cashierCount,
    int kitchenCount,
    bool isDark,
    Color borderColor,
    Color textColor,
    Color textMuted,
  ) {
    return Row(
      children: [
        _buildMetricItem(
          label: 'Total Staf',
          value: '$totalCount',
          icon: Icons.people_alt_rounded,
          color: AppTheme.primaryAmber,
          isDark: isDark,
          borderColor: borderColor,
          textColor: textColor,
          textMuted: textMuted,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          label: 'Kasir POS Aktif',
          value: '$cashierCount',
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          borderColor: borderColor,
          textColor: textColor,
          textMuted: textMuted,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          label: 'Koki Dapur Aktif',
          value: '$kitchenCount',
          icon: Icons.soup_kitchen_rounded,
          color: Colors.orange.shade700,
          isDark: isDark,
          borderColor: borderColor,
          textColor: textColor,
          textMuted: textMuted,
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color borderColor,
    required Color textColor,
    required Color textMuted,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 10.5, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu identitas Master Admin (Pemilik Usaha / Owner)
  Widget _buildOwnerCard(
    BuildContext context,
    UserModel owner,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.star_rounded, color: Colors.black, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      owner.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MASTER OWNER',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryAmber,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${owner.username} • Pemilik resto dengan otoritas penuh ke seluruh sistem',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => OwnerProfileDialog.show(context),
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: const Text('Profil Owner', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryAmber,
              side: BorderSide(color: AppTheme.primaryAmber.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu profil staf kasir / dapur dengan tata letak modern
  Widget _buildStaffItemCard(
    BuildContext context,
    SettingsProvider provider,
    UserModel staff,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color textMuted,
  ) {
    final isKitchen = staff.isKitchen;
    final roleColor = isKitchen ? Colors.orange.shade700 : const Color(0xFF2563EB);
    final roleBg = isKitchen ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.15);
    final roleLabel = isKitchen ? 'KOKI DAPUR (KDS)' : 'KASIR (POS)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Staf
          CircleAvatar(
            radius: 22,
            backgroundColor: roleBg,
            child: Icon(
              isKitchen ? Icons.soup_kitchen_rounded : Icons.point_of_sale_rounded,
              color: roleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Detail Staf
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        staff.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '@${staff.username}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: textMuted, fontSize: 10)),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: staff.isActive ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      staff.isActive ? 'Aktif Bertugas' : 'Nonaktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: staff.isActive ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tombol-Tombol Aksi
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Tautkan HP Karyawan (QR Code)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppTheme.primaryAmber),
                tooltip: 'Tautkan HP Karyawan (Kode QR)',
                onPressed: () => _showPairingQrDialog(context, provider, staff),
              ),

              // 2. Switch Status Aktif
              Switch(
                value: staff.isActive,
                activeThumbColor: AppTheme.emeraldGreen,
                onChanged: (val) {
                  provider.toggleCashierStatus(staff.id, val);
                  CloudSyncService(restoId: provider.settings.restoId).syncStaffToCloud(provider.allStaff);
                },
              ),

              // 3. Tombol Edit Staf
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                tooltip: 'Edit Data & Username Staf',
                onPressed: () => _showStaffFormDialog(
                  context: context,
                  provider: provider,
                  staffToEdit: staff,
                ),
              ),

              // 4. Tombol Hapus Staf
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.dangerRed),
                tooltip: 'Hapus Staf',
                onPressed: () => _showDeleteConfirmDialog(context, provider, staff),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tampilan saat belum ada kru kasir atau dapur yang terdaftar
  Widget _buildEmptyState(Color textMuted, bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada staf kasir atau koki terdaftar.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Klik tombol "+ Tambah Staf" di bawah untuk mendaftarkan akun kasir atau koki.',
              style: TextStyle(fontSize: 12, color: textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog konfirmasi penghapusan akun staf
  void _showDeleteConfirmDialog(BuildContext context, SettingsProvider provider, UserModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
            const SizedBox(width: 8),
            Text('Hapus Staf ${staff.name}?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Akun @${staff.username} (${staff.name}) akan dihapus secara permanen dan tidak dapat login ke sistem kasir lagi.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteCashier(staff.id);
              CloudSyncService(restoId: provider.settings.restoId).syncStaffToCloud(provider.allStaff);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Akun @${staff.username} berhasil dihapus.'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
  }

  /// Menampilkan dialog Kode QR untuk ditautkan oleh HP Karyawan
  void _showPairingQrDialog(BuildContext context, SettingsProvider provider, UserModel staff) {
    final restoId = provider.settings.restoId;
    final storeName = provider.settings.storeName;
    final pairingPayload = jsonEncode({
      'action': 'pair_device',
      'restoId': restoId,
      'storeName': storeName,
      'username': staff.username,
      'name': staff.name,
      'role': staff.role,
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryAmber, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tautkan HP ${staff.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('@${staff.username} • ${staff.isKitchen ? "Role: Koki Dapur (KDS)" : "Role: Kasir POS"}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Arahkan kamera HP karyawan ke kode QR ini dari layar penautan perangkat untuk menghubungkan HP mereka secara instan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: QrImageView(
                data: pairingPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Resto ID:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(restoId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Username Staf:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('@${staff.username}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
