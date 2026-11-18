import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/sales_analytics_model.dart';

/// Layar Dashboard Laporan Penjualan & Analisis Bisnis Owner.
/// Menyajikan metrik KPI (Omzet, Laba Kotor, HPP, Kas Fisik),
/// peringkat menu terlaris, audit metode pembayaran, serta fitur kirim EOD WA & ekspor CSV.
class SalesAnalyticsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onCancel;

  const SalesAnalyticsScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
    this.onCancel,
  });

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

  String _pinInput = '';
  String? _pinError;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final auth = context.watch<AuthProvider>();
    final analytics = context.watch<AnalyticsProvider>();

    // Proteksi Hak Akses Owner:
    // Terbuka secara penuh jika user adalah Owner, atau telah di-unlock sementara oleh Owner.
    final canAccess = auth.isOwnerMode;

    if (!canAccess) {
      return _buildPinLockScreen(isDark, auth);
    }

    final summary = analytics.summary;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            analytics.calculateSummary();
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
                // 1. Header Bar
                _buildHeader(isDark, analytics, auth),

                const SizedBox(height: 16),

                // 2. Bar Pemilih Rentang Waktu (Filter Chips)
                _buildDateFilterSection(isDark, analytics),

                const SizedBox(height: 18),

                // 3. Grid 4 Kartu KPI Finansial
                _buildKpiGrid(isDark, summary, isMobile),

                const SizedBox(height: 20),

                // 4. Baris 2 Kolom (Metode Pembayaran & Aksi Rekap)
                if (isMobile) ...[
                  _buildPaymentAuditCard(isDark, summary),
                  const SizedBox(height: 16),
                  _buildQuickActionButtons(isDark, analytics, auth),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildPaymentAuditCard(isDark, summary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _buildQuickActionButtons(isDark, analytics, auth),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // 5. Tabel Peringkat Menu Terlaris (Best Seller Leaderboard)
                _buildTopSellingSection(isDark, summary),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // KOMPONEN HEADER & FILTER
  // ==========================================================================

  Widget _buildHeader(bool isDark, AnalyticsProvider analytics, AuthProvider auth) {
    return Row(
      children: [
        if (widget.onOpenMenuDrawer != null) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: widget.onOpenMenuDrawer,
            tooltip: 'Buka Menu',
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Laporan & Analitik',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Owner Mode',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ringkasan omzet, laba kotor HPP & audit kas masuk',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan Data',
          onPressed: () {
            analytics.calculateSummary();
          },
        ),
        if (auth.currentUser?.isOwner != true) ...[
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Kunci Akses Laporan',
            onPressed: () {
              auth.lockOwnerMode();
              if (widget.onCancel != null) {
                widget.onCancel!();
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDateFilterSection(bool isDark, AnalyticsProvider analytics) {
    final filter = analytics.selectedFilter;
    final summary = analytics.summary;

    final dateRangeLabel = '${_dateFormat.format(summary.startDate)} - ${_dateFormat.format(summary.endDate)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RENTANG WAKTU:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateRangeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Hari Ini', AnalyticsDateFilter.today, filter, () {
                  analytics.setFilter(AnalyticsDateFilter.today);
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Kemarin', AnalyticsDateFilter.yesterday, filter, () {
                  analytics.setFilter(AnalyticsDateFilter.yesterday);
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('7 Hari Terakhir', AnalyticsDateFilter.last7Days, filter, () {
                  analytics.setFilter(AnalyticsDateFilter.last7Days);
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Bulan Ini', AnalyticsDateFilter.thisMonth, filter, () {
                  analytics.setFilter(AnalyticsDateFilter.thisMonth);
                }, isDark),
                const SizedBox(width: 8),
                _buildCustomCalendarChip(analytics, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    AnalyticsDateFilter type,
    AnalyticsDateFilter current,
    VoidCallback onTap,
    bool isDark,
  ) {
    final isSelected = type == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAmber
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.black
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCalendarChip(AnalyticsProvider analytics, bool isDark) {
    final isSelected = analytics.selectedFilter == AnalyticsDateFilter.custom;

    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: analytics.customDateRange ??
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now(),
              ),
          helpText: 'PILIH RENTANG TANGGAL LAPORAN',
          cancelText: 'BATAL',
          confirmText: 'PILIH',
        );

        if (picked != null) {
          analytics.setCustomRange(picked);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAmber
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 5),
            Text(
              'Pilih Kalender...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // GRID 4 KARTU KPI
  // ==========================================================================

  Widget _buildKpiGrid(bool isDark, SalesSummary summary, bool isMobile) {
    final card1 = _buildMetricCard(
      title: 'Total Omzet Bersih',
      value: _currencyFormat.format(summary.netRevenue),
      subtitle: '${summary.transactionCount} Transaksi Selesai',
      icon: Icons.monetization_on_rounded,
      iconColor: const Color(0xFF10B981),
      bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
      isDark: isDark,
    );

    final card2 = _buildMetricCard(
      title: 'Estimasi Laba Kotor',
      value: _currencyFormat.format(summary.grossProfit),
      subtitle: 'Margin Laba: ${summary.profitMargin.toStringAsFixed(1)}%',
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFF38BDF8),
      bgColor: const Color(0xFF38BDF8).withValues(alpha: 0.12),
      isDark: isDark,
      badgeText: '${summary.profitMargin.toStringAsFixed(0)}% Margin',
    );

    final card3 = _buildMetricCard(
      title: 'Total Modal HPP',
      value: _currencyFormat.format(summary.totalCogs),
      subtitle: 'Biaya pokok bahan terjual',
      icon: Icons.shopping_bag_outlined,
      iconColor: const Color(0xFFF59E0B),
      bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      isDark: isDark,
    );

    final card4 = _buildMetricCard(
      title: 'Kas Fisik di Laci',
      value: _currencyFormat.format(summary.cashTotal),
      subtitle: 'Uang tunai wajib setor',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF8B5CF6),
      bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
      isDark: isDark,
    );

    if (isMobile) {
      return Column(
        children: [
          Row(children: [Expanded(child: card1), const SizedBox(width: 10), Expanded(child: card2)]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: card3), const SizedBox(width: 10), Expanded(child: card4)]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 12),
        Expanded(child: card2),
        const SizedBox(width: 12),
        Expanded(child: card3),
        const SizedBox(width: 12),
        Expanded(child: card4),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppTheme.darkTextSecondary.withValues(alpha: 0.8) : AppTheme.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AUDIT METODE PEMBAYARAN
  // ==========================================================================

  Widget _buildPaymentAuditCard(bool isDark, SalesSummary summary) {
    final total = summary.totalRevenue > 0 ? summary.totalRevenue : 1;
    final cashPct = (summary.cashTotal / total);
    final qrisPct = (summary.qrisTotal / total);
    final debtPct = (summary.debtTotal / total);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 18, color: AppTheme.primaryAmber),
              const SizedBox(width: 8),
              Text(
                'Audit Saldo Kasir (Metode Bayar)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Baris Visual Progress Proporsi Pembayaran
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (cashPct > 0)
                    Expanded(
                      flex: (cashPct * 100).toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (qrisPct > 0)
                    Expanded(
                      flex: (qrisPct * 100).toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFF38BDF8)),
                    ),
                  if (debtPct > 0)
                    Expanded(
                      flex: (debtPct * 100).toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFFF43F5E)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List Rincian Nominal & Persentase
          _buildPaymentRow(
            title: 'Uang Tunai (Cash)',
            subtitle: 'Harus ada fisik di laci',
            amount: summary.cashTotal,
            percentage: cashPct * 100,
            color: const Color(0xFF10B981),
            icon: Icons.payments_rounded,
            isDark: isDark,
          ),
          const Divider(height: 18),
          _buildPaymentRow(
            title: 'QRIS Statis / Dinamis',
            subtitle: 'Masuk rekening bank BCA toko',
            amount: summary.qrisTotal,
            percentage: qrisPct * 100,
            color: const Color(0xFF38BDF8),
            icon: Icons.qr_code_2_rounded,
            isDark: isDark,
          ),
          if (summary.debtTotal > 0) ...[
            const Divider(height: 18),
            _buildPaymentRow(
              title: 'Kasbon Pelanggan (Piutang)',
              subtitle: 'Belum dibayar lunas',
              amount: summary.debtTotal,
              percentage: debtPct * 100,
              color: const Color(0xFFF43F5E),
              icon: Icons.receipt_long_rounded,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String title,
    required String subtitle,
    required int amount,
    required double percentage,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // TOMBOL AKSI CEPAT (EOD WA & EXPORT CSV)
  // ==========================================================================

  Widget _buildQuickActionButtons(
    bool isDark,
    AnalyticsProvider analytics,
    AuthProvider auth,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'Aksi Laporan Cepat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tombol 1: Kirim WA Tutup Kasir EOD
          ElevatedButton.icon(
            onPressed: () => _showSendEodDialog(analytics, auth),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Kirim Rekap WA Owner',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol 2: Ekspor CSV
          OutlinedButton.icon(
            onPressed: () => _showExportCsvDialog(analytics),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text(
              'Ekspor Laporan CSV',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PERINGKAT MENU TERLARIS
  // ==========================================================================

  Widget _buildTopSellingSection(bool isDark, SalesSummary summary) {
    final items = summary.topSellingItems;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded, size: 20, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(
                    'Peringkat Menu Terlaris (Leaderboard)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${items.length} Menu Terjual',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada transaksi pada rentang waktu ini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Header Tabel
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 30, child: Text('#', style: _tableHeaderStyle(isDark))),
                  Expanded(flex: 4, child: Text('MENU', style: _tableHeaderStyle(isDark))),
                  Expanded(flex: 2, child: Text('TERJUAL', textAlign: TextAlign.center, style: _tableHeaderStyle(isDark))),
                  Expanded(flex: 3, child: Text('OMZET', textAlign: TextAlign.right, style: _tableHeaderStyle(isDark))),
                  Expanded(flex: 3, child: Text('LABA KOTOR', textAlign: TextAlign.right, style: _tableHeaderStyle(isDark))),
                ],
              ),
            ),
            const Divider(height: 1),

            // Daftar Baris Item
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final rank = idx + 1;

                Color rankBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
                Color rankColor = isDark ? Colors.white70 : Colors.black87;

                if (rank == 1) {
                  rankBg = const Color(0xFFFEF3C7);
                  rankColor = const Color(0xFFD97706);
                } else if (rank == 2) {
                  rankBg = const Color(0xFFF1F5F9);
                  rankColor = const Color(0xFF64748B);
                } else if (rank == 3) {
                  rankBg = const Color(0xFFFFEDD5);
                  rankColor = const Color(0xFFC2410C);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
                          child: Text(
                            rank.toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: rankColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.qtySold} porsi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _currencyFormat.format(item.totalRevenue),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(item.totalProfit),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              '${item.profitMargin.toStringAsFixed(0)}% margin',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle(bool isDark) {
    return TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.bold,
      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
      letterSpacing: 0.5,
    );
  }

  // ==========================================================================
  // DIALOG EOD WHATSAPP & EXPORT CSV
  // ==========================================================================

  void _showSendEodDialog(AnalyticsProvider analytics, AuthProvider auth) {
    final noteController = TextEditingController();
    final cashierName = auth.currentUser?.name ?? 'Kasir';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('Kirim Laporan Tutup Kasir'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laporan penutupan kasir (End of Day) akan diformat rapi dan langsung dikirimkan ke WhatsApp Pemilik Resto.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Catatan Kasir Tambahan (Opsional)',
                  hintText: 'Contoh: Sisa kasbon meja 2 akan dilunasi besok...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await analytics.sendEodReportToWhatsApp(
                cashierName: cashierName,
                note: noteController.text,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Aplikasi WhatsApp terbuka untuk mengirim laporan.'
                          : 'Gagal membuka WhatsApp. Pastikan nomor HP Owner telah diatur di Pengaturan.',
                    ),
                    backgroundColor: success ? const Color(0xFF10B981) : AppTheme.dangerRed,
                  ),
                );
              }
            },
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
            label: const Text('Kirim ke WhatsApp'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }

  void _showExportCsvDialog(AnalyticsProvider analytics) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ekspor Laporan ke Format CSV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih jenis data laporan yang ingin disalin atau diekspor ke format CSV (Excel/Sheets):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryAmber),
                title: const Text('Rincian Transaksi Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Daftar struk, item menu, modal HPP, harga jual & laba per item', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.copy_rounded, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await analytics.copyTransactionsCsvToClipboard();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '📋 Data CSV Transaksi berhasil disalin ke Clipboard! Siap ditempel ke Google Sheets / Excel.'
                              : 'Gagal menyalin CSV.',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),

              ListTile(
                leading: const Icon(Icons.military_tech_rounded, color: Color(0xFF38BDF8)),
                title: const Text('Peringkat Menu Terlaris', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Rangking menu, porsi terjual, omzet total & persentase margin laba', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.copy_rounded, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await analytics.copyMenuRankingCsvToClipboard();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '📋 Data CSV Peringkat Menu berhasil disalin ke Clipboard! Siap ditempel ke Google Sheets / Excel.'
                              : 'Gagal menyalin CSV.',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PROTEKSI PIN OWNER
  // ==========================================================================

  Widget _buildPinLockScreen(bool isDark, AuthProvider auth) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: widget.embedded
          ? AppBar(
              title: const Text('Laporan & Analitik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              leading: widget.onOpenMenuDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onOpenMenuDrawer,
                    )
                  : null,
            )
          : AppBar(
              title: const Text('Laporan & Analitik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: AppTheme.primaryAmber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Proteksi Hak Akses Owner',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Laporan keuangan & analitik profit dilindungi. Masukkan PIN Owner untuk melanjutkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Display Dot PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _pinInput.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? AppTheme.primaryAmber
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      );
                    }),
                  ),

                  if (_pinError != null) ...[
                    const SizedBox(height: 12),
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

                  // Numpad Touch
                  _buildNumpadGrid(isDark, auth),

                  const SizedBox(height: 16),

                  // Tombol Batal / Kembali ke Halaman Sebelumnya
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _pinInput = '';
                          _pinError = null;
                        });
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Batal / Kembali'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _buildNumpadGrid(bool isDark, AuthProvider auth) {
    return Column(
      children: [
        Row(
          children: [
            _numpadBtn('1', isDark, auth),
            _numpadBtn('2', isDark, auth),
            _numpadBtn('3', isDark, auth),
          ],
        ),
        Row(
          children: [
            _numpadBtn('4', isDark, auth),
            _numpadBtn('5', isDark, auth),
            _numpadBtn('6', isDark, auth),
          ],
        ),
        Row(
          children: [
            _numpadBtn('7', isDark, auth),
            _numpadBtn('8', isDark, auth),
            _numpadBtn('9', isDark, auth),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _pinInput = '';
                      _pinError = null;
                    });
                  },
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            ),
            _numpadBtn('0', isDark, auth),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 20),
                  onPressed: () {
                    if (_pinInput.isNotEmpty) {
                      setState(() {
                        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
                        _pinError = null;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numpadBtn(String digit, bool isDark, AuthProvider auth) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () {
            if (_pinInput.length < 4) {
              setState(() {
                _pinInput += digit;
                _pinError = null;
              });

              if (_pinInput.length == 4) {
                final isValid = auth.unlockOwnerMode(_pinInput);
                if (isValid) {
                  setState(() {
                    _pinError = null;
                    _pinInput = '';
                  });
                } else {
                  setState(() {
                    _pinError = 'PIN Owner tidak valid!';
                    _pinInput = '';
                  });
                }
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
