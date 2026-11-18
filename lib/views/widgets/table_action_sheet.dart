import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/restaurant_table.dart';
import '../../models/order_model.dart';
import '../../models/online_order_model.dart';
import '../../theme/app_theme.dart';

/// Modal Bottom Sheet / Dialog Aksi Meja (Multi-Resolusi & Ergonomis)
/// Menyajikan interaksi satu sentuhan untuk meja kosong, meja terisi, atau pesanan web masuk.
class TableActionSheet extends StatelessWidget {
  final RestaurantTable table;
  final OrderModel? activeOrder;
  final OnlineOrderModel? pendingOrder;
  final bool hasWaiterCall;
  final String? waiterCallNote;
  final String? waiterCallId;

  // Callbacks Aksi Kasir
  final Function(String tableNo, String customerName) onOpenNewTransaction;
  final Function(OrderModel order) onOpenActiveOrderForEdit;
  final Function(OnlineOrderModel order) onAcceptOnlineOrder;
  final Function(String orderId) onRejectOnlineOrder;
  final Function(String orderId) onVerifyQrisPayment;
  final Function(String callId) onResolveWaiterCall;
  final Function(OrderModel order) onPrintKitchenTicket;
  final Function(OrderModel order)? onClosePaidTable;
  final Function(OrderModel order, int payableAmount)? onDirectPayTable;
  final Function(String currentTable, String newTable)? onMoveTable;
  final List<String> availableTablesForMove;

  const TableActionSheet({
    super.key,
    required this.table,
    this.activeOrder,
    this.pendingOrder,
    this.hasWaiterCall = false,
    this.waiterCallNote,
    this.waiterCallId,
    required this.onOpenNewTransaction,
    required this.onOpenActiveOrderForEdit,
    required this.onAcceptOnlineOrder,
    required this.onRejectOnlineOrder,
    required this.onVerifyQrisPayment,
    required this.onResolveWaiterCall,
    required this.onPrintKitchenTicket,
    this.onClosePaidTable,
    this.onDirectPayTable,
    this.onMoveTable,
    this.availableTablesForMove = const [],
  });

