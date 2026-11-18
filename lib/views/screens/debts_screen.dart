import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../models/customer_model.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

/// Layar Buku Kasbon Resto.
/// Mengelola data pelanggan yang berutang, pembayaran cicilan/lunas,
/// dan pengiriman pengingat tagihan via WhatsApp.
class DebtsScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const DebtsScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final debtProvider = context.watch<CustomerDebtProvider>();
    final shiftProvider = context.watch<ShiftProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final debtors = debtProvider.debtors;
    final allCustomers = debtProvider.filteredCustomers;

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    Widget bodyContent = Column(
      children: [
        // Banner Ringkasan Total Piutang Resto Modern
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E202B) : const Color(0xFF2C221E),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Total Piutang Resto', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(debtProvider.totalAllDebts),
                    style: const TextStyle(
                      color: AppTheme.primaryAmber,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(height: 36, width: 1, color: Colors.white24),
              Column(
                children: [
                  const Text('Pelanggan Berutang', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${debtors.length} Orang',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Kolom Pencarian
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari pelanggan berdasarkan nama atau No. WA...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: debtProvider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => debtProvider.setSearchQuery(''),
                    )
                  : null,
            ),
            onChanged: (val) => debtProvider.setSearchQuery(val),
          ),
        ),

        // Daftar Pelanggan
        Expanded(
          child: allCustomers.isEmpty
              ? Center(
                  child: Text('Tidak ada pelanggan ditemukan.', style: TextStyle(color: textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: allCustomers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = allCustomers[index];
                    final hasDebt = customer.totalDebt > 0;
                    final debtProgress = (customer.totalDebt / customer.debtLimit).clamp(0.0, 1.0);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasDebt
                              ? (isDark ? const Color(0xFF5A2A2A) : Colors.red.shade200)
                              : borderColor,
                          width: hasDebt ? 1.4 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: hasDebt
                                          ? AppTheme.dangerRed.withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      foregroundColor: hasDebt ? AppTheme.dangerRed : textColor,
                                      child: Text(customer.name.substring(0, 1).toUpperCase()),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          Text(
                                            customer.phoneWA,
                                            style: TextStyle(fontSize: 12, color: textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    hasDebt ? 'Saldo Kasbon:' : 'Lunas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasDebt ? AppTheme.dangerRed : AppTheme.emeraldGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(customer.totalDebt),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: hasDebt ? AppTheme.dangerRed : textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Progress Bar Limit Kasbon
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: debtProgress,
                                    backgroundColor: isDark ? const Color(0xFF2C2F3D) : Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      debtProgress > 0.8 ? AppTheme.dangerRed : AppTheme.warningOrange,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Limit: ${currencyFormat.format(customer.debtLimit)}',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Tombol Aksi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (hasDebt) ...[
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final msg = WhatsappService.generateDebtMessage(
                                      storeName: settings.storeName,
                                      customer: customer,
                                      latestTransactionAmount: 0,
                                    );
                                    WhatsappService.openWhatsApp(
                                      phone: customer.phoneWA,
                                      message: msg,
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.emeraldGreen, size: 15),
                                  label: const Text('Kirim Tagihan WA', style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.emeraldGreen),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _showRepayDialog(context, customer, debtProvider, shiftProvider),
                                  icon: const Icon(Icons.payments_outlined, size: 15),
                                  label: const Text('Bayar Cicilan / Lunas', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emeraldGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );

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
                              'Buku Kasbon Resto',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Piutang pelanggan & tagihan WA',
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
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddCustomerDialog(context, debtProvider),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Tambah Pelanggan', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      appBar: AppBar(
        title: const Text('Buku Kasbon Resto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Tambah Pelanggan Baru',
            onPressed: () => _showAddCustomerDialog(context, debtProvider),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  void _showAddCustomerDialog(BuildContext context, CustomerDebtProvider debtProvider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '100000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap Pelanggan', hintText: 'Contoh: Mas Joko (Bengkel)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp', hintText: '0812xxxxxxxx'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Batas Limit Kasbon (Rp)', prefixText: 'Rp '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final limit = int.tryParse(limitCtrl.text.trim()) ?? 100000;
              if (name.isNotEmpty && phone.isNotEmpty) {
                await debtProvider.addCustomer(name: name, phoneWA: phone, debtLimit: limit);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Simpan Pelanggan'),
          ),
        ],
      ),
    );
  }

  void _showRepayDialog(
    BuildContext context,
    CustomerModel customer,
    CustomerDebtProvider debtProvider,
    ShiftProvider shiftProvider,
  ) {
    final amountCtrl = TextEditingController(text: customer.totalDebt.toString());
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pelunasan Kasbon: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sisa Kasbon Saat Ini: ${currencyFormat.format(customer.totalDebt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Nominal Bayar Tunai (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionChip(
                  label: const Text('Bayar Lunas Penuh'),
                  backgroundColor: Colors.green.shade50,
                  onPressed: () => amountCtrl.text = customer.totalDebt.toString(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () async {
              final paid = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (paid > 0) {
                final auth = context.read<AuthProvider>();
                final posProvider = context.read<PosProvider>();
                final shiftId = shiftProvider.activeShift?.id ?? '';
                final cashierId = auth.currentUser?.id ?? 'cashier_unknown';
                final cashierName = auth.currentUser?.name ?? 'Kasir';

                await debtProvider.repayDebt(customerId: customer.id, amountPaid: paid);
                if (shiftProvider.hasActiveShift) {
                  await shiftProvider.recordDebtRepaidCash(paid);
                }
                await posProvider.recordDebtRepaymentTransaction(
                  customerId: customer.id,
                  customerName: customer.name,
                  amountPaid: paid,
                  paymentMethod: 'cash',
                  shiftId: shiftId,
                  cashierId: cashierId,
                  cashierName: cashierName,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pembayaran kasbon ${customer.name} sebesar ${currencyFormat.format(paid)} berhasil dicatat & masuk riwayat transaksi'),
                      backgroundColor: AppTheme.emeraldGreen,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
            icon: const Icon(Icons.check),
            label: const Text('Terima Pembayaran'),
          ),
        ],
      ),
    );
  }
}
