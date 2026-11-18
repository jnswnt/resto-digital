import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/kitchen_ticket_service.dart';
import '../../services/printer_receipt_service.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';

/// Layar Utama Kitchen Display System (KDS) & Kitchen Order Ticket (KOT).
/// Dirancang untuk staf dapur/koki memantau, memasak, dan menyelesaikan pesanan masuk secara real-time.
class KitchenDisplayScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const KitchenDisplayScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  Timer? _timer;
  String _selectedFilter = 'all'; // 'all', 'pending', 'cooking', 'ready'
  bool _sortOldestFirst = true; // True: pesanan terlama tampil di awal (prioritas)
  int _lastOrderCount = 0;

  @override
  void initState() {
    super.initState();
    // Perbarui timer durasi masak setiap 15 detik secara live
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Menghitung warna dan label durasi waktu tunggu pesanan
  Color _getDurationColor(int minutes) {
    if (minutes < 10) return AppTheme.emeraldGreen; // 0-9 mnt: Aman
    if (minutes < 20) return Colors.amber.shade800; // 10-19 mnt: Sedang
    return AppTheme.dangerRed; // >= 20 mnt: Kritis / Terlambat
  }

  /// Memutar nada bel saat ada pesanan baru masuk ke dapur
  void _checkAndPlayAlert(int currentCount, bool soundEnabled) {
    if (currentCount > _lastOrderCount && _lastOrderCount != 0 && soundEnabled) {
      SoundService().playOrderAlert();
    }
    _lastOrderCount = currentCount;
  }

  /// Mencetak tiket fisik KOT ke printer dapur
  void _printKitchenTicket(BuildContext context, OrderModel order, dynamic settings) {
    final ticketText = KitchenTicketService.buildKitchenTicketText(
      tableNo: order.tableNo ?? 'BUNGKUS / TAKEAWAY',
      customerName: order.customerName,
      items: order.items,
      orderId: order.id.replaceAll('ord_', ''),
      orderTime: order.createdAt,
    );
    debugPrint('[KDS] Mencetak Tiket KOT:\n$ticketText');

    PrinterReceiptService.printReceiptDirect(
      settings: settings,
      order: order,
      receiptNo: 'KOT-${order.id.replaceAll('ord_', '')}',
      orderTime: order.createdAt,
      cashierName: 'Koki Dapur',
      paymentMethod: order.paidAmount >= order.total ? 'Lunas' : 'Belum Bayar (Open Tab)',
      amountPaid: order.paidAmount,
      change: 0,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mencetak tiket dapur ${order.tableNo ?? 'Takeaway'}... 🖨️'),
        backgroundColor: AppTheme.emeraldGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final pos = context.watch<PosProvider>();
    final auth = context.watch<AuthProvider>();
    final online = context.watch<OnlineOrderProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    final rawOrders = pos.kitchenOrders;
    _checkAndPlayAlert(rawOrders.length, online.isSoundEnabled);

    // Filter daftar pesanan
    final filteredOrders = rawOrders.where((order) {
      if (_selectedFilter == 'pending') return order.isKitchenPending;
      if (_selectedFilter == 'cooking') return order.isKitchenCooking;
      if (_selectedFilter == 'ready') return order.isKitchenReady;
      return true; // 'all'
    }).toList();

    // Pengurutan pesanan
    if (_sortOldestFirst) {
      filteredOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Hitung ringkasan status antrean
    final pendingCount = rawOrders.where((o) => o.isKitchenPending).length;
    final cookingCount = rawOrders.where((o) => o.isKitchenCooking).length;
    final readyCount = rawOrders.where((o) => o.isKitchenReady).length;

    return Scaffold(
      backgroundColor: bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // ==============================================================
            // 1. TOP HEADER BAR KHUSUS DAPUR (KDS)
            // ==============================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSidebar : Colors.white,
                border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
              ),
              child: Row(
                children: [
                  if (widget.onOpenMenuDrawer != null) ...[
                    IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onOpenMenuDrawer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Dapur Resto (KDS)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LIVE REALTIME',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emeraldGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Sistem tiket pesanan & antrean memasak koki',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Suara Bel Dapur
                  IconButton(
                    icon: Icon(
                      online.isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: online.isSoundEnabled ? AppTheme.emeraldGreen : textMuted,
                      size: 22,
                    ),
                    tooltip: online.isSoundEnabled ? 'Suara Bel Aktif' : 'Suara Bel Nonaktif',
                    onPressed: () => online.setSoundEnabled(!online.isSoundEnabled),
                  ),
                  const SizedBox(width: 6),

                  // Info Staf Bertugas
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Text(
                          auth.currentUser?.name ?? 'Koki Dapur',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Logout / Kunci Layar
                  IconButton(
                    icon: const Icon(Icons.lock_clock_rounded, size: 20),
                    tooltip: 'Kunci Layar (Ganti Shift)',
                    onPressed: () => auth.lockScreen(),
                  ),
                ],
              ),
            ),

            // ==============================================================
            // 2. FILTER STATUS TABS & KONTROL SORTING
            // ==============================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E202B) : Colors.white,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Semua Pesanan', rawOrders.length, Icons.all_inbox_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('pending', 'Menunggu', pendingCount, Icons.hourglass_top_rounded, color: AppTheme.dangerRed),
                    const SizedBox(width: 8),
                    _buildFilterChip('cooking', 'Sedang Dimasak', cookingCount, Icons.local_fire_department_rounded, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    _buildFilterChip('ready', 'Siap Saji', readyCount, Icons.restaurant_rounded, color: AppTheme.emeraldGreen),
                    const SizedBox(width: 16),

                    // Toggle Pengurutan Waktu
                    ActionChip(
                      avatar: Icon(
                        _sortOldestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _sortOldestFirst ? 'Prioritas Terlama' : 'Pesanan Terbaru',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => _sortOldestFirst = !_sortOldestFirst),
                    ),
                  ],
                ),
              ),
            ),

            // ==============================================================
            // 3. DAFTAR KARTU TIKET KOT PESANAN DAPUR
            // ==============================================================
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64,
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == 'all'
                                ? 'Semua Pesanan Selesai Dimasak! 🍳'
                                : 'Tidak ada tiket dengan status terpilih.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pesanan baru dari kasir atau scan QR meja akan otomatis muncul di sini.',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 440,
                      ),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _buildKotCard(context, order, pos, isDark, textColor, textMuted, borderColor, settings);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun Chip Tombol Filter Status
  Widget _buildFilterChip(String filterKey, String label, int count, IconData icon, {Color? color}) {
    final isSelected = _selectedFilter == filterKey;
    final themeColor = color ?? AppTheme.primaryAmber;

    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : themeColor),
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.black : null,
      ),
      selectedColor: themeColor,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  /// Membangun Kartu Tiket KOT Dapur Individual
  Widget _buildKotCard(
    BuildContext context,
    OrderModel order,
    PosProvider pos,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
    dynamic settings,
  ) {
    final elapsedMinutes = order.elapsedOrderTime.inMinutes;
    final timerColor = _getDurationColor(elapsedMinutes);
    final timeStr = DateFormat('HH:mm').format(order.createdAt);
    final isFullyPaid = order.paidAmount >= order.total && order.total > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: order.isKitchenCooking
              ? Colors.orange.shade700
              : (order.isKitchenReady ? AppTheme.emeraldGreen : borderColor),
          width: order.isKitchenCooking || order.isKitchenReady ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (order.isKitchenCooking
                    ? Colors.orange
                    : (order.isKitchenReady ? AppTheme.emeraldGreen : Colors.black))
                .withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -------------------------------------------------------------
          // A. HEADER TIKET KOT: Nomor Meja, Status Bayar & Live Timer
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Meja / Takeaway (Kiri) & Live Elapsed Timer (Kanan)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        order.tableNo?.toUpperCase() ?? 'TAKEAWAY / BUNGKUS',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live Elapsed Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: timerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: timerColor.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_rounded, size: 13, color: timerColor),
                          const SizedBox(width: 4),
                          Text(
                            '${elapsedMinutes}m',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: timerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Baris 2: Info Tamu & Jam (Kiri) & Badge Status Bayar (Kanan)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Tamu: ${order.customerName} • Jam $timeStr • #${order.id.replaceAll('ord_', '')}',
                        style: TextStyle(fontSize: 11, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge Metode Bayar (Makan Dulu vs Lunas)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFullyPaid
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isFullyPaid
                              ? AppTheme.emeraldGreen.withValues(alpha: 0.4)
                              : Colors.amber.shade700.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isFullyPaid ? 'LUNAS' : 'OPEN TAB',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isFullyPaid ? AppTheme.emeraldGreen : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------
          // B. DAFTAR ITEM MENU & CATATAN RASA KHUSUS KOKI
          // -------------------------------------------------------------
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: order.items.length,
              separatorBuilder: (context, index) => const Divider(height: 10),
              itemBuilder: (context, itemIdx) {
                final item = order.items[itemIdx];
                final itemKey = '${order.id}_${item.productId}_$itemIdx';
                final isDone = order.completedItemIds.contains(itemKey);

                return InkWell(
                  onTap: () => pos.toggleKitchenItemCompleted(order.id, itemKey),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox Checklist Item Koki
                        Icon(
                          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          size: 20,
                          color: isDone ? AppTheme.emeraldGreen : textMuted,
                        ),
                        const SizedBox(width: 8),
                        // Qty Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.grey.withValues(alpha: 0.15)
                                : AppTheme.primaryAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.qty}x',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: isDone ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nama Menu & Catatan
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? textMuted : textColor,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.dangerRed),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          item.notes.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.dangerRed,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // -------------------------------------------------------------
          // C. FOOTER TIKET: Status Memasak, Aksi Cepat, & Cetak KOT
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Tombol Cetak Fisik KOT
                    IconButton(
                      icon: const Icon(Icons.print_rounded, size: 18),
                      tooltip: 'Cetak Tiket Fisik KOT',
                      onPressed: () => _printKitchenTicket(context, order, settings),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),

                    // Tombol Aksi Status Utama
                    Expanded(
                      child: order.isKitchenPending
                          ? ElevatedButton.icon(
                              onPressed: () => pos.updateKitchenStatus(order.id, 'cooking'),
                              icon: const Icon(Icons.local_fire_department_rounded, size: 18),
                              label: const Text('Mulai Masak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          : (order.isKitchenCooking
                              ? ElevatedButton.icon(
                                  onPressed: () => pos.updateKitchenStatus(order.id, 'ready'),
                                  icon: const Icon(Icons.restaurant_rounded, size: 18),
                                  label: const Text('Siap Saji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emeraldGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => pos.updateKitchenStatus(order.id, 'served'),
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text('Selesai / Diantar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF475569),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
