import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/pos_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../models/order_model.dart';
import '../../models/online_order_model.dart';
import '../../models/restaurant_table.dart';
import '../../theme/app_theme.dart';
import '../../services/kitchen_ticket_service.dart';
import '../../services/printer_receipt_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/notification_service.dart';
import '../widgets/table_floor_card.dart';
import '../widgets/table_action_sheet.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/whatsapp_receipt_dialog.dart';
import 'shift_screen.dart';

/// Layar Terpadu Denah Meja Visual (Visual Table Floor Plan):
/// - Konsep 1: Denah Meja Visual (Multi-Resolusi: HP Android Portrait, Tablet, & Desktop)
/// - Menyatukan Meja Kosong (🟢), Meja Terisi (🔴), Order Web Masuk (🟡), dan Panggilan Pelayan (🔔)
/// - Dilengkapi Filter Chips Status, Action Sheet Satu Sentuhan, dan Pemisahan Pesanan Takeaway
class OpenTabsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;
  final Function(OrderModel order) onSelectTabForEdit;

  const OpenTabsScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
    required this.onSelectTabForEdit,
  });

  @override
  State<OpenTabsScreen> createState() => _OpenTabsScreenState();
}

class _OpenTabsScreenState extends State<OpenTabsScreen> {
  static const String _prefsTablesKey = 'resto_configured_tables_v1';

  // Daftar Meja Fisik Restoran
  List<RestaurantTable> _tables = [];
  bool _isLoadingTables = true;

