import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/pos_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../theme/app_theme.dart';
import 'payment_dialog.dart';

/// Dialog Pisah Tagihan Meja (Split Bill by Item)
/// Memungkinkan kasir memisahkan sebagian pesanan makanan/minuman dari suatu meja
/// untuk langsung dibayar oleh tamu bersangkutan atau dipindahkan ke tagihan/meja baru.
class SplitBillDialog extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onSplitCompleted;

  const SplitBillDialog({
    super.key,
    required this.order,
    this.onSplitCompleted,
  });

  /// Helper untuk menampilkan dialog split bill
  static Future<void> show({
    required BuildContext context,
    required OrderModel order,
    VoidCallback? onSplitCompleted,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SplitBillDialog(
        order: order,
        onSplitCompleted: onSplitCompleted,
      ),
    );
  }

  @override
  State<SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<SplitBillDialog> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Menyimpan kuantitas yang dipilih untuk dipisah per indeks item order
  late List<int> _selectedQtys;

  @override
  void initState() {
    super.initState();
    // Default kuantitas terpilih = 0
    _selectedQtys = List<int>.filled(widget.order.items.length, 0);
  }

  int get _totalSelectedItemsCount => _selectedQtys.fold(0, (sum, q) => sum + q);

  int get _selectedSubtotal {
    int total = 0;
    for (int i = 0; i < widget.order.items.length; i++) {
      total += widget.order.items[i].price * _selectedQtys[i];
    }
    return total;
  }

  bool get _hasSelectedItems => _totalSelectedItemsCount > 0;

  List<OrderItem> _buildSplitItems() {
    final list = <OrderItem>[];
    for (int i = 0; i < widget.order.items.length; i++) {
      if (_selectedQtys[i] > 0) {
        final src = widget.order.items[i];
        list.add(src.copyWith(qty: _selectedQtys[i]));
      }
    }
    return list;
  }

  /// Membuka dialog konfirmasi untuk memindahkan item terpilih ke tab meja baru
  Future<void> _handleSplitToNewTab(BuildContext context) async {
    final shift = context.read<ShiftProvider>();
    final pos = context.read<PosProvider>();

    if (!shift.hasActiveShift) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buka shift kasir terlebih dahulu.')),
      );
      return;
    }

    final newTableCtrl = TextEditingController(
      text: '${widget.order.tableNo ?? "Meja"} - Bill B',
    );
    final guestNameCtrl = TextEditingController(
      text: '${widget.order.customerName} (Tamu B)',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.call_split_rounded, color: AppTheme.primaryAmber, size: 22),
              SizedBox(width: 10),
              Text('Pisah Jadi Tab / Meja Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan label nomor meja / nama bill baru:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: newTableCtrl,
                decoration: InputDecoration(
                  labelText: 'Nomor Meja / Label Bill',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: guestNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Tamu Pemisah',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pisahkan Tab'),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) {
      await pos.splitOrderToNewTab(
        sourceOrderId: widget.order.id,
        itemsToSplit: _buildSplitItems(),
        newTableNo: newTableCtrl.text.trim(),
        newCustomerName: guestNameCtrl.text.trim(),
        shiftId: shift.activeShift!.id,
      );

      if (mounted) {
        Navigator.pop(this.context); // Tutup SplitBillDialog
        widget.onSplitCompleted?.call();
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Item berhasil dipisahkan ke "${newTableCtrl.text.trim()}".'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    }
  }

  /// Langsung memproses pembayaran untuk item-item yang dipilih
  void _handlePaySelectedNow(BuildContext context) {
    final splitItems = _buildSplitItems();
    final subtotal = _selectedSubtotal;
    final settings = context.read<SettingsProvider>().settings;
    final pos = context.read<PosProvider>();
    final shift = context.read<ShiftProvider>();
    final auth = context.read<AuthProvider>();
    final debtProvider = context.read<CustomerDebtProvider>();

    if (!shift.hasActiveShift) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buka shift kasir terlebih dahulu.')),
      );
      return;
    }

    // Hitung pajak & service charge jika diaktifkan di toko
    final svc = pos.calculateServiceCharge(settings, subtotal);
    final tax = pos.calculateTax(settings, subtotal, svc);
    final grandTotal = (subtotal + svc + tax).clamp(0, 999999999);

    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        totalAmount: grandTotal,
        initialCustomerName: '${widget.order.customerName} (Split)',
        onPaymentCompleted: ({
          required String paymentMethod,
          required int amountPaid,
          required int change,
          String? customerId,
          String? customerName,
        }) async {
          final trx = await pos.splitOrderAndCheckoutDirectly(
            sourceOrderId: widget.order.id,
            itemsToPay: splitItems,
            shiftId: shift.activeShift!.id,
            cashierId: auth.currentUser?.id ?? 'cashier_unknown',
            cashierName: auth.currentUser?.name ?? 'Kasir',
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
            change: change,
            serviceChargeAmount: svc,
            taxAmount: tax,
            customerId: customerId,
            customerName: customerName,
          );

          // Catat penjualan di shift
          if (paymentMethod == 'cash') {
            await shift.recordCashSale(trx.totalAmount);
          } else if (paymentMethod == 'qris') {
            await shift.recordQrisSale(trx.totalAmount);
          } else if (paymentMethod == 'debt' && customerId != null) {
            await shift.recordDebtSale(trx.totalAmount);
            await debtProvider.recordNewDebt(
              customerId: customerId,
              amount: trx.totalAmount,
              orderId: trx.orderId,
            );
          }

          if (mounted) {
            Navigator.pop(this.context); // Tutup SplitBillDialog
            widget.onSplitCompleted?.call();
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(
                content: Text('Tagihan pecahan berhasil dibayar & lunas!'),
                backgroundColor: AppTheme.emeraldGreen,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final cardBg = isDark ? AppTheme.darkCardSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER DIALOG
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.call_split_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pisah Tagihan (Split Bill)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        Text(
                          '${widget.order.tableNo ?? "Pesanan"} • Tamu: ${widget.order.customerName}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                'Pilih kuantitas item yang ingin dipisahkan dari meja ini:',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 10),

              // DAFTAR ITEM PESANAN DENGAN STEPPER
              Expanded(
                child: ListView.separated(
                  itemCount: widget.order.items.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: borderColor),
                  itemBuilder: (context, index) {
                    final item = widget.order.items[index];
                    final selectedQty = _selectedQtys[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_currencyFormat.format(item.price)} (Total meja: ${item.qty} pcs)',
                                  style: TextStyle(fontSize: 11.5, color: textMuted),
                                ),
                                if (item.notes.isNotEmpty)
                                  Text(
                                    '* ${item.notes}',
                                    style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.primaryAmber),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // STEPPER KUANTITAS
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: selectedQty > 0
                                      ? () {
                                          setState(() => _selectedQtys[index]--);
                                        }
                                      : null,
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 26),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$selectedQty',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: selectedQty > 0 ? AppTheme.emeraldGreen : textColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: selectedQty < item.qty
                                      ? () {
                                          setState(() => _selectedQtys[index]++);
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // RINGKASAN TAGIHAN PECAHAN YANG TERPILIH
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Item Dipilih:', style: TextStyle(fontSize: 11.5, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '$_totalSelectedItemsCount Menu Pcs',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal Tagihan Pisah:', style: TextStyle(fontSize: 11.5, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(_selectedSubtotal),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // DUA TOMBOL AKSI: BAYAR SEKARANG ATAU PISAH JADI TAB BARU
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasSelectedItems ? () => _handleSplitToNewTab(context) : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.table_restaurant_outlined, size: 17),
                      label: const Text('Pisah Jadi Tab Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _hasSelectedItems ? () => _handlePaySelectedNow(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 17),
                      label: const Text('Bayar Tagihan Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
