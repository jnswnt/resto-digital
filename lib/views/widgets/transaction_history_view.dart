import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/pos_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/printer_receipt_service.dart';
import '../../services/csv_export_service.dart';
import '../../theme/app_theme.dart';
import 'whatsapp_receipt_dialog.dart';

/// Opsi Filter Waktu untuk Riwayat Transaksi
enum TransactionDateFilter {
  today,
  yesterday,
  last7Days,
  thisMonth,
  all,
  custom,
}

/// Widget Komprehensif Riwayat Transaksi Penjualan Resto.
/// Menyajikan pencarian real-time (No. Nota, Nama Tamu, Meja, Kasir),
/// filter rentang waktu & metode pembayaran (Tunai, QRIS, Kasbon),
/// ringkasan finansial, serta aksi Lihat Nota Visual, Cetak Thermal Ulang, & Kirim WA.
class TransactionHistoryView extends StatefulWidget {
  final bool isEmbedded;
  final bool showHeader;
  final VoidCallback? onClose;

  const TransactionHistoryView({
    super.key,
    this.isEmbedded = true,
    this.showHeader = true,
    this.onClose,
  });

  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  final _fullDateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionDateFilter _dateFilter = TransactionDateFilter.today;
  DateTimeRange? _customDateRange;
  String _paymentMethodFilter = 'all'; // 'all', 'cash', 'qris', 'debt'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Menghitung rentang tanggal aktif berdasarkan filter yang dipilih
  DateTimeRange? _getActiveDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_dateFilter) {
      case TransactionDateFilter.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case TransactionDateFilter.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59);
        return DateTimeRange(start: yStart, end: yEnd);
      case TransactionDateFilter.last7Days:
        final start7 = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: start7, end: todayEnd);
      case TransactionDateFilter.thisMonth:
        final mStart = DateTime(now.year, now.month, 1, 0, 0, 0);
        return DateTimeRange(start: mStart, end: todayEnd);
      case TransactionDateFilter.all:
        return null;
      case TransactionDateFilter.custom:
        if (_customDateRange != null) {
          final cStart = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
            0,
            0,
            0,
          );
          final cEnd = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
          return DateTimeRange(start: cStart, end: cEnd);
        }
        return DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final pos = context.watch<PosProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    final allTransactions = pos.transactions;
    final allOrders = pos.allOrders;

    // Filter transaksi berdasarkan tanggal, metode bayar, dan kata kunci pencarian
    final activeRange = _getActiveDateRange();
    final filteredTxs = allTransactions.where((tx) {
      // 1. Filter Tanggal
      if (activeRange != null) {
        if (tx.timestamp.isBefore(activeRange.start) || tx.timestamp.isAfter(activeRange.end)) {
          return false;
        }
      }

      // 2. Filter Metode Bayar
      if (_paymentMethodFilter != 'all' && tx.paymentMethod != _paymentMethodFilter) {
        return false;
      }

      // 3. Filter Kata Kunci Pencarian (No. Trx, No. Order, Tamu, Kasir, Meja)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = tx.id.toLowerCase().contains(q);
        final matchOrder = tx.orderId.toLowerCase().contains(q);
        final matchCustomer = (tx.customerName ?? '').toLowerCase().contains(q);
        final matchCashier = tx.cashierName.toLowerCase().contains(q);

        // Cari juga kecocokan nomor meja dari order terkait
        final relatedOrder = allOrders.cast<OrderModel?>().firstWhere(
          (o) => o?.id == tx.orderId,
          orElse: () => null,
        );
        final matchTable = (relatedOrder?.tableNo ?? '').toLowerCase().contains(q);

        if (!matchId && !matchOrder && !matchCustomer && !matchCashier && !matchTable) {
          return false;
        }
      }

      return true;
    }).toList();

    // Hitung ringkasan transaksi terfilter
    int totalFilteredAmount = 0;
    int totalCash = 0;
    int totalQris = 0;
    int totalDebt = 0;

    for (final tx in filteredTxs) {
      totalFilteredAmount += tx.totalAmount;
      if (tx.paymentMethod == 'cash') totalCash += tx.totalAmount;
      if (tx.paymentMethod == 'qris') totalQris += tx.totalAmount;
      if (tx.paymentMethod == 'debt') totalDebt += tx.totalAmount;
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Opsional (Jika dipanggil di modal dialog)
        if (widget.showHeader) ...[
          _buildHeaderBar(isDark, filteredTxs.length),
          const SizedBox(height: 12),
        ],

        // 2. Bar Pencarian & Tombol Ekspor CSV
        _buildSearchBarAndActions(isDark, filteredTxs, allOrders, pos),

        const SizedBox(height: 12),

        // 3. Filter Bar (Filter Waktu & Metode Pembayaran)
        _buildFiltersSection(isDark),

        const SizedBox(height: 14),

        // 4. Kartu Ringkasan Metrik Singkat
        _buildSummaryCard(
          isDark,
          filteredTxs.length,
          totalFilteredAmount,
          totalCash,
          totalQris,
          totalDebt,
          isMobile,
        ),

        const SizedBox(height: 16),

        // 5. Daftar Kartu Transaksi
        if (filteredTxs.isEmpty)
          _buildEmptyState(isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredTxs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = filteredTxs[index];
              final order = pos.findOrderById(tx.orderId, fallbackTx: tx);

              return _buildTransactionCard(
                context,
                isDark: isDark,
                tx: tx,
                order: order,
                settings: settings,
                isMobile: isMobile,
              );
            },
          ),
      ],
    );
  }

  // ==========================================================================
  // KOMPONEN HEADER & FILTER
  // ==========================================================================

  Widget _buildHeaderBar(bool isDark, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.primaryAmber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat Transaksi Penjualan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Log seluruh nota kasir yang berhasil dibayar ($count transaksi ditemukan)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (widget.onClose != null)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: widget.onClose,
            tooltip: 'Tutup Riwayat',
          ),
      ],
    );
  }

  Widget _buildSearchBarAndActions(
    bool isDark,
    List<TransactionModel> filteredTxs,
    List<OrderModel> allOrders,
    PosProvider pos,
  ) {
    final searchBg = isDark ? const Color(0xFF232530) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF323644) : const Color(0xFFE2E8F0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari No. Struk, Nama Tamu, Meja, Kasir...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tombol Salin CSV
        Tooltip(
          message: 'Salin Transaksi ke Format CSV (Excel/Sheets)',
          child: OutlinedButton.icon(
            onPressed: filteredTxs.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final csvText = CsvExportService.generateTransactionsCsv(
                      transactions: filteredTxs,
                      orders: allOrders,
                      products: pos.products,
                    );
                    final success = await CsvExportService.copyToClipboard(csvText);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Data ${filteredTxs.length} transaksi berhasil disalin ke clipboard!'
                              : 'Gagal menyalin CSV transaksi.',
                        ),
                        backgroundColor: success ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            icon: const Icon(Icons.table_chart_outlined, size: 16),
            label: const Text('Salin CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filter Rentang Waktu (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDateFilterChip(
                label: 'Hari Ini',
                isSelected: _dateFilter == TransactionDateFilter.today,
                onTap: () => setState(() => _dateFilter = TransactionDateFilter.today),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDateFilterChip(
                label: 'Kemarin',
                isSelected: _dateFilter == TransactionDateFilter.yesterday,
                onTap: () => setState(() => _dateFilter = TransactionDateFilter.yesterday),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDateFilterChip(
                label: '7 Hari Terakhir',
                isSelected: _dateFilter == TransactionDateFilter.last7Days,
                onTap: () => setState(() => _dateFilter = TransactionDateFilter.last7Days),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDateFilterChip(
                label: 'Bulan Ini',
                isSelected: _dateFilter == TransactionDateFilter.thisMonth,
                onTap: () => setState(() => _dateFilter = TransactionDateFilter.thisMonth),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDateFilterChip(
                label: 'Semua Waktu',
                isSelected: _dateFilter == TransactionDateFilter.all,
                onTap: () => setState(() => _dateFilter = TransactionDateFilter.all),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildDateFilterChip(
                label: _customDateRange == null
                    ? 'Pilih Tanggal...'
                    : '${_dateFormat.format(_customDateRange!.start)} - ${_dateFormat.format(_customDateRange!.end)}',
                isSelected: _dateFilter == TransactionDateFilter.custom,
                icon: Icons.date_range_rounded,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                    initialDateRange: _customDateRange ??
                        DateTimeRange(
                          start: now.subtract(const Duration(days: 7)),
                          end: now,
                        ),
                    locale: const Locale('id', 'ID'),
                  );
                  if (picked != null) {
                    setState(() {
                      _customDateRange = picked;
                      _dateFilter = TransactionDateFilter.custom;
                    });
                  }
                },
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Filter Metode Pembayaran
        Row(
          children: [
            Text(
              'Metode Bayar:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPaymentChip('all', 'Semua', Icons.all_inclusive_rounded, isDark),
                    const SizedBox(width: 6),
                    _buildPaymentChip('cash', 'Tunai', Icons.payments_rounded, isDark, const Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    _buildPaymentChip('qris', 'QRIS', Icons.qr_code_2_rounded, isDark, const Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    _buildPaymentChip('debt', 'Kasbon', Icons.menu_book_rounded, isDark, const Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
  }) {
    final activeBg = isDark ? const Color(0xFF1E3A2F) : const Color(0xFFD1FAE5);
    final activeText = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
    final idleBg = isDark ? const Color(0xFF232530) : const Color(0xFFF1F5F9);
    final idleText = isDark ? Colors.white70 : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : idleBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF323644) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? activeText : idleText),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeText : idleText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(
    String method,
    String label,
    IconData icon,
    bool isDark, [
    Color accentColor = const Color(0xFF10B981),
  ]) {
    final isSelected = _paymentMethodFilter == method;

    return InkWell(
      onTap: () => setState(() => _paymentMethodFilter = method),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF1E202B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF323644) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RINGKASAN METRIK TRANSAKSI
  // ==========================================================================

  Widget _buildSummaryCard(
    bool isDark,
    int count,
    int totalAmount,
    int cash,
    int qris,
    int debt,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C303E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL TRANSAKSI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '$count Pesanan',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL NOMINAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(totalAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildPaymentBreakdownRow(cash, qris, debt, isDark),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL PENJUALAN TERFILTER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(totalAmount),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 38,
                  width: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JUMLAH NOTA SELESAI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '$count Transaksi',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 38,
                  width: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  flex: 4,
                  child: _buildPaymentBreakdownRow(cash, qris, debt, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentBreakdownRow(int cash, int qris, int debt, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMiniPaymentStat('Tunai', cash, const Color(0xFF10B981), isDark),
        _buildMiniPaymentStat('QRIS', qris, const Color(0xFF0284C7), isDark),
        _buildMiniPaymentStat('Kasbon', debt, const Color(0xFFF59E0B), isDark),
      ],
    );
  }

  Widget _buildMiniPaymentStat(String label, int amount, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KARTU TRANSAKSI DETAIL
  // ==========================================================================

  Widget _buildTransactionCard(
    BuildContext context, {
    required bool isDark,
    required TransactionModel tx,
    required OrderModel order,
    required dynamic settings,
    required bool isMobile,
  }) {
    final cardBg = isDark ? const Color(0xFF191A23) : Colors.white;
    final borderColor = isDark ? const Color(0xFF282B38) : const Color(0xFFE2E8F0);

    final isRepayment = tx.orderId.startsWith('ord_repay_');

    // Format item summary (misal: "2x Kebab biasa, 1x Es Teh...")
    final itemsSummary = isRepayment
        ? 'Pelunasan Kasbon / Piutang a/n ${tx.customerName ?? order.customerName}'
        : (order.items.isEmpty
            ? 'Transaksi Penjualan'
            : order.items.map((i) => '${i.qty}x ${i.name}').join(', '));

    Color methodColor;
    String methodLabel;
    IconData methodIcon;

    if (tx.paymentMethod == 'cash') {
      methodColor = const Color(0xFF10B981);
      methodLabel = isRepayment ? 'PELUNASAN TUNAI' : 'TUNAI';
      methodIcon = Icons.payments_rounded;
    } else if (tx.paymentMethod == 'qris') {
      methodColor = const Color(0xFF0284C7);
      methodLabel = isRepayment ? 'PELUNASAN QRIS' : 'QRIS';
      methodIcon = Icons.qr_code_2_rounded;
    } else {
      methodColor = const Color(0xFFF59E0B);
      methodLabel = 'KASBON';
      methodIcon = Icons.menu_book_rounded;
    }

    final tableLabel = isRepayment
        ? 'Buku Kasbon'
        : (order.tableNo != null && order.tableNo!.isNotEmpty
            ? order.tableNo!
            : 'Takeaway');
    final customerLabel = order.customerName.isNotEmpty && order.customerName != 'Pelanggan'
        ? order.customerName
        : (tx.customerName ?? 'Pelanggan Umum');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: ID Transaksi, Waktu, Badge Metode Bayar & Nominal
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kiri: ID Transaksi & Waktu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${tx.id.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fullDateFormat.format(tx.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Kanan: Badge Metode Bayar & Nominal Transaksi
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge Metode Bayar (Dipindahkan ke kanan mendampingi nominal transaksi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: methodColor.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(methodIcon, size: 12, color: methodColor),
                        const SizedBox(width: 4),
                        Text(
                          methodLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: methodColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Nominal Transaksi
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(tx.totalAmount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                        ),
                      ),
                      if (tx.paymentMethod == 'cash' && tx.change > 0)
                        Text(
                          'Kembali: ${_currencyFormat.format(tx.change)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Baris 2: Info Meja, Pelanggan, Kasir, & Rincian Item
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meja & Tamu & Kasir
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoTag(Icons.table_restaurant_rounded, tableLabel, isDark),
                        _buildInfoTag(Icons.person_outline_rounded, customerLabel, isDark),
                        _buildInfoTag(Icons.badge_outlined, 'Kasir: ${tx.cashierName}', isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ringkasan Menu
                    Text(
                      itemsSummary,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris 3: Tombol Aksi (Lihat Nota, Kirim WA, Cetak Cepat)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 1. Tombol Kirim WA (Nota Digital Gambar)
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => WhatsappReceiptDialog(
                      order: order,
                      receiptNo: tx.id.toUpperCase(),
                      orderTime: tx.timestamp,
                      paymentMethod: tx.paymentMethod,
                      amountPaid: tx.amountPaid,
                      change: tx.change,
                      cashierName: tx.cashierName,
                      settings: settings,
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 14),
                label: const Text('Kirim WA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 34),
                  side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.6)),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Tombol Cetak Cepat Thermal
              OutlinedButton.icon(
                onPressed: () {
                  PrinterReceiptService.printReceiptDirect(
                    settings: settings,
                    order: order,
                    receiptNo: tx.id.toUpperCase(),
                    orderTime: tx.timestamp,
                    cashierName: tx.cashierName,
                    paymentMethod: tx.paymentMethod,
                    amountPaid: tx.amountPaid,
                    change: tx.change,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nota #${tx.id.toUpperCase()} dikirim ke printer.'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 14),
                label: const Text('Cetak Cepat', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 34),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(width: 8),

              // 3. Tombol Lihat Nota (Visual Live Paper)
              ElevatedButton.icon(
                onPressed: () {
                  PrinterReceiptService.showReceiptPreviewDialog(
                    context,
                    settings: settings,
                    order: order,
                    receiptNo: tx.id.toUpperCase(),
                    orderTime: tx.timestamp,
                    cashierName: tx.cashierName,
                    paymentMethod: tx.paymentMethod,
                    amountPaid: tx.amountPaid,
                    change: tx.change,
                  );
                },
                icon: const Icon(Icons.receipt_rounded, size: 15),
                label: const Text('Lihat Nota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 34),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232530) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STATE KOSONG (EMPTY STATE)
  // ==========================================================================

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C303E) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tidak ada transaksi dengan kata kunci "$_searchQuery"'
                : 'Belum Ada Transaksi Pada Periode Ini',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Coba gunakan kata kunci lain atau periksa ejaan nomor nota / pelanggan.'
                : 'Transaksi penjualan yang selesai dibayar kasir akan otomatis tercatat di sini.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _dateFilter != TransactionDateFilter.all || _paymentMethodFilter != 'all') ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _dateFilter = TransactionDateFilter.today;
                  _paymentMethodFilter = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filter & Tampilkan Hari Ini'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fungsi pembantu untuk membuka Dialog Modal Riwayat Transaksi langsung dari layar Kasir POS
Future<void> showTransactionHistoryDialog(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 800;

  return showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isWide ? 40 : 12,
          vertical: 24,
        ),
        child: Container(
          width: isWide ? 900 : double.infinity,
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: TransactionHistoryView(
                    showHeader: true,
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

