import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Dialog Interaktif Input Diskon Transaksi & Voucher Promo Kasir
/// Memfasilitasi kasir dalam memberikan diskon member (persentase %)
/// atau potongan harga nominal langsung (Rp).
class DiscountDialog extends StatefulWidget {
  final int subtotal;
  final int currentDiscountAmount;
  final double currentDiscountPercent;
  final Function({required int discountAmount, required double discountPercent}) onApplyDiscount;
  final VoidCallback onClearDiscount;

  const DiscountDialog({
    super.key,
    required this.subtotal,
    required this.currentDiscountAmount,
    required this.currentDiscountPercent,
    required this.onApplyDiscount,
    required this.onClearDiscount,
  });

  /// Helper statis untuk memanggil dialog diskon dengan mudah
  static Future<void> show({
    required BuildContext context,
    required int subtotal,
    required int currentDiscountAmount,
    required double currentDiscountPercent,
    required Function({required int discountAmount, required double discountPercent}) onApplyDiscount,
    required VoidCallback onClearDiscount,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DiscountDialog(
        subtotal: subtotal,
        currentDiscountAmount: currentDiscountAmount,
        currentDiscountPercent: currentDiscountPercent,
        onApplyDiscount: onApplyDiscount,
        onClearDiscount: onClearDiscount,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late TabController _tabController;
  final TextEditingController _percentController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();

  // Mode: 0 = Persentase (%), 1 = Nominal (Rp)
  int _activeMode = 0;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.currentDiscountPercent > 0 ? 0 : (widget.currentDiscountAmount > 0 ? 1 : 0);
    _tabController = TabController(length: 2, vsync: this, initialIndex: _activeMode);

    if (widget.currentDiscountPercent > 0) {
      _percentController.text = widget.currentDiscountPercent.toStringAsFixed(
        widget.currentDiscountPercent.truncateToDouble() == widget.currentDiscountPercent ? 0 : 1,
      );
    }
    if (widget.currentDiscountAmount > 0) {
      _nominalController.text = widget.currentDiscountAmount.toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _percentController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  int get _calculatedDiscount {
    if (_activeMode == 0) {
      final pct = double.tryParse(_percentController.text.trim()) ?? 0.0;
      return ((widget.subtotal * pct.clamp(0.0, 100.0)) / 100).round();
    } else {
      final nominal = int.tryParse(_nominalController.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return nominal.clamp(0, widget.subtotal);
    }
  }

  double get _calculatedPercent {
    if (_activeMode == 0) {
      return (double.tryParse(_percentController.text.trim()) ?? 0.0).clamp(0.0, 100.0);
    } else {
      if (widget.subtotal <= 0) return 0.0;
      return (_calculatedDiscount / widget.subtotal) * 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;

    final discountVal = _calculatedDiscount;
    final totalAfterDiscount = (widget.subtotal - discountVal).clamp(0, widget.subtotal);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // JUDUL DIALOG
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_offer_rounded, color: AppTheme.primaryAmber, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diskon & Voucher Promo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        Text('Potongan harga transaksi kasir', style: TextStyle(fontSize: 11.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // TAB PEMILIHAN METODE DISKON (PERSENTASE / NOMINAL)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {
                      _activeMode = index;
                    });
                  },
                  indicator: BoxDecoration(
                    color: AppTheme.emeraldGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Persen (%)'),
                    Tab(text: 'Nominal (Rp)'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ISI TAB: PERSENTASE ATAU NOMINAL
              if (_activeMode == 0) ...[
                // INPUT PERSEN (%)
                TextField(
                  controller: _percentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // PILIHAN CEPAT PERSEN
                Row(
                  children: [5, 10, 15, 20, 50].map((pct) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _percentController.text = pct.toString();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                // INPUT NOMINAL (Rp)
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // PILIHAN CEPAT NOMINAL
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [5000, 10000, 20000, 50000].map((nominal) {
                    return ActionChip(
                      label: Text(_currencyFormat.format(nominal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        setState(() {
                          _nominalController.text = nominal.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // KOTAK RINGKASAN SETELAH DISKON
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal Menu:', style: TextStyle(fontSize: 11.5, color: textMuted)),
                        Text(_currencyFormat.format(widget.subtotal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Potongan Diskon:', style: TextStyle(fontSize: 11.5, color: Colors.redAccent)),
                        Text(
                          '- ${_currencyFormat.format(discountVal)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal Bersih:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                          _currencyFormat.format(totalAfterDiscount),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // TOMBOL AKSI TERAPKAN & HAPUS DISKON
              Row(
                children: [
                  if (widget.currentDiscountAmount > 0 || widget.currentDiscountPercent > 0) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        widget.onClearDiscount();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus Diskon', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onApplyDiscount(
                          discountAmount: discountVal,
                          discountPercent: _calculatedPercent,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Terapkan Diskon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
