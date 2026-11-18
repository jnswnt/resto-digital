import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/restaurant_table.dart';
import '../../models/order_model.dart';
import '../../models/online_order_model.dart';
import '../../theme/app_theme.dart';

/// Kartu Denah Meja Visual (Multi-Resolusi & Responsif)
/// Menampilkan status meja: Kosong (🟢), Terisi (🔴), Order Baru (🟡), Panggilan Pelayan (🔔)
class TableFloorCard extends StatelessWidget {
  final RestaurantTable table;
  final OrderModel? activeOrder;
  final OnlineOrderModel? pendingOrder;
  final bool hasWaiterCall;
  final String? waiterCallNote;
  final VoidCallback onTap;

  const TableFloorCard({
    super.key,
    required this.table,
    this.activeOrder,
    this.pendingOrder,
    this.hasWaiterCall = false,
    this.waiterCallNote,
    required this.onTap,
  });

  TableStatus get status {
    if (pendingOrder != null && pendingOrder!.isPending) {
      return TableStatus.pendingWebOrder;
    }
    if (activeOrder != null) {
      return TableStatus.occupied;
    }
    return TableStatus.available;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Palet warna responsif berbasis status
    Color cardBorderColor;
    Color cardBgColor;
    Color statusBadgeColor;
    Color statusBadgeTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case TableStatus.pendingWebOrder:
        cardBorderColor = const Color(0xFFF59E0B); // Amber glow
        cardBgColor = isDark ? const Color(0xFF2E2211) : const Color(0xFFFFFBEB);
        statusBadgeColor = const Color(0xFFF59E0B);
        statusBadgeTextColor = Colors.black;
        statusLabel = 'ORDER BARU';
        statusIcon = Icons.notifications_active_rounded;
        break;
      case TableStatus.occupied:
        final isPaid = activeOrder != null && activeOrder!.paidAmount >= activeOrder!.total && activeOrder!.total > 0;
        cardBorderColor = isPaid
            ? (isDark ? const Color(0xFF065F46) : const Color(0xFF6EE7B7))
            : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD));
        cardBgColor = isPaid
            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5))
            : (isDark ? const Color(0xFF131F37) : const Color(0xFFEFF6FF));
        statusBadgeColor = isPaid
            ? const Color(0xFF10B981)
            : (isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6));
        statusBadgeTextColor = Colors.white;
        statusLabel = isPaid ? 'LUNAS (SANTAP)' : 'TERISI';
        statusIcon = isPaid ? Icons.check_circle_rounded : Icons.restaurant_rounded;
        break;
      case TableStatus.callingWaiter:
        cardBorderColor = const Color(0xFFE11D48);
        cardBgColor = isDark ? const Color(0xFF37121D) : const Color(0xFFFFF1F2);
        statusBadgeColor = const Color(0xFFE11D48);
        statusBadgeTextColor = Colors.white;
        statusLabel = 'PANGGIL';
        statusIcon = Icons.campaign_rounded;
        break;
      case TableStatus.available:
        cardBorderColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFA7F3D0);
        cardBgColor = isDark ? const Color(0xFF0E231F) : const Color(0xFFF0FDF4);
        statusBadgeColor = isDark ? const Color(0xFF059669) : const Color(0xFF10B981);
        statusBadgeTextColor = Colors.white;
        statusLabel = 'KOSONG';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
    }

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    // Hitung durasi makan untuk meja terisi
    int elapsedMinutes = 0;
    if (activeOrder != null) {
      elapsedMinutes = DateTime.now().difference(activeOrder!.createdAt).inMinutes;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasWaiterCall ? const Color(0xFFE11D48) : cardBorderColor,
              width: (status == TableStatus.pendingWebOrder || hasWaiterCall) ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasWaiterCall || status == TableStatus.pendingWebOrder)
                    ? (hasWaiterCall ? Colors.red.withValues(alpha: 0.25) : Colors.amber.withValues(alpha: 0.25))
                    : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: (hasWaiterCall || status == TableStatus.pendingWebOrder) ? 8 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // HEADER KARTU: Nomor Meja & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nomor Meja
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              table.tableNumber,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasWaiterCall) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.notifications_active_rounded,
                              size: 15,
                              color: Color(0xFFE11D48),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Badge Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBadgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusBadgeTextColor),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusBadgeTextColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ISI UTAMA KARTU
                Expanded(
                  child: _buildCardContent(
                    status: status,
                    textColor: textColor,
                    textMuted: textMuted,
                    currencyFormat: currencyFormat,
                    elapsedMinutes: elapsedMinutes,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(height: 6),

                // FOOTER / HINT AKSI
                _buildCardFooter(
                  status: status,
                  textColor: textColor,
                  textMuted: textMuted,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required TableStatus status,
    required Color textColor,
    required Color textMuted,
    required NumberFormat currencyFormat,
    required int elapsedMinutes,
    required bool isDark,
  }) {
    switch (status) {
      case TableStatus.available:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chair_alt_rounded,
                size: 28,
                color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF059669),
              ),
              const SizedBox(height: 4),
              Text(
                'Meja Kosong',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
              ),
              Text(
                'Kapasitas: ${table.capacity} org',
                style: TextStyle(fontSize: 9.5, color: textMuted.withValues(alpha: 0.8)),
              ),
            ],
          ),
        );

      case TableStatus.pendingWebOrder:
        final order = pendingOrder!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              order.customerName,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${order.items.length} item • ${currencyFormat.format(order.totalAmount)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  order.paymentMethod == 'qris' ? Icons.qr_code_2_rounded : Icons.storefront_rounded,
                  size: 11,
                  color: textMuted,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    order.paymentMethod == 'qris' ? 'QRIS Mandiri' : 'Bayar Kasir',
                    style: TextStyle(fontSize: 10, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );

      case TableStatus.occupied:
        final order = activeOrder!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              order.customerName,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                currencyFormat.format(order.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryAmber,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 11, color: textMuted),
                const SizedBox(width: 3),
                Text(
                  '$elapsedMinutes mnt lalu',
                  style: TextStyle(fontSize: 10, color: textMuted),
                ),
                const SizedBox(width: 6),
                Text(
                  '• ${order.totalItems} item',
                  style: TextStyle(fontSize: 10, color: textMuted),
                ),
              ],
            ),
          ],
        );

      case TableStatus.callingWaiter:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_rounded, size: 26, color: Color(0xFFE11D48)),
              const SizedBox(height: 4),
              Text(
                'Panggil Pelayan',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
              ),
              if (waiterCallNote != null && waiterCallNote!.isNotEmpty)
                Text(
                  '"$waiterCallNote"',
                  style: TextStyle(fontSize: 9.5, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
    }
  }

  Widget _buildCardFooter({
    required TableStatus status,
    required Color textColor,
    required Color textMuted,
    required bool isDark,
  }) {
    String actionHint;
    Color actionColor;

    switch (status) {
      case TableStatus.available:
        actionHint = '+ Buka Meja';
        actionColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        break;
      case TableStatus.pendingWebOrder:
        actionHint = '⚡ Ketuk untuk Terima';
        actionColor = const Color(0xFFD97706);
        break;
      case TableStatus.occupied:
        final isPaid = activeOrder != null && activeOrder!.paidAmount >= activeOrder!.total && activeOrder!.total > 0;
        actionHint = isPaid ? 'Selesai / Kosongkan ➜' : 'Detail / Pelunasan ➜';
        actionColor = isPaid
            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
            : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
        break;
      case TableStatus.callingWaiter:
        actionHint = 'Lihat Panggilan ➜';
        actionColor = const Color(0xFFE11D48);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: actionColor.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        actionHint,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: actionColor,
        ),
      ),
    );
  }
}
