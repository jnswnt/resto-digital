import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/restaurant_table.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'table_qr_generator_screen.dart';

/// Halaman Khusus Pengaturan Denah Meja & Area Resto
/// - Tambah / Edit / Hapus Meja Fisik
/// - Atur Kapasitas Kursi & Pembagian Zona (Reguler, VIP, Outdoor, Lesehan)
/// - Penyesuaian Cepat Jumlah Meja
/// - Integrasi Cetak Stiker QR Meja Tamu
class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  static const String _prefsTablesKey = 'resto_configured_tables_v1';

  List<RestaurantTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsTablesKey);

      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(savedJson) as List<dynamic>;
        _tables = decoded.map((e) => RestaurantTable.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        _tables = RestaurantTable.getDefaultTables();
        await _saveTables();
      }
    } catch (_) {
      _tables = RestaurantTable.getDefaultTables();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_tables.map((t) => t.toMap()).toList());
      await prefs.setString(_prefsTablesKey, encoded);
    } catch (_) {}
  }

  void _showAddOrEditTableDialog({RestaurantTable? existingTable, int? index}) {
    final isEdit = existingTable != null && index != null;
    final nameCtrl = TextEditingController(text: isEdit ? existingTable.tableNumber : 'Meja ${(_tables.length + 1).toString().padLeft(2, '0')}');
    final capacityCtrl = TextEditingController(text: isEdit ? existingTable.capacity.toString() : '4');
    String selectedSection = isEdit ? existingTable.section : 'Reguler';

    const sections = ['Reguler', 'VIP', 'Outdoor', 'Lesehan'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: AppTheme.primaryAmber,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Edit ${existingTable.tableNumber}' : 'Tambah Meja Baru',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama / Nomor Meja',
                      hintText: 'Contoh: Meja 05, VIP 1, Lesehan B',
                      prefixIcon: const Icon(Icons.table_restaurant_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kapasitas Kursi (Orang)',
                      hintText: 'Contoh: 2, 4, 6, 8',
                      prefixIcon: const Icon(Icons.chair_alt_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Zona / Area Restoran:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: sections.map((sec) {
                      final isSelected = selectedSection == sec;
                      return ChoiceChip(
                        label: Text(sec),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryAmber,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : null,
                        ),
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedSection = sec);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final cap = int.tryParse(capacityCtrl.text.trim()) ?? 4;
                  if (name.isNotEmpty) {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isEdit) {
                        _tables[index] = existingTable.copyWith(
                          tableNumber: name,
                          capacity: cap,
                          section: selectedSection,
                        );
                      } else {
                        final id = 'T_${DateTime.now().millisecondsSinceEpoch}';
                        _tables.add(RestaurantTable(
                          id: id,
                          tableNumber: name,
                          section: selectedSection,
                          capacity: cap,
                          isActive: true,
                        ));
                      }
                    });
                    final messenger = ScaffoldMessenger.of(context);
                    await _saveTables();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? '$name berhasil diperbarui.' : '$name berhasil ditambahkan.'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isEdit ? 'Simpan' : 'Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickSetCountDialog() {
    final countCtrl = TextEditingController(text: _tables.length.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: AppTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Set Cepat Jumlah Meja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan jumlah total meja resto. Sistem akan membuat urutan meja otomatis (Meja 01 s.d Meja N):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Total Meja',
                hintText: 'Contoh: 12, 16, 20',
                prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final count = int.tryParse(countCtrl.text.trim()) ?? _tables.length;
              if (count > 0 && count <= 50) {
                Navigator.pop(ctx);
                setState(() {
                  _tables = List.generate(count, (index) {
                    final numStr = (index + 1).toString().padLeft(2, '0');
                    return RestaurantTable(
                      id: 'T$numStr',
                      tableNumber: 'Meja $numStr',
                      section: index < 8 ? 'Reguler' : 'Outdoor',
                      capacity: (index % 3 == 0) ? 6 : 4,
                      isActive: true,
                    );
                  });
                });
                final messenger = ScaffoldMessenger.of(context);
                await _saveTables();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Denah meja berhasil diatur menjadi $count meja.'),
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
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset ke 12 Meja Standar?'),
        content: const Text(
          'Seluruh daftar meja kustom akan dikembalikan ke konfigurasi bawaan resto (Meja 01 s/d Meja 12).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _tables = RestaurantTable.getDefaultTables();
              });
              final messenger = ScaffoldMessenger.of(context);
              await _saveTables();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Denah meja telah direset ke 12 meja standar.'),
                    backgroundColor: AppTheme.emeraldGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isTableEnabled = settingsProvider.settings.tableFeatureEnabled;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Meja & Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryAmber),
            tooltip: 'Cetak QR Meja Tamu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TableQrGeneratorScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'quick_count') _showQuickSetCountDialog();
              if (val == 'reset') _showResetConfirmDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'quick_count',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Set Cepat Jumlah Meja'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: AppTheme.dangerRed),
                    SizedBox(width: 8),
                    Text('Reset ke 12 Meja Standar', style: TextStyle(color: AppTheme.dangerRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditTableDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Meja', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryAmber,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
          : Column(
              children: [
                // KARTU MASTER TOGGLE FITUR MEJA
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isTableEnabled ? AppTheme.primaryAmber : Colors.grey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.table_restaurant_rounded,
                        color: isTableEnabled ? AppTheme.primaryAmber : Colors.grey,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Aktifkan Fitur Pemilihan Meja',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      isTableEnabled
                          ? 'Denah meja aktif di kasir dan pelanggan dapat memilih meja via Web QR.'
                          : 'Jika dimatikan, pesanan cukup menggunakan nama pemesan tanpa nomor meja.',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                    value: isTableEnabled,
                    activeThumbColor: AppTheme.primaryAmber,
                    onChanged: (val) => settingsProvider.toggleTableFeature(val),
                  ),
                ),

                if (!isTableEnabled)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryAmber),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fitur meja dinonaktifkan. Anda tetap dapat mengatur denah dan kapasitas meja di bawah ini.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // BANNER INFO & SHORTCUT CETAK QR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242735) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, color: Colors.black, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: ${_tables.length} Meja Terdaftar',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor),
                            ),
                            Text(
                              'Meja ini otomatis tampil di Denah Kasir & siap dipesan via Web QR.',
                              style: TextStyle(fontSize: 11, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TableQrGeneratorScreen()),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 14),
                        label: const Text('Cetak QR', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryAmber,
                          side: const BorderSide(color: AppTheme.primaryAmber),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),

                // DAFTAR MEJA
                Expanded(
                  child: _tables.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.table_restaurant_outlined, size: 54, color: textMuted.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              const Text('Belum ada meja terdaftar.', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => _showQuickSetCountDialog(),
                                child: const Text('Buat 12 Meja Standar Otomatis'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _tables.length,
                          itemBuilder: (context, index) {
                            final table = _tables[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    RestaurantTable.extractDigits(table.tableNumber).isEmpty
                                        ? '#'
                                        : RestaurantTable.extractDigits(table.tableNumber),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: AppTheme.primaryAmber,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  table.tableNumber,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor),
                                ),
                                subtitle: Text(
                                  'Zona: ${table.section} • Kapasitas: ${table.capacity} Orang',
                                  style: TextStyle(fontSize: 11.5, color: textMuted),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit Meja',
                                      onPressed: () => _showAddOrEditTableDialog(
                                        existingTable: table,
                                        index: index,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                                      tooltip: 'Hapus Meja',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text('Hapus ${table.tableNumber}?'),
                                            content: Text(
                                              'Apakah Anda yakin ingin menghapus ${table.tableNumber} dari denah restoran?',
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  setState(() {
                                                    _tables.removeAt(index);
                                                  });
                                                  await _saveTables();
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
                ),
              ],
            ),
    );
  }
}
