import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/petty_cash_dialog.dart';

/// Layar Manajemen Shift Kasir & Rekonsiliasi Arus Kas Laci.
class ShiftScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const ShiftScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final authProvider = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    Widget bodyContent = shiftProvider.hasActiveShift
        ? _buildActiveShiftView(context, shiftProvider, currencyFormat, isDark, textColor, textMuted, borderColor)
        : _buildStartShiftView(context, shiftProvider, authProvider, currencyFormat, isDark, textColor, textMuted);

    if (embedded) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSidebar : Colors.white,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (onOpenMenuDrawer != null) ...[
                        IconButton(
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: onOpenMenuDrawer,
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
                              'Shift & Arus Kas',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Modal awal & pengeluaran kas',
                              style: TextStyle(fontSize: 11, color: textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Shift & Arus Kas')),
      body: bodyContent,
    );
  }

  // --- Tampilan Jika Belum Ada Shift Aktif (Buka Shift) ---
  Widget _buildStartShiftView(
    BuildContext context,
    ShiftProvider shiftProvider,
    AuthProvider authProvider,
    NumberFormat currencyFormat,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    final modalCtrl = TextEditingController(text: '100000');
    final currentUser = authProvider.currentUser;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock_rounded, size: 32, color: AppTheme.primaryAmber),
              ),
              const SizedBox(height: 16),
              Text(
                'Buka Shift Kasir Baru',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Kasir Bertugas: ${currentUser?.name ?? "Kasir"}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: modalCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                decoration: const InputDecoration(
                  labelText: 'Modal Awal Kas Laci (Pecahan Kembalian)',
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [50000, 100000, 150000, 200000].map((amt) {
                  return ActionChip(
                    label: Text(currencyFormat.format(amt)),
                    backgroundColor: isDark ? const Color(0xFF2C2F3D) : Colors.brown.shade50,
                    onPressed: () => modalCtrl.text = amt.toString(),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final initial = int.tryParse(modalCtrl.text.trim()) ?? 0;
                  if (currentUser != null) {
                    await shiftProvider.startShift(
                      cashier: currentUser,
                      initialCash: initial,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Buka Shift Sekarang'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tampilan Jika Shift Sedang Berjalan (Multi-Resolusi & Anti-Overflow) ---
  Widget _buildActiveShiftView(
    BuildContext context,
    ShiftProvider shiftProvider,
    NumberFormat currencyFormat,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
  ) {
    final shift = shiftProvider.activeShift!;
    final movements = shiftProvider.cashMovements;
    final timeFormat = DateFormat('HH:mm, dd MMM yyyy');
    final expectedCash = shift.expectedCash;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile
            ? ((constraints.maxWidth - 40 - 12) / 2).clamp(140.0, 300.0)
            : ((constraints.maxWidth - 40 - 28) / 3).clamp(180.0, 360.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Status Shift Aktif
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E202B), const Color(0xFF282B38)]
                        : [const Color(0xFF2C221E), const Color(0xFF3E2723)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'SHIFT AKTIF BERJALAN',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Mulai: ${DateFormat('HH:mm').format(shift.startedAt)} WIB',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kasir Bertugas:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                    Text(
                                      shift.cashierName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Kas Laci Sistem:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  Text(
                                    currencyFormat.format(expectedCash),
                                    style: const TextStyle(
                                      color: AppTheme.primaryAmber,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'SHIFT AKTIF BERJALAN',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kasir: ${shift.cashierName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Mulai: ${timeFormat.format(shift.startedAt)} WIB',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Kas Laci Sistem:',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                currencyFormat.format(expectedCash),
                                style: const TextStyle(
                                  color: AppTheme.primaryAmber,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Grid Komponen Arus Kas (Proporsional & Anti-Overflow)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard('Modal Awal Laci', currencyFormat.format(shift.initialCash), Icons.savings, Colors.blue, isDark, textColor, textMuted, borderColor, width: cardWidth),
                  _buildMetricCard('Penjualan Tunai', currencyFormat.format(shift.totalCashSales), Icons.attach_money, Colors.green, isDark, textColor, textMuted, borderColor, width: cardWidth),
                  _buildMetricCard('Penjualan QRIS', currencyFormat.format(shift.totalQrisSales), Icons.qr_code, Colors.purple, isDark, textColor, textMuted, borderColor, width: cardWidth),
                  _buildMetricCard('Penjualan Kasbon', currencyFormat.format(shift.totalDebtSales), Icons.menu_book, Colors.orange, isDark, textColor, textMuted, borderColor, width: cardWidth),
                  _buildMetricCard('Pelunasan Kasbon Masuk', currencyFormat.format(shift.totalDebtRepaidCash), Icons.price_check, Colors.teal, isDark, textColor, textMuted, borderColor, width: cardWidth),
                  _buildMetricCard('Kas Keluar (Petty Cash)', currencyFormat.format(shift.totalCashOut), Icons.outbox, Colors.red, isDark, textColor, textMuted, borderColor, width: cardWidth),
                ],
              ),
              const SizedBox(height: 22),

              // Tombol Aksi Shift (Responsif: Bertumpuk di Mobile agar Tidak Meluap, Bersebelahan di Layar Lebar)
              if (isMobile) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => PettyCashDialog(
                        onRecorded: (amount, notes) async {
                          await shiftProvider.recordPettyCashOut(
                            amount: amount,
                            notes: notes,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kas keluar ${currencyFormat.format(amount)} ($notes) tercatat')),
                            );
                          }
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Catat Kas Keluar (Beli Es/Gas/Galon)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showCloseShiftDialog(context, shiftProvider, currencyFormat),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2F3D) : AppTheme.darkSidebar,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Tutup Shift & Rekonsiliasi Kas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => PettyCashDialog(
                              onRecorded: (amount, notes) async {
                                await shiftProvider.recordPettyCashOut(
                                  amount: amount,
                                  notes: notes,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Kas keluar ${currencyFormat.format(amount)} ($notes) tercatat')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('Catat Kas Keluar (Beli Es/Gas/Galon)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCloseShiftDialog(context, shiftProvider, currencyFormat),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2C2F3D) : AppTheme.darkSidebar,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Tutup Shift & Rekonsiliasi Kas', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 26),

              // Riwayat Pengeluaran Kas Keluar Shift Ini
              Text(
                'Riwayat Pengeluaran Kas Kecil Shift Ini:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              movements.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardSurface : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text('Belum ada pengeluaran kas laci pada shift ini.', style: TextStyle(color: textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: movements.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final mov = movements[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardSurface : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                radius: 16,
                                child: Icon(Icons.arrow_upward, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mov.notes, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                    Text(DateFormat('HH:mm').format(mov.timestamp), style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ),
                              Text(
                                '- ${currencyFormat.format(mov.amount)}',
                                style: const TextStyle(
                                  color: AppTheme.dangerRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor, {
    double? width,
  }) {
    return Container(
      width: width ?? 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(
    BuildContext context,
    ShiftProvider shiftProvider,
    NumberFormat currencyFormat,
  ) {
    final actualCashCtrl = TextEditingController();
    final expectedCash = shiftProvider.activeShift!.expectedCash;
    final settings = context.read<SettingsProvider>().settings;

    showDialog(
      context: context,
      builder: (ctx) {
        int diff = 0;
        return StatefulBuilder(
          builder: (context, setState) {
            final actual = int.tryParse(actualCashCtrl.text.trim()) ?? 0;
            diff = actual - expectedCash;

            Color diffColor = Colors.grey;
            String diffLabel = 'Belum dihitung';
            if (actualCashCtrl.text.isNotEmpty) {
              if (diff == 0) {
                diffColor = AppTheme.emeraldGreen;
                diffLabel = 'SESUAI (Uang laci pas)';
              } else if (diff < 0) {
                diffColor = AppTheme.dangerRed;
                diffLabel = 'SELISIH KURANG (${currencyFormat.format(diff.abs())})';
              } else {
                diffColor = Colors.blue;
                diffLabel = 'SELISIH LEBIH (${currencyFormat.format(diff)})';
              }
            }

            return AlertDialog(
              title: const Text('Tutup Shift & Rekonsiliasi Kas'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kas Sistem (Seharusnya Ada):', style: TextStyle(fontSize: 13, color: Colors.black87)),
                          Text(
                            currencyFormat.format(expectedCash),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: actualCashCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Hitung Uang Fisik Aktual di Laci (Rp)',
                        prefixText: 'Rp ',
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: diffColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hasil Rekonsiliasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            diffLabel,
                            style: TextStyle(fontWeight: FontWeight.bold, color: diffColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: actualCashCtrl.text.isEmpty
                      ? null
                      : () async {
                          final closed = await shiftProvider.closeShift(actualCash: actual);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final summaryMsg = '*Laporan Tutup Shift Resto*\n'
                                'Kasir: ${closed.cashierName}\n'
                                'Modal Awal: ${currencyFormat.format(closed.initialCash)}\n'
                                'Penjualan Tunai: ${currencyFormat.format(closed.totalCashSales)}\n'
                                'Penjualan QRIS: ${currencyFormat.format(closed.totalQrisSales)}\n'
                                'Kasbon Masuk: ${currencyFormat.format(closed.totalDebtRepaidCash)}\n'
                                'Kas Keluar: ${currencyFormat.format(closed.totalCashOut)}\n'
                                'Kas Seharusnya: ${currencyFormat.format(closed.expectedCash)}\n'
                                'Kas Fisik: ${currencyFormat.format(closed.actualCash)}\n'
                                'Selisih: ${currencyFormat.format(closed.difference)}';

                            WhatsappService.openWhatsApp(
                              phone: settings.phoneWA,
                              message: summaryMsg,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAmber, foregroundColor: Colors.black),
                  child: const Text('Selesaikan & Tutup Shift'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
