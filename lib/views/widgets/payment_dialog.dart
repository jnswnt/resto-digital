import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/customer_model.dart';
import '../../services/qris_service.dart';
import '../../theme/app_theme.dart';

/// Dialog Pembayaran Kasir Modern, Ergonomis, dan Fit-Content (Tinggi Pas Mengikuti Konten).
/// Mendukung Tunai (Cash dengan kalkulator uang pas & pecahan cepat),
/// QRIS Auto-Nominal (dengan pengingat cek mutasi rekening), dan Kasbon (Utang).
class PaymentDialog extends StatefulWidget {
  final int totalAmount;
  final String? initialCustomerName;
  final Function({
    required String paymentMethod,
    required int amountPaid,
    required int change,
    String? customerId,
    String? customerName,
  }) onPaymentCompleted;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    this.initialCustomerName,
    required this.onPaymentCompleted,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Tab Index: 0 = Tunai, 1 = QRIS Auto, 2 = Kasbon
  int _selectedTabIndex = 0;

  // State Pembayaran Tunai
  int _cashPaid = 0;
  final TextEditingController _cashController = TextEditingController();

  // State Pembayaran Kasbon
  CustomerModel? _selectedCustomer;

  // State Verifikasi Mutasi QRIS
  bool _isQrisVerified = false;