  /// Helper untuk menampilkan TableActionSheet secara adaptif sesuai resolusi layar
  static void show({
    required BuildContext context,
    required RestaurantTable table,
    OrderModel? activeOrder,
    OnlineOrderModel? pendingOrder,
    bool hasWaiterCall = false,
    String? waiterCallNote,
    String? waiterCallId,
    required Function(String tableNo, String customerName) onOpenNewTransaction,
    required Function(OrderModel order) onOpenActiveOrderForEdit,
    required Function(OnlineOrderModel order) onAcceptOnlineOrder,
    required Function(String orderId) onRejectOnlineOrder,
    required Function(String orderId) onVerifyQrisPayment,
    required Function(String callId) onResolveWaiterCall,
    required Function(OrderModel order) onPrintKitchenTicket,
    Function(OrderModel order)? onClosePaidTable,
    Function(OrderModel order, int payableAmount)? onDirectPayTable,
    Function(String currentTable, String newTable)? onMoveTable,
    List<String> availableTablesForMove = const [],
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth >= 600;

    final sheetWidget = TableActionSheet(
      table: table,
      activeOrder: activeOrder,
      pendingOrder: pendingOrder,
      hasWaiterCall: hasWaiterCall,
      waiterCallNote: waiterCallNote,
      waiterCallId: waiterCallId,
      onOpenNewTransaction: onOpenNewTransaction,
      onOpenActiveOrderForEdit: onOpenActiveOrderForEdit,
      onAcceptOnlineOrder: onAcceptOnlineOrder,
      onRejectOnlineOrder: onRejectOnlineOrder,
      onVerifyQrisPayment: onVerifyQrisPayment,
      onResolveWaiterCall: onResolveWaiterCall,
      onPrintKitchenTicket: onPrintKitchenTicket,
      onClosePaidTable: onClosePaidTable,
      onDirectPayTable: onDirectPayTable,
      onMoveTable: onMoveTable,
      availableTablesForMove: availableTablesForMove,
    );

    if (isDesktopOrTablet) {
      // Tampilkan sebagai Dialog terpusat dengan batas lebar maksimal pada Tablet / Desktop
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
            child: sheetWidget,
          ),
        ),
      );
    } else {
      // Tampilkan sebagai Modal Bottom Sheet yang ramah jempol pada HP Portrait
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: sheetWidget,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator untuk HP
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // HEADER LEMBAR AKSI MEJA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      table.tableNumber,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Zona: ${table.section} (${table.capacity} Kursi)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // NOTIFIKASI PANGGILAN PELAYAN (JIKA ADA)
          if (hasWaiterCall && waiterCallId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFE11D48), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tamu Memanggil Bantuan Pelayan!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF9F1239)),
                        ),
                        if (waiterCallNote != null && waiterCallNote!.isNotEmpty)
                          Text(
                            '"$waiterCallNote"',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      onResolveWaiterCall(waiterCallId!);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Selesai', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          // KONTEN SESUAI KONDISI MEJA:
          if (pendingOrder != null && pendingOrder!.isPending) ...[
            _buildPendingWebOrderSection(context, pendingOrder!, isDark, currencyFormat),
          ] else if (activeOrder != null) ...[
            _buildOccupiedTableSection(context, activeOrder!, isDark, currencyFormat),
          ] else ...[
            _buildAvailableTableSection(context, isDark),
          ],
        ],
      ),
    );
  }

  /// TAMPILAN MEJA KOSONG: Formulir Buka Transaksi Baru
  Widget _buildAvailableTableSection(BuildContext context, bool isDark) {
    final nameController = TextEditingController(text: 'Pelanggan');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F2621) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF10B981)),
              const SizedBox(height: 6),
              const Text(
                'Meja Ini Sedang Kosong',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'Tamu dapat langsung dipersilakan duduk atau scan QR di meja.',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nama Pelanggan / Catatan Meja',
            hintText: 'Contoh: Bpk. Budi, Meja Sofa',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              Navigator.pop(context);
              onOpenNewTransaction(table.tableNumber, name.isEmpty ? 'Pelanggan' : name);
            },
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text('Buka Transaksi di ${table.tableNumber}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }

  /// TAMPILAN ORDER WEB MASUK (PENDING): Terima/Tolak & Verifikasi
  Widget _buildPendingWebOrderSection(
    BuildContext context,
    OnlineOrderModel order,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner Status Pesanan Masuk
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF382307) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan Self-Order Baru: #${order.orderId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                    ),
                    Text(
                      'Pemesan: ${order.customerName} • ${DateFormat('HH:mm').format(order.createdAt)} WIB',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Metode Pembayaran & Verifikasi QRIS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: order.isQrisWaitingVerification
                ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: order.isQrisWaitingVerification ? const Color(0xFFF59E0B) : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    order.paymentMethod == 'qris' ? Icons.qr_code_2_rounded : Icons.storefront_rounded,
                    size: 16,
                    color: order.isQrisWaitingVerification ? const Color(0xFFD97706) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.isQrisWaitingVerification
                        ? 'QRIS Mandiri (Menunggu Cek Mutasi)'
                        : order.isQrisPaid
                            ? 'QRIS Mandiri (Lunas)'
                            : 'Metode: Bayar di Meja Kasir',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: order.isQrisWaitingVerification ? const Color(0xFFD97706) : null,
                    ),
                  ),
                ],
              ),
              if (order.isQrisWaitingVerification)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onVerifyQrisPayment(order.orderId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Verifikasi Dana', style: TextStyle(fontSize: 10.5)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Daftar Item Menu yang Dipesan Tamu
        const Text(
          'Daftar Menu yang Dipesan:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.qty}x',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryAmber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (item.notes.isNotEmpty)
                            Text(
                              '📝 Catatan: ${item.notes}',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFFB45309)),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormat.format(item.price * item.qty),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 10),

        // Total Tagihan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Pesanan:', style: TextStyle(fontSize: 12.5)),
            Text(
              currencyFormat.format(order.totalAmount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryAmber),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tombol Aksi Kasir: Tolak vs Terima
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRejectOnlineOrder(order.orderId);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAcceptOnlineOrder(order);
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Terima & Cetak Dapur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// TAMPILAN MEJA TERISI (OCCUPIED): Detail Tagihan, Cetak KOT, Pelunasan, Pindah Meja
  Widget _buildOccupiedTableSection(
    BuildContext context,
    OrderModel order,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    final elapsedMinutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isFullyPaid = order.paidAmount >= order.total && order.total > 0;
    final remaining = (order.total - order.paidAmount).clamp(0, 999999999);

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ringkasan Tamu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Durasi Santap: ⏱️ $elapsedMinutes menit • ${order.totalItems} item',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.soup_kitchen_rounded, color: AppTheme.primaryAmber),
              tooltip: 'Cetak Tiket Dapur (KOT)',
              onPressed: () => onPrintKitchenTicket(order),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Rincian Pesanan
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2232) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.qty}x',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryAmber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (item.notes.isNotEmpty)
                            Text(
                              '📝 ${item.notes}',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFFB45309)),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormat.format(item.total),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),


        // Total Tagihan & Info Uang Muka QRIS (jika ada)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFullyPaid
                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                : (isDark ? const Color(0xFF242735) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFullyPaid
                  ? AppTheme.emeraldGreen.withValues(alpha: 0.5)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Seluruh Menu:', style: TextStyle(fontSize: 12, color: textMuted)),
                  Text(
                    currencyFormat.format(order.total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (order.paidAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.emeraldGreen),
                        const SizedBox(width: 4),
                        Text(
                          isFullyPaid ? 'Status: Lunas via QRIS' : 'Uang Muka QRIS:',
                          style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      '- ${currencyFormat.format(order.paidAmount)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFullyPaid ? 'Sisa Tagihan:' : 'Sisa Harus Dibayar:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isFullyPaid ? AppTheme.emeraldGreen : textColor,
                    ),
                  ),
                  Text(
                    isFullyPaid ? 'Rp 0 (LUNAS)' : currencyFormat.format(remaining),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isFullyPaid ? AppTheme.emeraldGreen : AppTheme.primaryAmber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Tombol Aksi Utama
        Row(
          children: [
            // Tombol Cetak Tiket KOT Dapur
            OutlinedButton.icon(
              onPressed: () => onPrintKitchenTicket(order),
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('KOT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryAmber,
                side: const BorderSide(color: AppTheme.primaryAmber),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),

            // Tombol Selesai & Kosongkan Meja (Jika Sudah Lunas) atau Bayar di Kasir (Jika Belum)
            Expanded(
              child: isFullyPaid && onClosePaidTable != null
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onClosePaidTable!(order);
                      },
                      icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: const Text('Selesai & Kosongkan Meja'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (onDirectPayTable != null) {
                          onDirectPayTable!(order, remaining);
                        } else {
                          onOpenActiveOrderForEdit(order);
                        }
                      },
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                      label: Text(
                        order.paidAmount > 0
                            ? 'Bayar Sisa (${currencyFormat.format(remaining)})'
                            : 'Bayar (${currencyFormat.format(remaining)})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),

        // Tombol Sekunder: Opsi Tambah/Ubah Pesanan di Kasir
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onOpenActiveOrderForEdit(order);
            },
            icon: Icon(
              isFullyPaid ? Icons.add_shopping_cart_rounded : Icons.edit_note_rounded,
              size: 16,
            ),
            label: Text(
              isFullyPaid ? '+ Tambah Pesanan / Buka di Kasir' : 'Ubah / Tambah Menu di Kasir',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),

        // Opsi Pindah Meja (jika ada meja kosong)
        if (onMoveTable != null && availableTablesForMove.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _showMoveTableDialog(context, order),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Pindahkan ke Meja Lain', style: TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ],
    );
  }

  void _showMoveTableDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pindahkan ${table.tableNumber} ke Meja Lain'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih meja tujuan yang sedang kosong:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              ...availableTablesForMove.map((targetTable) {
                return ListTile(
                  title: Text(targetTable, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    onMoveTable?.call(table.tableNumber, targetTable);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ],
      ),
    );
  }
}
