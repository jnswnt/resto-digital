import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../models/user_model.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/app_theme.dart';

/// Halaman Sub Menu Khusus: Manajemen Akun Staf (Kasir & Koki Dapur)
/// Pemilik Resto (Owner) dapat menambah, mengedit, memilih peran (Kasir vs Dapur),
/// mengatur PIN rahasia, serta mengaktifkan/menonaktifkan akun staf.
class CashierManagementScreen extends StatelessWidget {
  const CashierManagementScreen({super.key});

  void _showAddStaffDialog(BuildContext context, SettingsProvider provider) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String selectedRole = 'cashier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_rounded, color: AppTheme.primaryAmber),
                SizedBox(width: 8),
                Text('Tambah Staf Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap Staf',
                    hintText: 'Contoh: Ahmad, Siti, Koki Juna',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Pilihan Peran Staf
                const Text('Peran / Hak Akses Sistem:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.point_of_sale_rounded, size: 16),
                        label: const Text('Kasir (POS)'),
                        selected: selectedRole == 'cashier',
                        selectedColor: AppTheme.primaryAmber,
                        onSelected: (val) {
                          if (val) setState(() => selectedRole = 'cashier');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.soup_kitchen_rounded, size: 16),
                        label: const Text('Koki Dapur (KDS)'),
                        selected: selectedRole == 'kitchen',
                        selectedColor: Colors.orange.shade400,
                        onSelected: (val) {
                          if (val) setState(() => selectedRole = 'kitchen');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'PIN Masuk (4–6 Digit)',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.password_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  if (name.isNotEmpty && pin.length >= 4) {
                    Navigator.pop(ctx);
                    await provider.addStaff(name: name, pin: pin, role: selectedRole);
                    if (context.mounted) {
                      final roleLabel = selectedRole == 'kitchen' ? 'Koki Dapur' : 'Kasir';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$roleLabel $name berhasil ditambahkan.'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Simpan Staf'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditStaffDialog(BuildContext context, SettingsProvider provider, UserModel staff) {
    final nameCtrl = TextEditingController(text: staff.name);
    final pinCtrl = TextEditingController();
    String selectedRole = staff.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit Staf: ${staff.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap Staf',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Peran / Hak Akses Sistem:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.point_of_sale_rounded, size: 16),
                        label: const Text('Kasir (POS)'),
                        selected: selectedRole == 'cashier',
                        selectedColor: AppTheme.primaryAmber,
                        onSelected: (val) {
                          if (val) setState(() => selectedRole = 'cashier');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.soup_kitchen_rounded, size: 16),
                        label: const Text('Koki Dapur (KDS)'),
                        selected: selectedRole == 'kitchen',
                        selectedColor: Colors.orange.shade400,
                        onSelected: (val) {
                          if (val) setState(() => selectedRole = 'kitchen');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Ganti PIN Baru (Kosongkan jika tidak diubah)',
                    hintText: '4–6 Digit Angka',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(ctx);
                    await provider.updateStaff(
                      id: staff.id,
                      name: name,
                      role: selectedRole,
                      newPin: pin.isNotEmpty ? pin : null,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Data staf $name berhasil diperbarui.'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Simpan'),
              ),
            ],
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
    final provider = context.watch<SettingsProvider>();
    final allStaff = provider.allStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Kasir & Staf Dapur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(context, provider),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Staf', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryAmber,
        foregroundColor: Colors.black,
      ),
      body: allStaff.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 54, color: textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  const Text('Belum ada staf terdaftar.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Klik tombol tambah staf untuk mendaftarkan kasir atau koki dapur.', style: TextStyle(fontSize: 12, color: textMuted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: allStaff.length,
              itemBuilder: (context, index) {
                final staff = allStaff[index];
                final isKitchen = staff.isKitchen;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isKitchen
                          ? Colors.orange.withValues(alpha: 0.15)
                          : AppTheme.emeraldGreen.withValues(alpha: 0.15),
                      child: Icon(
                        isKitchen ? Icons.soup_kitchen_rounded : Icons.person_rounded,
                        color: isKitchen ? Colors.orange.shade700 : AppTheme.emeraldGreen,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          staff.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isKitchen
                                ? Colors.orange.withValues(alpha: 0.15)
                                : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isKitchen ? 'KOKI DAPUR' : 'KASIR POS',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isKitchen ? Colors.orange.shade800 : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      staff.isActive ? 'Status: Aktif' : 'Status: Nonaktif',
                      style: TextStyle(
                        color: staff.isActive ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppTheme.primaryAmber),
                          tooltip: 'Tautkan HP Karyawan (Kode QR)',
                          onPressed: () => _showPairingQrDialog(context, provider, staff),
                        ),
                        Switch(
                          value: staff.isActive,
                          activeThumbColor: AppTheme.emeraldGreen,
                          onChanged: (val) {
                            provider.toggleCashierStatus(staff.id, val);
                            CloudSyncService(restoId: provider.settings.restoId).syncStaffToCloud(provider.allStaff);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Staf',
                          onPressed: () => _showEditStaffDialog(context, provider, staff),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                          tooltip: 'Hapus Staf',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Hapus Staf ${staff.name}?'),
                                content: const Text('Staf ini tidak akan dapat login lagi ke sistem.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await provider.deleteCashier(staff.id);
                                      CloudSyncService(restoId: provider.settings.restoId).syncStaffToCloud(provider.allStaff);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryAmber, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tautkan HP ${staff.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(staff.isKitchen ? 'Role: Koki Dapur (KDS)' : 'Role: Kasir POS', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
              style: TextStyle(fontSize: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Resto ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(restoId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Username:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(staff.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