  @override
  void initState() {
    super.initState();
    _cashPaid = widget.totalAmount;
    _cashController.text = widget.totalAmount.toString();
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  /// Mengatur nominal uang tunai yang diterima
  void _setCash(int amount) {
    setState(() {
      _cashPaid = amount;
      _cashController.text = amount.toString();
    });
  }

  int get _cashChange => (_cashPaid - widget.totalAmount).clamp(0, 999999999);
  bool get _isCashSufficient => _cashPaid >= widget.totalAmount;

  /// Menghasilkan 3 pecahan uang kertas rupiah yang proporsional di atas total tagihan
  List<int> _getQuickDenominations(int total) {
    final bills = <int>[];
    const standardBills = [10000, 20000, 50000, 100000, 200000];

    for (final bill in standardBills) {
      if (bill > total) {
        bills.add(bill);
      }
    }

    if (total > 50000 && total < 100000 && !bills.contains(100000)) {
      bills.add(100000);
    }

    // Jika tagihan bernilai besar (> 200rb), buat pembulatan kelipatan 50rb/100rb di atas total
    if (bills.isEmpty) {
      final next50k = ((total / 50000).ceil()) * 50000;
      final next100k = ((total / 100000).ceil()) * 100000;
      bills.add(next50k);
      if (next100k != next50k) bills.add(next100k);
      bills.add(next100k + 50000);
    }

    return bills.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final debtProvider = context.watch<CustomerDebtProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenWidth < 450;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.90,
        ),
        // SingleChildScrollView memungkinkan dialog wrap-content secara presisi tanpa sisa ruang kosong
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================================================================
              // 1. HEADER DIALOG & TOMBOL TUTUP
              // ================================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        color: AppTheme.emeraldGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pembayaran Pesanan',
                            style: TextStyle(
                              fontSize: isSmall ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          if (widget.initialCustomerName != null &&
                              widget.initialCustomerName!.trim().isNotEmpty)
                            Text(
                              widget.initialCustomerName!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Tutup',
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

              // ================================================================
              // 2. KARTU HERO TOTAL TAGIHAN (HERO PAYABLE CARD)
              // ================================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF132A20), const Color(0xFF0F1E19)]
                          : [const Color(0xFFF0FDF4), const Color(0xFFE6F9EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.emeraldGreen.withValues(alpha: 0.35)
                          : const Color(0xFFA7F3D0),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL HARUS DIBAYAR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tagihan aktif meja / pesanan',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF065F46).withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currencyFormat.format(widget.totalAmount),
                        style: TextStyle(
                          fontSize: isSmall ? 21 : 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ================================================================
              // 3. SEGMENTED TAB SELECTOR (TUNAI, QRIS, KASBON)
              // ================================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282B38) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildTabButton(
                        index: 0,
                        icon: Icons.payments_rounded,
                        label: 'Tunai',
                        isDark: isDark,
                      ),
                      _buildTabButton(
                        index: 1,
                        icon: Icons.qr_code_2_rounded,
                        label: 'QRIS Auto',
                        isDark: isDark,
                      ),
                      _buildTabButton(
                        index: 2,
                        icon: Icons.menu_book_rounded,
                        label: 'Kasbon',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ================================================================
              // 4. KONTEN TAB AKTIF (WRAP-CONTENT DINAMIS)
              // ================================================================
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedTabIndex),
                  child: _buildActiveTabContent(
                    isDark: isDark,
                    isSmall: isSmall,
                    qrisPayload: settings.qrisPayload,
                    debtProvider: debtProvider,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol Segmented Tab
  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTabIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppTheme.emeraldGreen : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? (isDark ? Colors.white : AppTheme.emeraldGreen)
                      : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : AppTheme.emeraldGreen)
                        : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Memilih konten tab yang aktif
  Widget _buildActiveTabContent({
    required bool isDark,
    required bool isSmall,
    required String qrisPayload,
    required CustomerDebtProvider debtProvider,
  }) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCashTab(isDark, isSmall);
      case 1:
        return _buildQrisTab(qrisPayload, isDark, isSmall);
      case 2:
        return _buildDebtTab(debtProvider, isDark, isSmall);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // WIDGET TAB TUNAI (CASH)
  // ==========================================================================
  Widget _buildCashTab(bool isDark, bool isSmall) {
    final quickDenominations = _getQuickDenominations(widget.totalAmount);
    final isExactPaid = _cashPaid == widget.totalAmount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label Input Uang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uang Diterima dari Pelanggan:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              if (_cashPaid > 0)
                GestureDetector(
                  onTap: () => _setCash(0),
                  child: Text(
                    'Reset (0)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.primaryAmber : const Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Input Textfield Uang Diterima
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                width: 46,
                child: Text(
                  'Rp',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF6EE7B7) : AppTheme.emeraldGreen,
                  ),
                ),
              ),
              suffixIcon: _cashController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 19),
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      onPressed: () => _setCash(0),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF282B38) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.emeraldGreen,
                  width: 2,
                ),
              ),
            ),
            onChanged: (val) {
              final cleanStr = val.replaceAll(RegExp(r'[^0-9]'), '');
              setState(() {
                _cashPaid = int.tryParse(cleanStr) ?? 0;
              });
            },
          ),

          const SizedBox(height: 12),

          // Tombol Cepat 1: Hero Uang Pas (Paling sering digunakan)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setCash(widget.totalAmount),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isExactPaid
                      ? (isDark
                          ? AppTheme.emeraldGreen.withValues(alpha: 0.25)
                          : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFF282B38) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExactPaid
                        ? AppTheme.emeraldGreen
                        : (isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0)),
                    width: isExactPaid ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flash_on_rounded,
                      size: 18,
                      color: isExactPaid
                          ? AppTheme.emeraldGreen
                          : (isDark ? Colors.amber : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Uang Pas (${_currencyFormat.format(widget.totalAmount)})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isExactPaid
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Tombol Cepat 2: Pecahan Uang Kertas Populer (3 Kolom Seimbang)
          Row(
            children: quickDenominations.map((amt) {
              final isSelected = _cashPaid == amt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _setCash(amt),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? AppTheme.emeraldGreen.withValues(alpha: 0.25)
                                  : const Color(0xFFD1FAE5))
                              : (isDark ? const Color(0xFF282B38) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.emeraldGreen
                                : (isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Text(
                          _currencyFormat.format(amt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Kotak Hasil Kembalian / Uang Kurang
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isCashSufficient
                  ? (isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                      : const Color(0xFFF0FDF4))
                  : (isDark
                      ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                      : const Color(0xFFFEF2F2)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isCashSufficient
                    ? (isDark ? AppTheme.emeraldGreen : const Color(0xFFA7F3D0))
                    : (isDark ? AppTheme.dangerRed : const Color(0xFFFECACA)),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCashSufficient
                          ? Icons.savings_rounded
                          : Icons.error_outline_rounded,
                      color: _isCashSufficient
                          ? (isDark ? const Color(0xFF34D399) : AppTheme.emeraldGreen)
                          : AppTheme.dangerRed,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCashSufficient ? 'Uang Kembalian:' : 'Uang Kurang:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isCashSufficient
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                            : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
                Text(
                  _isCashSufficient
                      ? _currencyFormat.format(_cashChange)
                      : _currencyFormat.format(widget.totalAmount - _cashPaid),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _isCashSufficient
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                        : AppTheme.dangerRed,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Tombol Konfirmasi Pembayaran Tunai
          ElevatedButton(
            onPressed: _isCashSufficient
                ? () {
                    widget.onPaymentCompleted(
                      paymentMethod: 'cash',
                      amountPaid: _cashPaid,
                      change: _cashChange,
                    );
                    Navigator.pop(context);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
              disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
              minimumSize: const Size(double.infinity, 50),
              elevation: _isCashSufficient ? 2 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isCashSufficient ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCashSufficient
                      ? 'Konfirmasi Pembayaran Tunai'
                      : 'Uang Belum Cukup (${_currencyFormat.format(widget.totalAmount - _cashPaid)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET TAB QRIS AUTO-NOMINAL
  // ==========================================================================
  Widget _buildQrisTab(String rawQrisPayload, bool isDark, bool isSmall) {
    final dynamicQris = QrisService.generateDynamicQris(
      rawPayload: rawQrisPayload,
      amount: widget.totalAmount,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge Nominal Otomatis Terinjeksi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0284C7), size: 17),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Nominal otomatis disematkan: ${_currencyFormat.format(widget.totalAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tampilan QR Code Bersih
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: dynamicQris,
                version: QrVersions.auto,
                size: isSmall ? 135 : 155,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Kotak Peringatan Cek Mutasi Bank/E-Wallet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E1C0A) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENGINGAT KASIR: CEK MUTASI DANA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wajib periksa notifikasi mutasi m-banking / e-wallet resto Anda. Pastikan dana ${_currencyFormat.format(widget.totalAmount)} benar-benar masuk sebelum menyelesaikan transaksi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Checkbox Verifikasi Mutasi
          InkWell(
            onTap: () {
              setState(() {
                _isQrisVerified = !_isQrisVerified;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: _isQrisVerified,
                    activeColor: AppTheme.emeraldGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        _isQrisVerified = val ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Saya sudah memeriksa mutasi dan saldo Rp ${_currencyFormat.format(widget.totalAmount)} telah masuk.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Tombol Konfirmasi QRIS
          ElevatedButton(
            onPressed: () {
              if (_isQrisVerified) {
                widget.onPaymentCompleted(
                  paymentMethod: 'qris',
                  amountPaid: widget.totalAmount,
                  change: 0,
                );
                Navigator.pop(context);
              } else {
                _confirmQrisPayment();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isQrisVerified
                  ? AppTheme.emeraldGreen
                  : const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isQrisVerified ? Icons.check_circle_rounded : Icons.shield_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  _isQrisVerified
                      ? 'Selesaikan Pembayaran QRIS'
                      : 'Konfirmasi Penerimaan Dana QRIS',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET TAB KASBON (UTANG TEMPO)
  // ==========================================================================
  Widget _buildDebtTab(CustomerDebtProvider debtProvider, bool isDark, bool isSmall) {
    final customers = debtProvider.customers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Pelanggan Kasbon:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CustomerModel>(
            initialValue: _selectedCustomer,
            hint: const Text('-- Pilih Pelanggan Terdaftar --'),
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF282B38) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            items: customers.map((c) {
              return DropdownMenuItem<CustomerModel>(
                value: c,
                child: Text(
                  '${c.name} (Utang: ${_currencyFormat.format(c.totalDebt)})',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCustomer = val;
              });
            },
          ),
          const SizedBox(height: 14),

          if (_selectedCustomer != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282B38) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.3) : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Kasbon Saat Ini:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      Text(
                        _currencyFormat.format(_selectedCustomer!.totalDebt),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Batas Maksimal Kasbon:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      Text(
                        _currencyFormat.format(_selectedCustomer!.debtLimit),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Setelah Transaksi Ini:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(_selectedCustomer!.totalDebt + widget.totalAmount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: (_selectedCustomer!.totalDebt + widget.totalAmount > _selectedCustomer!.debtLimit)
                              ? AppTheme.dangerRed
                              : AppTheme.emeraldGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (_selectedCustomer!.totalDebt + widget.totalAmount > _selectedCustomer!.debtLimit)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peringatan: Transaksi ini melebihi limit kasbon pelanggan!',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.dangerRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 18),

          // Tombol Simpan Kasbon
          ElevatedButton(
            onPressed: _selectedCustomer != null
                ? () {
                    widget.onPaymentCompleted(
                      paymentMethod: 'debt',
                      amountPaid: 0,
                      change: 0,
                      customerId: _selectedCustomer!.id,
                      customerName: _selectedCustomer!.name,
                    );
                    Navigator.pop(context);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
              disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
              minimumSize: const Size(double.infinity, 50),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_rounded, size: 19),
                SizedBox(width: 8),
                Text(
                  'Simpan Transaksi Kasbon',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DIALOG PERINGATAN WAJIB CEK MUTASI QRIS
  // ==========================================================================
  Future<void> _confirmQrisPayment() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.security_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cek Mutasi QRIS!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282B38) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF383B4A) : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nominal yang wajib masuk rekening:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(widget.totalAmount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sudahkah Anda memeriksa mutasi m-banking atau notifikasi e-wallet resto Anda?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '⚠️ Jangan hanya melihat bukti transfer dari layar HP pelanggan untuk mencegah modus bukti transfer palsu / editan.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            child: const Text('Belum (Cek Dulu)'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Ya, Dana Sudah Masuk'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      widget.onPaymentCompleted(
        paymentMethod: 'qris',
        amountPaid: widget.totalAmount,
        change: 0,
      );
      Navigator.of(context).pop();
    }
  }
}