  // Filter Status Aktif: 'all', 'available', 'occupied', 'pending', 'takeaway'
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadConfiguredTables();
  }

  /// Memuat konfigurasi denah meja dari SharedPreferences
  Future<void> _loadConfiguredTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsTablesKey);

      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(savedJson) as List<dynamic>;
        _tables = decoded.map((e) => RestaurantTable.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        _tables = RestaurantTable.getDefaultTables();
        await _saveConfiguredTables();
      }
    } catch (e) {
      _tables = RestaurantTable.getDefaultTables();
    } finally {
      if (mounted) {
        setState(() => _isLoadingTables = false);
      }
    }
  }

  /// Menyimpan konfigurasi meja ke SharedPreferences
  Future<void> _saveConfiguredTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_tables.map((t) => t.toMap()).toList());
      await prefs.setString(_prefsTablesKey, encoded);
    } catch (_) {}
  }

  /// Dialog Cetak Tiket KOT Dapur
  void _showKitchenTicketDialog({
    required BuildContext context,
    required String tableNo,
    required String customerName,
    required List<OrderItem> items,
    String? orderId,
    bool isAdditionalOrder = false,
    int? roundNumber,
  }) {
    final ticketText = KitchenTicketService.buildKitchenTicketText(
      tableNo: tableNo,
      customerName: customerName,
      items: items,
      orderId: orderId,
      isAdditionalOrder: isAdditionalOrder,
      roundNumber: roundNumber,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.soup_kitchen_rounded, color: AppTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Tiket Pesanan Dapur (KOT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ticketText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF38BDF8),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tiket ini dapat langsung dikirim ke printer thermal koki dapur.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tiket dapur KOT dikirim ke printer thermal koki!'),
                  backgroundColor: AppTheme.emeraldGreen,
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Cetak Tiket KOT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka dialog pembayaran langsung dari Denah Meja (Satu Sentuhan tanpa redirect ke kasir POS)
  void _openDirectPaymentDialogForTable({
    required BuildContext context,
    required OrderModel order,
    required int payableAmount,
    required PosProvider posProvider,
    required OnlineOrderProvider onlineOrderProvider,
  }) {
    final shift = context.read<ShiftProvider>();
    if (!shift.hasActiveShift) {
      _promptStartShift(context);
      return;
    }

    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final debtProvider = context.read<CustomerDebtProvider>();

    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        totalAmount: payableAmount,
        initialCustomerName: order.customerName,
        onPaymentCompleted: ({
          required String paymentMethod,
          required int amountPaid,
          required int change,
          String? customerId,
          String? customerName,
        }) async {
          // 1. Selesaikan transaksi di sistem POS lokal secara langsung tanpa menghapus keranjang kasir
          final trx = await posProvider.completeOrderDirectly(
            order: order,
            shiftId: shift.activeShift!.id,
            cashierId: auth.currentUser?.id ?? 'cashier_unknown',
            cashierName: auth.currentUser?.name ?? 'Kasir',
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
            change: change,
            customerId: customerId,
            customerName: customerName,
          );

          // 3. Sinkronisasi status pelunasan ke Cloud Firestore secara realtime
          if (order.tableNo != null && context.mounted) {
            try {
              await onlineOrderProvider.markTableOrderPaid(
                tableNo: order.tableNo!,
                orderId: order.onlineOrderId ?? '',
                paymentMethod: paymentMethod,
              );
            } catch (e) {
              debugPrint('Gagal sinkron pelunasan ke cloud: $e');
            }
          }

          // 4. Catat penerimaan transaksi ke shift kasir & buku piutang pelanggan
          // Mencegah double-counting: catat sebesar uang yang ditagihkan saat ini (payableAmount)
          final recordedAmount = payableAmount;
          if (paymentMethod == 'cash') {
            await shift.recordCashSale(recordedAmount);
          } else if (paymentMethod == 'qris') {
            await shift.recordQrisSale(recordedAmount);
          } else if (paymentMethod == 'debt' && customerId != null) {
            await shift.recordDebtSale(recordedAmount);
            await debtProvider.recordNewDebt(
              customerId: customerId,
              amount: recordedAmount,
              orderId: trx.orderId,
            );
          }

          // 5. Beri feedback konfirmasi ke kasir
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pembayaran ${order.tableNo ?? "Meja"} berhasil diselesaikan & meja kini KOSONG.'),
                backgroundColor: AppTheme.emeraldGreen,
              ),
            );
          }

          // 6. Tampilkan dialog kirim struk WhatsApp
          if (context.mounted) {
            final receiptMsg = WhatsappService.generateReceiptMessage(
              storeName: settings.storeName,
              storeAddress: settings.address,
              receiptNo: trx.id.replaceAll('trx_', ''),
              order: order,
              cashierName: trx.cashierName,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
              change: change,
              receiptFooter: settings.receiptFooter,
            );

            showDialog(
              context: context,
              builder: (_) => WhatsappReceiptDialog(
                initialPhone: customerId != null
                    ? (debtProvider.customers.where((c) => c.id == customerId).isNotEmpty
                        ? debtProvider.customers.firstWhere((c) => c.id == customerId).phoneWA
                        : '')
                    : '',
                receiptMessage: receiptMsg,
                settings: settings,
                order: order,
                receiptNo: trx.id.replaceAll('trx_', ''),
                cashierName: trx.cashierName,
                paymentMethod: paymentMethod,
                amountPaid: amountPaid,
                change: change,
                orderTime: DateTime.now(),
                onPrintThermal: () {
                  PrinterReceiptService.printReceiptDirect(
                    settings: settings,
                    order: order,
                    receiptNo: trx.id.replaceAll('trx_', ''),
                    orderTime: DateTime.now(),
                    cashierName: trx.cashierName,
                    paymentMethod: paymentMethod,
                    amountPaid: amountPaid,
                    change: change,
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  /// Peringatan bahwa kasir wajib membuka shift terlebih dahulu sebelum transaksi
  void _promptStartShift(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shift Belum Dibuka'),
        content: const Text(
          'Kasir wajib membuka shift kerja dan menginput modal awal sebelum dapat melakukan transaksi pembayaran.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftScreen()));
            },
            child: const Text('Buka Shift Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<PosProvider>();
    final onlineOrderProvider = context.watch<OnlineOrderProvider>();
    final shiftProvider = context.watch<ShiftProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    final allOrders = posProvider.allOrders;
    final onlineOrders = onlineOrderProvider.onlineOrders;
    final pendingCalls = onlineOrderProvider.pendingCalls;
    final now = DateTime.now();

    if (_isLoadingTables) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAmber),
      );
    }

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final currentShiftId = shiftProvider.activeShift?.id ?? 'shift_default';
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // 1. Pesanan Meja Fisik Aktif (Dine-in):
    //    - Pesanan belum lunas (status == 'open') yang memiliki nomor meja fisik
    //    - Pesanan sudah lunas di kasir (status == 'completed') yang belum selesai disajikan (kitchenStatus != 'served') dalam 24 jam
    final activeTableOrders = allOrders.where((o) {
      if (o.status == 'cancelled') return false;
      if (o.id.startsWith('ord_repay_') || o.items.any((i) => i.productId == 'item_repay')) return false;
      if (o.tableNo == null || o.tableNo!.trim().isEmpty) return false;
      final t = o.tableNo!.toLowerCase();
      final isTakeaway = t.contains('takeaway') || t.contains('bawa pulang') || t.contains('bungkus');
      if (isTakeaway) return false;

      if (o.status == 'open') return true;
      if (o.status == 'completed') {
        return o.kitchenStatus != 'served' && now.difference(o.createdAt).inHours < 24;
      }
      return false;
    }).toList();

    // 2. Pesanan Bawa Pulang / Takeaway Aktif:
    //    - Pesanan takeaway belum lunas (status == 'open')
    //    - Pesanan takeaway sudah lunas di kasir (status == 'completed') tapi makanannya masih diproses di dapur (kitchenStatus != 'served') dalam 24 jam
    final takeawayOrders = allOrders.where((o) {
      if (o.status == 'cancelled') return false;
      if (o.id.startsWith('ord_repay_') || o.items.any((i) => i.productId == 'item_repay')) return false;
      final isTakeaway = o.tableNo == null ||
          o.tableNo!.trim().isEmpty ||
          o.tableNo!.toLowerCase().contains('takeaway') ||
          o.tableNo!.toLowerCase().contains('bawa pulang') ||
          o.tableNo!.toLowerCase().contains('bungkus');
      if (!isTakeaway) return false;

      if (o.status == 'open') return true;
      if (o.status == 'completed') {
        return o.kitchenStatus != 'served' && now.difference(o.createdAt).inHours < 24;
      }
      return false;
    }).toList();

    // 3. Kumpulkan seluruh meja dinamis (gabungkan meja default dengan meja custom dari pesanan)
    final allTableNumbers = <String>{};
    for (final t in _tables) {
      allTableNumbers.add(t.tableNumber);
    }
    for (final o in activeTableOrders) {
      if (o.tableNo != null && o.tableNo!.trim().isNotEmpty) {
        allTableNumbers.add(o.tableNo!.trim());
      }
    }
    for (final o in onlineOrders) {
      if (o.tableNo.trim().isNotEmpty) {
        final normName = o.tableNo.startsWith('Meja') ? o.tableNo : 'Meja ${o.tableNo.padLeft(2, '0')}';
        allTableNumbers.add(normName);
      }
    }

    // Buat daftar RestaurantTable lengkap (terurut rapi)
    final combinedTables = allTableNumbers.map((tableNum) {
      final found = _tables.where((t) => RestaurantTable.isMatch(t.tableNumber, tableNum)).firstOrNull;
      if (found != null) return found;
      return RestaurantTable(
        id: 'T_${tableNum.replaceAll(RegExp(r'\s+'), '_')}',
        tableNumber: tableNum,
        section: 'Reguler',
        capacity: 4,
        isActive: true,
      );
    }).toList();

    // Urutkan meja berdasarkan nomor
    combinedTables.sort((a, b) {
      final digA = int.tryParse(RestaurantTable.extractDigits(a.tableNumber)) ?? 999;
      final digB = int.tryParse(RestaurantTable.extractDigits(b.tableNumber)) ?? 999;
      return digA.compareTo(digB);
    });

    // 4. Petakan order aktif & pending ke tiap meja
    int countAvailable = 0;
    int countOccupied = 0;
    int countPending = 0;

    final tableCardDataList = combinedTables.map((tbl) {
      // Cari active order di meja resto (baik yang open tab maupun yang sudah bayar lunas santap)
      final active = activeTableOrders.where((o) => o.tableNo != null && RestaurantTable.isMatch(o.tableNo!, tbl.tableNumber)).firstOrNull;

      // Cari pending online order
      final pending = onlineOrders.where((o) => o.isPending && RestaurantTable.isMatch(o.tableNo, tbl.tableNumber)).firstOrNull;

      // Cari panggilan pelayan
      final waiterCall = pendingCalls.where((c) => RestaurantTable.isMatch(c.tableNo, tbl.tableNumber)).firstOrNull;

      if (pending != null) {
        countPending++;
      } else if (active != null) {
        countOccupied++;
      } else {
        countAvailable++;
      }

      return _TableDisplayData(
        table: tbl,
        activeOrder: active,
        pendingOrder: pending,
        hasWaiterCall: waiterCall != null,
        waiterCallNote: waiterCall?.notes,
        waiterCallId: waiterCall?.callId,
      );
    }).toList();

    // 4. Filter daftar meja sesuai chip yang dipilih
    final filteredDisplayData = tableCardDataList.where((item) {
      if (_activeFilter == 'available') {
        return item.activeOrder == null && item.pendingOrder == null;
      }
      if (_activeFilter == 'occupied') {
        return item.activeOrder != null && item.pendingOrder == null;
      }
      if (_activeFilter == 'pending') {
        return item.pendingOrder != null;
      }
      return true; // 'all'
    }).toList();

    // Daftar meja yang saat ini kosong (untuk opsi pindah meja)
    final availableTableNamesForMove = tableCardDataList
        .where((d) => d.activeOrder == null && d.pendingOrder == null)
        .map((d) => d.table.tableNumber)
        .toList();

    return Column(
      children: [
        // ====================================================================
        // TOP APP BAR / HEADER RESMI
        // ====================================================================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSidebar : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Denah Meja Resto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${combinedTables.length} Meja • $countOccupied Terisi • $countAvailable Kosong',
                      style: TextStyle(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),


              // Tombol Uji Coba Notifikasi Android (Heads-Up + Suara)
              IconButton(
                icon: const Icon(Icons.notifications_active_outlined, size: 20),
                tooltip: 'Uji Coba Notifikasi Android',
                onPressed: () async {
                  await NotificationService().showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifikasi uji coba pesanan masuk telah dipicu di sistem Android.'),
                        backgroundColor: AppTheme.emeraldGreen,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),

              // Tombol Sinkronisasi Menu Cloud
              IconButton(
                icon: onlineOrderProvider.isSyncingMenu
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 20),
                tooltip: 'Sinkronisasi Menu ke Cloud',
                onPressed: onlineOrderProvider.isSyncingMenu
                    ? null
                    : () async {
                        final categoryMap = {
                          for (final c in posProvider.categories) c.id: c.name,
                        };
                        final success = await onlineOrderProvider.syncMenuCatalog(
                          posProvider.products,
                          categoryNames: categoryMap,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Seluruh katalog menu resto berhasil disinkronkan ke Cloud Web!'
                                    : 'Gagal menyinkronkan menu. Periksa koneksi internet.',
                              ),
                              backgroundColor: success ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
        ),

        // ====================================================================
        // BANNER NOTIFIKASI PANGGILAN PELAYAN (CALL WAITER)
        // ====================================================================
        if (pendingCalls.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFEF3C7),
            child: Column(
              children: pendingCalls.map((call) {
                final tableLabel = call.tableNo.startsWith('Meja')
                    ? call.tableNo
                    : 'Meja ${call.tableNo.padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$tableLabel memanggil pelayan: "${call.requestType}"',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await onlineOrderProvider.resolveTableCall(call.callId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Selesai', style: TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // ====================================================================
        // FILTER CHIPS HORIZONTAL (RESPONSIF UNTUK HP PORTRAIT)
        // ====================================================================
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: isDark ? AppTheme.darkCardSurface : const Color(0xFFF9FAFB),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildFilterChip(
                label: 'Semua (${combinedTables.length})',
                filterKey: 'all',
                activeColor: AppTheme.primaryAmber,
                textColor: Colors.black,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '🟢 Kosong ($countAvailable)',
                filterKey: 'available',
                activeColor: const Color(0xFF10B981),
                textColor: Colors.white,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '🔴 Terisi ($countOccupied)',
                filterKey: 'occupied',
                activeColor: const Color(0xFF3B82F6),
                textColor: Colors.white,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '🟡 Order Baru ($countPending)',
                filterKey: 'pending',
                activeColor: const Color(0xFFF59E0B),
                textColor: Colors.black,
              ),
              if (takeawayOrders.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '🥡 Takeaway (${takeawayOrders.length})',
                  filterKey: 'takeaway',
                  activeColor: const Color(0xFFEA580C),
                  textColor: Colors.white,
                ),
              ],
            ],
          ),
        ),

        // ====================================================================
        // GRID DENAH MEJA VISUAL (MULTI-RESOLUSI)
        // ====================================================================
        Expanded(
          child: _activeFilter == 'takeaway'
              ? _buildTakeawayListView(takeawayOrders, isDark, textColor, textMuted)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    // Hitung jumlah kolom grid secara dinamis sesuai resolusi layar
                    int crossAxisCount;
                    double childAspectRatio;

                    if (width < 500) {
                      // HP Android Portrait (< 500px): 2 Kolom proporsional
                      crossAxisCount = 2;
                      childAspectRatio = 1.08;
                    } else if (width < 768) {
                      // HP Landscape / Tablet Kecil (500 - 768px): 3 Kolom
                      crossAxisCount = 3;
                      childAspectRatio = 1.12;
                    } else if (width < 1100) {
                      // Tablet Landscape (768 - 1100px): 4 Kolom
                      crossAxisCount = 4;
                      childAspectRatio = 1.15;
                    } else {
                      // Desktop Lebar (> 1100px): 5 - 6 Kolom
                      crossAxisCount = (width / 220).floor().clamp(5, 8);
                      childAspectRatio = 1.18;
                    }

                    if (filteredDisplayData.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant_rounded, size: 54, color: textMuted.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text(
                              'Tidak Ada Meja dengan Status Ini',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filteredDisplayData.length,
                      itemBuilder: (context, index) {
                        final item = filteredDisplayData[index];

                        return TableFloorCard(
                          table: item.table,
                          activeOrder: item.activeOrder,
                          pendingOrder: item.pendingOrder,
                          hasWaiterCall: item.hasWaiterCall,
                          waiterCallNote: item.waiterCallNote,
                          onTap: () {
                            TableActionSheet.show(
                              context: context,
                              table: item.table,
                              activeOrder: item.activeOrder,
                              pendingOrder: item.pendingOrder,
                              hasWaiterCall: item.hasWaiterCall,
                              waiterCallNote: item.waiterCallNote,
                              waiterCallId: item.waiterCallId,
                              availableTablesForMove: availableTableNamesForMove,
                              // Aksi Buka Transaksi Baru (Meja Kosong)
                              onOpenNewTransaction: (tableNo, customerName) {
                                posProvider.clearCart();
                                posProvider.setTableNo(tableNo);
                                posProvider.setCustomerName(customerName);

                                // Buat dummy temporary order agar bisa langsung dialihkan ke kasir
                                final tempOrder = OrderModel(
                                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                  shiftId: currentShiftId,
                                  customerName: customerName,
                                  tableNo: tableNo,
                                  items: [],
                                  status: 'open',
                                  createdAt: DateTime.now(),
                                );
                                widget.onSelectTabForEdit(tempOrder);
                              },
                              // Aksi Buka Meja Terisi ke Kasir
                              onOpenActiveOrderForEdit: (order) {
                                widget.onSelectTabForEdit(order);
                              },
                              // Aksi Terima Pesanan Online
                              onAcceptOnlineOrder: (onlineOrder) async {
                                final success = await onlineOrderProvider.acceptOrder(
                                  order: onlineOrder,
                                  posProvider: posProvider,
                                  shiftId: currentShiftId,
                                );
                                if (context.mounted) {
                                  _showKitchenTicketDialog(
                                    context: context,
                                    tableNo: onlineOrder.tableNo,
                                    customerName: onlineOrder.customerName,
                                    items: onlineOrder.items,
                                    orderId: onlineOrder.orderId,
                                    isAdditionalOrder: onlineOrder.isAdditionalOrder,
                                    roundNumber: onlineOrder.roundNumber,
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Pesanan ${onlineOrder.tableNo} diterima & masuk ke Tab Meja!'
                                            : 'Pesanan dimasukkan ke Tab Meja lokal.',
                                      ),
                                      backgroundColor: AppTheme.emeraldGreen,
                                    ),
                                  );
                                }
                              },
                              // Aksi Tolak Pesanan Online
                              onRejectOnlineOrder: (orderId) async {
                                await onlineOrderProvider.rejectOrder(orderId);
                              },
                              // Aksi Verifikasi QRIS Mandiri
                              onVerifyQrisPayment: (orderId) async {
                                await onlineOrderProvider.verifyQrisPayment(
                                  orderId,
                                  posProvider: posProvider,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pembayaran QRIS mandiri diverifikasi & tagihan lokal diperbarui!'),
                                      backgroundColor: AppTheme.emeraldGreen,
                                    ),
                                  );
                                }
                              },
                              // Aksi Selesaikan Panggilan Waiter
                              onResolveWaiterCall: (callId) async {
                                await onlineOrderProvider.resolveTableCall(callId);
                              },
                              // Aksi Cetak Tiket KOT Dapur
                              onPrintKitchenTicket: (order) {
                                _showKitchenTicketDialog(
                                  context: context,
                                  tableNo: order.tableNo ?? 'Meja',
                                  customerName: order.customerName,
                                  items: order.items,
                                  orderId: order.id,
                                );
                              },
                              // Aksi Selesaikan & Kosongkan Meja (Sudah Lunas QRIS)
                              onClosePaidTable: (order) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 24),
                                        const SizedBox(width: 8),
                                        Text('Selesaikan ${order.tableNo}?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pesanan tamu ${order.customerName} sudah dibayar lunas sebesar ${currencyFormat.format(order.paidAmount > 0 ? order.paidAmount : order.total)}.',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Meja akan dikosongkan dan status dapur diselesaikan.',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                      ElevatedButton.icon(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                                        label: const Text('Ya, Kosongkan Meja'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.emeraldGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && context.mounted) {
                                  if (order.status == 'completed') {
                                    // Pesanan sudah pernah di-checkout dan lunas di kasir sebelumnya (Pay-First Dine-in).
                                    // Cukup tandai siklus dapur selesai disajikan agar meja kembali kosong tanpa menduplikasi data transaksi kasir!
                                    await posProvider.updateKitchenStatus(order.id, 'served');
                                  } else {
                                    // Pesanan QRIS mandiri / self-order yang belum ditutup kasir
                                    final auth = context.read<AuthProvider>();
                                    final shift = context.read<ShiftProvider>();
                                    final onlineProvider = context.read<OnlineOrderProvider>();

                                    final effectiveShiftId = shift.activeShift?.id ?? currentShiftId;
                                    final trx = await posProvider.completeOrderDirectly(
                                      order: order,
                                      shiftId: effectiveShiftId,
                                      cashierId: auth.currentUser?.id ?? 'cashier_unknown',
                                      cashierName: auth.currentUser?.name ?? 'Kasir',
                                      paymentMethod: 'qris',
                                      amountPaid: order.total,
                                      change: 0,
                                      customerName: order.customerName,
                                    );

                                    if (shift.hasActiveShift) {
                                      await shift.recordQrisSale(trx.totalAmount);
                                    }

                                    if (order.tableNo != null) {
                                      await onlineProvider.markTableOrderPaid(
                                        tableNo: order.tableNo!,
                                        orderId: order.onlineOrderId ?? '',
                                        paymentMethod: 'qris',
                                      );
                                    }
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${order.tableNo} berhasil diselesaikan & meja kini KOSONG.'),
                                        backgroundColor: AppTheme.emeraldGreen,
                                      ),
                                    );
                                  }
                                }
                              },
                              // Aksi Bayar Langsung dari Denah Meja (Satu Sentuhan tanpa redirect)
                              onDirectPayTable: (order, payableAmount) {
                                _openDirectPaymentDialogForTable(
                                  context: context,
                                  order: order,
                                  payableAmount: payableAmount,
                                  posProvider: posProvider,
                                  onlineOrderProvider: onlineOrderProvider,
                                );
                              },
                              // Aksi Pindah Meja (Move Table)
                              onMoveTable: (currentTable, targetTable) async {
                                final ok = await posProvider.moveTable(currentTable, targetTable);
                                if (ok && context.mounted) {
                                  // Sinkronisasi nomor meja baru ke Cloud Firestore jika pesanan berasal dari self-order
                                  final movedOrder = posProvider.openOrders.firstWhere(
                                    (o) => o.tableNo != null && posProvider.normalizeTable(o.tableNo!) == posProvider.normalizeTable(targetTable),
                                    orElse: () => OrderModel(id: '', shiftId: '', items: [], status: '', createdAt: DateTime.now()),
                                  );
                                  if (movedOrder.onlineOrderId != null && movedOrder.onlineOrderId!.isNotEmpty) {
                                    await onlineOrderProvider.updateOrderTableNo(movedOrder.onlineOrderId!, targetTable);
                                  }
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Pesanan $currentTable berhasil dipindahkan ke $targetTable.'
                                            : 'Gagal: Meja tujuan ($targetTable) sedang terisi atau tidak ditemukan.',
                                      ),
                                      backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Widget Chip Filter Status Horizontal
  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required Color activeColor,
    required Color textColor,
  }) {
    final isSelected = _activeFilter == filterKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _activeFilter = filterKey),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? textColor : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan Khusus Pesanan Bungkus / Takeaway
  Widget _buildTakeawayListView(
    List<OrderModel> takeawayOrders,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    if (takeawayOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.takeout_dining_rounded, size: 54, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'Belum Ada Pesanan Bawa Pulang (Takeaway)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: takeawayOrders.length,
      itemBuilder: (context, index) {
        final order = takeawayOrders[index];
        final isPaid = order.status == 'completed' || (order.paidAmount >= order.total && order.total > 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TAKEAWAY',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppTheme.emeraldGreen.withValues(alpha: 0.15)
                                  : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPaid
                                    ? AppTheme.emeraldGreen.withValues(alpha: 0.4)
                                    : Colors.amber.shade700.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              isPaid ? 'LUNAS' : 'BELUM BAYAR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppTheme.emeraldGreen : Colors.amber.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.totalItems} item • ${currencyFormat.format(order.total)} • Dapur: ${order.kitchenStatus.toUpperCase()}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isPaid)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pos = context.read<PosProvider>();
                      await pos.updateKitchenStatus(order.id, 'served');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Pesanan bawa pulang ${order.customerName} telah diserahkan.'),
                            backgroundColor: AppTheme.emeraldGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Serahkan', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => widget.onSelectTabForEdit(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Buka / Bayar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper internal untuk data tampilan kartu meja
class _TableDisplayData {
  final RestaurantTable table;
  final OrderModel? activeOrder;
  final OnlineOrderModel? pendingOrder;
  final bool hasWaiterCall;
  final String? waiterCallNote;
  final String? waiterCallId;

  _TableDisplayData({
    required this.table,
    this.activeOrder,
    this.pendingOrder,
    this.hasWaiterCall = false,
    this.waiterCallNote,
    this.waiterCallId,
  });
}
