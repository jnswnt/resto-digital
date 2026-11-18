import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/transaction_history_view.dart';

/// Layar Mandiri Riwayat Transaksi Penjualan Resto (Transaction History Screen).
/// Menyajikan jurnal seluruh transaksi kasir yang telah selesai dibayar,
/// dilengkapi pencarian real-time, filter tanggal & metode bayar, ringkasan omzet,
/// serta tombol pratinjau nota visual, kirim WA bergambar, dan cetak thermal ulang.
class TransactionHistoryScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const TransactionHistoryScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final pos = context.watch<PosProvider>();

    final isMobile = MediaQuery.of(context).size.width < 700;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    Widget content = RefreshIndicator(
      onRefresh: () async {
        pos.loadData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Halaman Riwayat Transaksi
            _buildHeader(context, isDark, textColor, textMuted, pos),

            const SizedBox(height: 16),

            // 2. Konten Riwayat Transaksi Lengkap
            const TransactionHistoryView(
              isEmbedded: true,
              showHeader: false,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );

    if (embedded) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
        body: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: onOpenMenuDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: onOpenMenuDrawer,
                tooltip: 'Buka Menu',
              )
            : null,
      ),
      body: content,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color textMuted,
    PosProvider pos,
  ) {
    return Row(
      children: [
        if (onOpenMenuDrawer != null) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: onOpenMenuDrawer,
            tooltip: 'Buka Menu',
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.primaryAmber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppTheme.primaryAmber,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Log seluruh nota kasir, filter metode bayar & cetak ulang struk',
                style: TextStyle(fontSize: 12.5, color: textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan Riwayat',
          onPressed: () {
            pos.loadData();
          },
        ),
      ],
    );
  }
}
