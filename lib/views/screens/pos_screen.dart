import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../services/whatsapp_service.dart';
import '../../services/printer_receipt_service.dart';
import '../widgets/custom_notes_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/whatsapp_receipt_dialog.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_image_view.dart';
import '../widgets/petty_cash_dialog.dart';
import '../widgets/transaction_history_view.dart';
import 'open_tabs_screen.dart';
import 'debts_screen.dart';
import 'shift_screen.dart';
import 'settings_screen.dart';

/// Layar Utama POS Resto Digital dengan tampilan antarmuka modern,
/// kartu produk elegan, pemilih meja interaktif, dan keranjang belanja responsif.
class PosScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const PosScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<String> _tableOptions = [
    'Meja 01', 'Meja 02', 'Meja 03', 'Meja 04', 'Meja 05',
    'Meja 06', 'Meja 07', 'Meja 08', 'Meja 09', 'Meja 10',
    'Bar Depan', 'Lesehan A', 'Lesehan B', 'Bawa Pulang (Take Away)',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pos = context.watch<PosProvider>();
    final shift = context.watch<ShiftProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    final openTabCount = pos.openOrders.length;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    Widget content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Kiri/Tengah: Katalog Menu Resto Modern
              Expanded(
                flex: 7,
                child: _buildCatalogSection(pos, isDark, textColor, textMuted, borderColor),
              ),
              // Panel Kanan: Live Nota Struk Pesanan
              SizedBox(
                width: 390,
                child: _buildCartPanel(context, pos, shift, settings, isDark, textColor, textMuted, borderColor),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(
                child: _buildCatalogSection(pos, isDark, textColor, textMuted, borderColor),
              ),
              if (!pos.isCartEmpty)
                _buildBottomMobileCartBar(context, pos, shift, settings),
            ],
          );

    // Jika berjalan di dalam MainDashboardScreen (embedded), tidak perlu Scaffold/AppBar ganda
    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, auth, shift, isDark, textColor, textMuted),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant_rounded, color: AppTheme.primaryAmber),
            const SizedBox(width: 8),
            Text(settings.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    auth.currentUser?.name ?? 'Kasir',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.table_restaurant),
                tooltip: 'Pesanan Meja Resto (Open Tab)',
                onPressed: () => _openOpenTabsScreen(context),
              ),
              if (openTabCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$openTabCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Riwayat Transaksi Penjualan',
            onPressed: () => showTransactionHistoryDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Buku Kasbon Resto',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Shift & Arus Kas',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Toko & Kasir (Owner)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Kunci Layar (Ganti Shift)',
            onPressed: () => auth.lockScreen(),
          ),
        ],
      ),
      body: content,
    );
  }

  // --- Header Bersih Saat Berjalan di Dashboard Terpadu ---
  Widget _buildEmbeddedHeader(
    BuildContext context,
    AuthProvider auth,
    ShiftProvider shift,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSidebar : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            ),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Katalog Menu & Kasir',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isCompact
                          ? 'Bayar Langsung & Open Tab'
                          : 'Pencatatan pesanan cepat resto (Bayar Langsung & Open Tab)',
                      style: TextStyle(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge Status Shift Kasir Interaktif (Bisa Diklik Langsung)
              Tooltip(
                message: shift.hasActiveShift
                    ? 'Klik untuk melihat ringkasan shift & opsi tutup shift'
                    : 'Klik untuk membuka shift kasir baru',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (!shift.hasActiveShift) {
                        _showStartShiftDialog(context, shift, auth);
                      } else {
                        _showActiveShiftSummaryDialog(context, shift, auth);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 14,
                        vertical: isCompact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: shift.hasActiveShift
                            ? (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFD1FAE5))
                            : (isDark ? const Color(0xFF3B2824) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: shift.hasActiveShift
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF34D399))
                              : Colors.redAccent,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (shift.hasActiveShift ? AppTheme.emeraldGreen : AppTheme.dangerRed)
                                .withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: shift.hasActiveShift ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            isCompact
                                ? (shift.hasActiveShift ? 'Shift Aktif' : 'Shift Tutup')
                                : (shift.hasActiveShift
                                    ? 'Shift Kasir: ${shift.activeShift!.cashierName} (Laci: ${_currencyFormat.format(shift.activeShift!.expectedCash)})'
                                    : 'Shift Belum Dibuka'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: shift.hasActiveShift
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                  : AppTheme.dangerRed,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            shift.hasActiveShift
                                ? Icons.arrow_drop_down_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 16,
                            color: shift.hasActiveShift
                                ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                : AppTheme.dangerRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Cepat Riwayat Transaksi Kasir
              Tooltip(
                message: 'Lihat Riwayat Transaksi & Cetak Ulang Nota',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => showTransactionHistoryDialog(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 12,
                        vertical: isCompact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF232530) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF383B4A) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: isDark ? AppTheme.primaryAmber : const Color(0xFFD97706),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Riwayat Transaksi',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Bagian Katalog Menu Resto ---
  Widget _buildCatalogSection(
    PosProvider pos,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
  ) {
    final categories = pos.categories;
    final products = pos.filteredProducts;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar Kategori Menu (Pills Modern)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill(
                  label: 'Semua Menu',
                  icon: Icons.apps_rounded,
                  isSelected: pos.selectedCategoryId == 'all',
                  onTap: () => pos.selectCategory('all'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final isSelected = pos.selectedCategoryId == cat.id;
                  IconData icon = Icons.local_cafe_rounded;
                  if (cat.id == 'cat_makanan') icon = Icons.ramen_dining_rounded;
                  if (cat.id == 'cat_rokok') icon = Icons.smoking_rooms_rounded;
                  if (cat.id == 'cat_camilan') icon = Icons.bakery_dining_rounded;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryPill(
                      label: cat.name,
                      icon: icon,
                      isSelected: isSelected,
                      onTap: () => pos.selectCategory(cat.id),
                      isDark: isDark,
                    ),
                  );
                }),
                // Tombol Aksi Cepat Tambah Menu Baru
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const ProductFormDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: isDark ? 0.18 : 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryAmber.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.primaryAmber),
                          SizedBox(width: 6),
                          Text(
                            '+ Tambah Menu',
                            style: TextStyle(
                              color: AppTheme.primaryAmber,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Grid Menu Produk Modern
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Menu tidak ditemukan.',
                          style: TextStyle(color: textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: 168,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildModernProductCard(context, product, pos, isDark, textColor, textMuted, borderColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark ? AppTheme.primaryAmber : AppTheme.primaryCoffee;
    final inactiveBg = isDark ? const Color(0xFF222430) : const Color(0xFFF3F4F6);
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveText = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeText : inactiveText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeText : inactiveText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Kartu Produk Menu Modern ---
  Widget _buildModernProductCard(
    BuildContext context,
    ProductModel product,
    PosProvider pos,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
  ) {
    // Icon dan warna gradient berdasarkan kategori
    List<Color> gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    IconData itemIcon = Icons.coffee_rounded;

    if (product.categoryId == 'cat_makanan') {
      gradientColors = [const Color(0xFFF97316), const Color(0xFFEA580C)];
      itemIcon = Icons.ramen_dining_rounded;
    } else if (product.categoryId == 'cat_rokok') {
      gradientColors = [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
      itemIcon = Icons.smoking_rooms_rounded;
    } else if (product.categoryId == 'cat_camilan') {
      gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
      itemIcon = Icons.bakery_dining_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => pos.addToCart(product),
          onLongPress: () => _showNotesDialog(context, product, pos),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Ikon & Tombol Modifiers Catatan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ProductImageView(
                        imageUrl: product.imageUrl,
                        width: 34,
                        height: 34,
                        fallbackIcon: itemIcon,
                        fallbackIconSize: 18,
                        backgroundColor: gradientColors.first.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Row(
                      children: [
                        // Tombol Edit Menu (Ubah Harga / Stok)
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => ProductFormDialog(productToEdit: product),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2F3D) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 12, color: textMuted),
                                const SizedBox(width: 2),
                                Text(
                                  'Edit',
                                  style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Tombol Tambah Catatan Modifiers
                        InkWell(
                          onTap: () => _showNotesDialog(context, product, pos),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2F3D) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit_note, size: 14, color: textMuted),
                                const SizedBox(width: 2),
                                Text(
                                  '+ Note',
                                  style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Nama Menu
                Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),

                // Baris Harga & Tombol Tambah
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stok: ${product.stock} ${product.unit}',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(product.sellPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2F3D) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, size: 18, color: AppTheme.primaryAmber),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Panel Keranjang Belanja & Live Nota Struk ---
  Widget _buildCartPanel(
    BuildContext context,
    PosProvider pos,
    ShiftProvider shift,
    dynamic settings,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
  ) {
    final isTableEnabled = settings.tableFeatureEnabled;
    final auth = context.watch<AuthProvider>();
    final cashierName = auth.currentUser?.name ?? 'Kasir';
    final now = DateTime.now();
    final timeStr = DateFormat('dd/MM/yy HH:mm').format(now);
    final totalItemsCount = pos.cartItems.fold<int>(0, (sum, i) => sum + i.qty);

    // Skema warna kertas struk dan pembatas
    final receiptBg = isDark ? const Color(0xFF1E2232) : Colors.white;
    final receiptBorder = isDark ? const Color(0xFF2C3246) : const Color(0xFFE2E8F0);
    final receiptSubBg = isDark ? const Color(0xFF171A26) : const Color(0xFFF8FAFC);
    final dashedColor = isDark ? const Color(0xFF3E455E) : const Color(0xFFCBD5E1);

    return Container(
      color: isDark ? const Color(0xFF131520) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // KERTAS STRUK / LIVE NOTA CONTAINER DENGAN SHADOW FISIK
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: receiptBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(4)),
                border: Border.all(color: receiptBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. CLIP ATAS & KEPALA STRUK RESMI
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: receiptSubBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Column(
                      children: [
                        // Notch / Penjepit Rel Struk Logam
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3E455E) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Nama Toko & Badge Status Live
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🍽️', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  settings.storeName.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            // Badge Status Nota
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: pos.activeEditingTab != null
                                    ? AppTheme.primaryAmber.withValues(alpha: 0.18)
                                    : AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: pos.activeEditingTab != null ? AppTheme.primaryAmber : AppTheme.emeraldGreen,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pos.activeEditingTab != null ? AppTheme.primaryAmber : AppTheme.emeraldGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    pos.activeEditingTab != null ? 'TAB MEJA' : 'LIVE NOTA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: pos.activeEditingTab != null ? AppTheme.primaryAmber : AppTheme.emeraldGreen,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Alamat & Info Kasir
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kasir: $cashierName',
                              style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Baris Input Form Meja & Nama Tamu (Sleek Nota Inputs)
                        Row(
                          children: [
                            if (isTableEnabled) ...[
                              Expanded(
                                flex: 5,
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: receiptBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: receiptBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: pos.selectedTableNo,
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                                      hint: Row(
                                        children: [
                                          const Icon(Icons.table_restaurant_outlined, size: 14, color: AppTheme.primaryAmber),
                                          const SizedBox(width: 4),
                                          Text('Pilih Meja', style: TextStyle(fontSize: 11, color: textMuted)),
                                        ],
                                      ),
                                      items: _tableOptions.map((tbl) {
                                        return DropdownMenuItem(
                                          value: tbl,
                                          child: Text(tbl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                        );
                                      }).toList(),
                                      onChanged: (val) => pos.setTableNo(val),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              flex: 6,
                              child: SizedBox(
                                height: 36,
                                child: TextFormField(
                                  key: ValueKey(pos.activeEditingTab?.id ?? 'cart_cust_name'),
                                  initialValue: pos.customerName == 'Pelanggan' ? '' : pos.customerName,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    filled: true,
                                    fillColor: receiptBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: receiptBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: receiptBorder),
                                    ),
                                    prefixIcon: Icon(Icons.person_outline_rounded, size: 15, color: textMuted),
                                    hintText: 'Nama Tamu',
                                    hintStyle: TextStyle(fontSize: 11, color: textMuted),
                                  ),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                  onChanged: (val) => pos.setCustomerName(val),
                                ),
                              ),
                            ),
                            if (!pos.isCartEmpty) ...[
                              const SizedBox(width: 5),
                              InkWell(
                                onTap: () => pos.clearCart(),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 34,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 17, color: AppTheme.dangerRed),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Garis Putus-putus Struk
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DashedDivider(color: dashedColor, height: 1.2),
                  ),

                  // 2. JUDUL KOLOM STRUK (TABLE HEADER NOTA)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'MENU / PESANAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'QTY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(
                            'TOTAL',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DashedDivider(color: dashedColor, height: 1.2),
                  ),

                  // 3. DAFTAR ITEM PESANAN NOTA
                  Expanded(
                    child: pos.isCartEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: textMuted.withValues(alpha: 0.35)),
                                const SizedBox(height: 8),
                                Text(
                                  '- NOTA KOSONG -',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    color: textMuted.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sentuh menu di katalog untuk\nmenambahkan item ke nota',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: textMuted.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            itemCount: pos.cartItems.length,
                            separatorBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: DashedDivider(color: dashedColor.withValues(alpha: 0.4), height: 1),
                            ),
                            itemBuilder: (context, index) {
                              final item = pos.cartItems[index];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Nama Menu
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Total Harga Menu
                                      Text(
                                        _currencyFormat.format(item.total),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Catatan Khusus Modifiers
                                  if (item.notes.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      '↳ Catatan: ${item.notes}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? const Color(0xFFFCD34D) : Colors.brown.shade700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  // Baris Unit Price & Stepper Qty
                                  Row(
                                    children: [
                                      Text(
                                        '@ ${_currencyFormat.format(item.price)}',
                                        style: TextStyle(fontSize: 11, color: textMuted),
                                      ),
                                      const Spacer(),
                                      // Stepper Qty Kertas Nota
                                      Container(
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF161824) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: receiptBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap: () => pos.updateItemQty(index, -1),
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                                              child: Container(
                                                width: 24,
                                                alignment: Alignment.center,
                                                child: Icon(Icons.remove, size: 12, color: textColor),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${item.qty}',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => pos.updateItemQty(index, 1),
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                                              child: Container(
                                                width: 24,
                                                alignment: Alignment.center,
                                                child: Icon(Icons.add, size: 12, color: textColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Tombol Hapus Item Cepat
                                      InkWell(
                                        onTap: () => pos.removeFromCart(index),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          child: Icon(Icons.close_rounded, size: 14, color: textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  // 4. RINGKASAN KALKULASI NOTA (SUBTOTAL, DP QRIS, TOTAL)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DashedDivider(color: dashedColor, height: 1.5),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Menu / Qty:', style: TextStyle(fontSize: 11, color: textMuted)),
                            Text(
                              '${pos.cartItems.length} Menu ($totalItemsCount Pcs)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal Tagihan:', style: TextStyle(fontSize: 11, color: textMuted)),
                            Text(
                              _currencyFormat.format(pos.cartSubtotal),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),

                        // Baris Diskon / Voucher Transaksi
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                DiscountDialog.show(
                                  context: context,
                                  subtotal: pos.cartSubtotal,
                                  currentDiscountAmount: pos.cartDiscountAmount,
                                  currentDiscountPercent: pos.cartDiscountPercent,
                                  onApplyDiscount: ({required discountAmount, required discountPercent}) {
                                    if (discountPercent > 0) {
                                      pos.setDiscountPercent(discountPercent);
                                    } else {
                                      pos.setDiscountAmount(discountAmount);
                                    }
                                  },
                                  onClearDiscount: () => pos.clearDiscount(),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 13,
                                    color: pos.cartDiscountAmount > 0 ? Colors.redAccent : AppTheme.primaryAmber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    pos.cartDiscountAmount > 0
                                        ? 'Diskon (${pos.cartDiscountPercent.toStringAsFixed(0)}%):'
                                        : '+ Diskon/Promo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: pos.cartDiscountAmount > 0 ? Colors.redAccent : AppTheme.primaryAmber,
                                      decoration: pos.cartDiscountAmount == 0 ? TextDecoration.underline : TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pos.cartDiscountAmount > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '- ${_currencyFormat.format(pos.cartDiscountAmount)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => pos.clearDiscount(),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Rp 0',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                          ],
                        ),

                        // Baris Service Charge jika diaktifkan
                        if (settings.enableServiceCharge) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Biaya Layanan (${settings.serviceChargePercentage.toStringAsFixed(0)}%):',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                              Text(
                                _currencyFormat.format(pos.calculateServiceCharge(settings)),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ],
                          ),
                        ],

                        // Baris Pajak Resto PB1 jika diaktifkan
                        if (settings.enableTax) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pajak Resto PB1 (${settings.taxPercentage.toStringAsFixed(0)}%):',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                              Text(
                                _currencyFormat.format(pos.calculateTax(settings)),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ],
                          ),
                        ],

                        if (pos.activeEditingTab != null && (pos.activeEditingTab!.paidAmount > 0)) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Uang Muka QRIS (Lunas):', style: TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w600)),
                              Text(
                                '- ${_currencyFormat.format(pos.activeEditingTab!.paidAmount)}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Garis Ganda / Tebal Penutup Total
                        DashedDivider(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), height: 1.8),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL TAGIHAN:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                                color: textColor,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final grandTotal = pos.calculateCartGrandTotal(settings);
                                final initPaid = pos.activeEditingTab?.paidAmount ?? 0;
                                final payable = (grandTotal - initPaid).clamp(0, 999999999);
                                return Text(
                                  _currencyFormat.format(initPaid > 0 ? payable : grandTotal),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryAmber,
                                    letterSpacing: -0.5,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Barcode Dekoratif Struk Thermal
                        _buildThermalBarcode(isDark),
                      ],
                    ),
                  ),

                  // Efek Sobekan Gerigi Kertas Struk (Sawtooth Cut Bottom)
                  CustomPaint(
                    size: const Size(double.infinity, 6),
                    painter: SawtoothPainter(
                      color: receiptBg,
                      triangleWidth: 10,
                      triangleHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // TOMBOL AKSI DOCKED DI BAWAH NOTA (SIMPAN TAB & BAYAR SEKARANG)
          Row(
            children: [
              // Tombol Simpan Tab
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pos.isCartEmpty
                      ? null
                      : () async {
                          if (!shift.hasActiveShift) {
                            _promptStartShift(context);
                            return;
                          }
                          await pos.saveAsOpenTab(shiftId: shift.activeShift!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pesanan berhasil disimpan sebagai Tab / Meja Nongkrong')),
                            );
                          }
                        },
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Simpan Tab', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: isDark ? const Color(0xFF3E455E) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Bayar Sekarang / Selesai Meja
              Expanded(
                flex: 2,
                child: Builder(
                  builder: (ctx) {
                    final grandTotal = pos.calculateCartGrandTotal(settings);
                    final initialPaid = pos.activeEditingTab?.paidAmount ?? 0;
                    final isFullyPaid = pos.activeEditingTab != null && initialPaid >= grandTotal && grandTotal > 0;
                    final remaining = (grandTotal - initialPaid).clamp(0, 999999999);

                    if (isFullyPaid) {
                      return ElevatedButton.icon(
                        onPressed: pos.isCartEmpty ? null : () => _completeFullyPaidQrisOrder(context, pos, shift, settings),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 17),
                        label: const Text('Selesai & Kosongkan Meja', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      );
                    }

                    return ElevatedButton.icon(
                      onPressed: pos.isCartEmpty ? null : () => _openPaymentDialog(context, pos, shift, settings),
                      icon: const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text(
                        initialPaid > 0
                            ? 'Bayar Sisa (${_currencyFormat.format(remaining)})'
                            : 'Bayar Sekarang',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: initialPaid > 0 ? AppTheme.primaryAmber : AppTheme.emeraldGreen,
                        foregroundColor: initialPaid > 0 ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Generator Barcode Dekoratif Struk Thermal
  Widget _buildThermalBarcode(bool isDark) {
    final barColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    const bars = [2, 1, 3, 1, 2, 4, 1, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 4, 2, 1, 3, 1, 2];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bars.map((w) {
            return Container(
              width: w.toDouble(),
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              color: barColor.withValues(alpha: 0.7),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '*** TERIMA KASIH - RESTO DIGITAL ***',
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: barColor,
          ),
        ),
      ],
    );
  }

  // --- Bottom Bar Mobile / Layar Sempit ---
  Widget _buildBottomMobileCartBar(
    BuildContext context,
    PosProvider pos,
    ShiftProvider shift,
    dynamic settings,
  ) {
    final initialPaid = pos.activeEditingTab?.paidAmount ?? 0;
    final isFullyPaid = pos.activeEditingTab != null && initialPaid >= pos.cartSubtotal && pos.cartSubtotal > 0;
    final remaining = (pos.cartSubtotal - initialPaid).clamp(0, 999999999);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.darkSidebar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFullyPaid
                    ? '${pos.cartTotalItems} Menu (Lunas QRIS)'
                    : (initialPaid > 0
                        ? 'Sisa Tagihan (${pos.cartTotalItems} item)'
                        : '${pos.cartTotalItems} Menu Dipilih'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                isFullyPaid
                    ? 'Rp 0 (LUNAS)'
                    : (initialPaid > 0 ? _currencyFormat.format(remaining) : _currencyFormat.format(pos.cartSubtotal)),
                style: TextStyle(
                  color: isFullyPaid ? AppTheme.emeraldGreen : AppTheme.primaryAmber,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: isFullyPaid
                ? () => _completeFullyPaidQrisOrder(context, pos, shift, settings)
                : () => _openPaymentDialog(context, pos, shift, settings),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFullyPaid ? AppTheme.emeraldGreen : (initialPaid > 0 ? AppTheme.primaryAmber : AppTheme.emeraldGreen),
              foregroundColor: (isFullyPaid || initialPaid == 0) ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(isFullyPaid ? Icons.cleaning_services_rounded : Icons.check, size: 18),
            label: Text(
              isFullyPaid
                  ? 'Selesai & Kosongkan'
                  : (initialPaid > 0 ? 'Bayar Sisa (${_currencyFormat.format(remaining)})' : 'Bayar Sekarang'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeFullyPaidQrisOrder(
    BuildContext context,
    PosProvider pos,
    ShiftProvider shift,
    dynamic settings,
  ) async {
    final activeTab = pos.activeEditingTab;
    final tableName = pos.selectedTableNo ?? activeTab?.tableNo ?? 'Meja';
    final custName = pos.customerName.isNotEmpty ? pos.customerName : (activeTab?.customerName ?? 'Pelanggan');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 24),
            const SizedBox(width: 8),
            Text('Selesaikan $tableName?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan $tableName a.n $custName sudah DIBAYAR LUNAS via QRIS (${_currencyFormat.format(pos.cartSubtotal)}).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tidak ada tagihan tambahan. Meja akan dikosongkan dan transaksi dicatat lunas ke sistem.',
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

    if (confirm != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final onlineIdToNotify = activeTab?.onlineOrderId;

    // Catat transaksi di POS sebagai QRIS lunas
    final trx = await pos.completeCheckout(
      shiftId: shift.activeShift!.id,
      cashierId: auth.currentUser?.id ?? 'cashier_unknown',
      cashierName: auth.currentUser?.name ?? 'Kasir',
      paymentMethod: 'qris',
      amountPaid: pos.cartSubtotal,
      change: 0,
      customerName: custName,
    );

    // Sinkronisasi status paid ke Cloud Firestore
    if (context.mounted) {
      try {
        final onlineProvider = context.read<OnlineOrderProvider>();
        await onlineProvider.markTableOrderPaid(
          tableNo: tableName,
          orderId: onlineIdToNotify ?? '',
          paymentMethod: 'qris',
        );
      } catch (e) {
        debugPrint('Gagal sinkron pelunasan ke cloud: $e');
      }
    }

    // Catat ke shift kasir
    await shift.recordQrisSale(trx.totalAmount);

    // Buka dialog struk WhatsApp jika diinginkan
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tableName berhasil diselesaikan. Meja kini KOSONG.'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );

      final currentOrder = pos.findOrderById(trx.orderId);

      final receiptMsg = WhatsappService.generateReceiptMessage(
        storeName: settings.storeName,
        storeAddress: settings.address,
        receiptNo: trx.id.replaceAll('trx_', ''),
        order: currentOrder,
        cashierName: trx.cashierName,
        paymentMethod: 'qris',
        amountPaid: pos.cartSubtotal,
        change: 0,
        receiptFooter: settings.receiptFooter,
      );

      showDialog(
        context: context,
        builder: (_) => WhatsappReceiptDialog(
          initialPhone: '',
          receiptMessage: receiptMsg,
          settings: settings,
          order: currentOrder,
          receiptNo: trx.id.replaceAll('trx_', ''),
          cashierName: trx.cashierName,
          paymentMethod: 'QRIS',
          amountPaid: pos.cartSubtotal,
          change: 0,
          orderTime: DateTime.now(),
          onPrintThermal: () {
            PrinterReceiptService.printReceiptDirect(
              settings: settings,
              order: currentOrder,
              receiptNo: trx.id.replaceAll('trx_', ''),
              orderTime: DateTime.now(),
              cashierName: trx.cashierName,
              paymentMethod: 'QRIS',
              amountPaid: pos.cartSubtotal,
              change: 0,
            );
          },
        ),
      );
    }
  }

  void _showNotesDialog(BuildContext context, ProductModel product, PosProvider pos) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => CustomNotesDialog(productName: product.name),
    );

    if (note != null) {
      pos.addToCart(product, notes: note);
    }
  }

  void _openOpenTabsScreen(BuildContext context) {
    final pos = context.read<PosProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenTabsScreen(
          onSelectTabForEdit: (order) {
            pos.loadOpenTabForEdit(order);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Peringatan bahwa kasir wajib membuka shift sebelum bertransaksi
  void _promptStartShift(BuildContext context) {
    final shift = context.read<ShiftProvider>();
    final auth = context.read<AuthProvider>();
    _showStartShiftDialog(context, shift, auth);
  }

  /// Dialog Interaktif Pembukaan Shift Baru (Input Modal Awal Laci)
  void _showStartShiftDialog(
    BuildContext context,
    ShiftProvider shiftProvider,
    AuthProvider authProvider,
  ) {
    final modalCtrl = TextEditingController(text: '100000');
    final currentUser = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Dialog
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryAmber, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buka Shift Kasir Baru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Input uang modal awal laci sebelum transaksi',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Info Kasir Bertugas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282B38) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: AppTheme.primaryAmber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kasir Bertugas:', style: TextStyle(fontSize: 10.5, color: textMuted)),
                                Text(
                                  currentUser?.name ?? 'Kasir Resto',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (currentUser?.role ?? 'kasir').toUpperCase(),
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Modal Awal
                    const Text('Modal Kas Awal di Laci (Rp):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: modalCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        hintText: '100000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF282B38) : const Color(0xFFF8FAFC),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Tombol Cepat Pecahan Modal
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [50000, 100000, 200000, 500000].map((amt) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(_currencyFormat.format(amt), style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              modalCtrl.text = amt.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final initial = int.tryParse(modalCtrl.text.trim()) ?? 100000;
                              final cashier = currentUser ??
                                  UserModel(
                                    id: 'cashier_unknown',
                                    name: 'Kasir Resto',
                                    role: 'cashier',
                                    pinHash: '',
                                    salt: '',
                                  );
                              await shiftProvider.startShift(
                                cashier: cashier,
                                initialCash: initial,
                              );
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Shift kasir berhasil dibuka dengan modal awal ${_currencyFormat.format(initial)}! 🚀'),
                                    backgroundColor: AppTheme.emeraldGreen,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Buka Shift Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dialog Ringkasan Shift Aktif & Opsi Penutupan Shift Kasir
  void _showActiveShiftSummaryDialog(
    BuildContext context,
    ShiftProvider shiftProvider,
    AuthProvider authProvider,
  ) {
    final active = shiftProvider.activeShift;
    if (active == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(active.startedAt);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Dialog
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emeraldGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Ringkasan Shift Aktif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AKTIF',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Kasir: ${active.cashierName} • Buka: $timeStr', style: TextStyle(fontSize: 11, color: textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Kotak Utama Uang Kas di Laci (Expected Cash)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uang Kas di Laci (Seharusnya Ada):',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(active.expectedCash),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.emeraldGreen),
                          ),
                        ],
                      ),
                      Icon(Icons.point_of_sale_rounded, size: 36, color: AppTheme.emeraldGreen.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Rincian Arus Finansial Shift
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282B38) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildShiftRow('Modal Awal Laci', _currencyFormat.format(active.initialCash), textColor, textMuted),
                      const Divider(height: 12),
                      _buildShiftRow('Penjualan Tunai (Cash)', _currencyFormat.format(active.totalCashSales), textColor, textMuted, isPositive: true),
                      const Divider(height: 12),
                      _buildShiftRow('Penjualan QRIS (Bank/E-Wallet)', _currencyFormat.format(active.totalQrisSales), textColor, textMuted),
                      const Divider(height: 12),
                      _buildShiftRow('Pelunasan Kasbon Masuk', _currencyFormat.format(active.totalDebtRepaidCash), textColor, textMuted),
                      const Divider(height: 12),
                      _buildShiftRow('Kas Keluar (Petty Cash/Biaya)', '- ${_currencyFormat.format(active.totalCashOut)}', textColor, textMuted, isNegative: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Baris Tombol Aksi Kas & Layar Lengkap
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPettyCashDialog(context, shiftProvider, authProvider);
                        },
                        icon: const Icon(Icons.outbox_rounded, size: 15),
                        label: const Text('Kas Masuk/Keluar', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftScreen()));
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Layar Penuh Shift', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // TOMBOL UTAMA: TUTUP SHIFT KASIR
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCloseShiftDialog(context, shiftProvider);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Tutup Shift & Rekonsiliasi Kas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baris Rincian Finansial Shift
  Widget _buildShiftRow(
    String label,
    String value,
    Color textColor,
    Color textMuted, {
    bool isPositive = false,
    bool isNegative = false,
  }) {
    Color valColor = textColor;
    if (isPositive) valColor = AppTheme.emeraldGreen;
    if (isNegative) valColor = AppTheme.dangerRed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textMuted)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }

  /// Dialog Pencatatan Kas Masuk / Kas Keluar (Petty Cash)
  void _showPettyCashDialog(
    BuildContext context,
    ShiftProvider shiftProvider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (_) => PettyCashDialog(
        onRecorded: (amount, notes) async {
          await shiftProvider.recordPettyCashOut(
            amount: amount,
            notes: notes,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pengeluaran kas ${_currencyFormat.format(amount)} berhasil dicatat!'),
                backgroundColor: AppTheme.emeraldGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Dialog Rekonsiliasi Kas Fisik dan Penutupan Shift Kasir
  void _showCloseShiftDialog(
    BuildContext context,
    ShiftProvider shiftProvider,
  ) {
    final actualCashCtrl = TextEditingController();
    final expectedCash = shiftProvider.activeShift?.expectedCash ?? 0;
    final settings = context.read<SettingsProvider>().settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    showDialog(
      context: context,
      builder: (ctx) {
        int diff = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final actual = int.tryParse(actualCashCtrl.text.trim()) ?? 0;
            diff = actual - expectedCash;

            Color diffColor = Colors.grey;
            String diffLabel = 'Belum dihitung';
            if (actualCashCtrl.text.isNotEmpty) {
              if (diff == 0) {
                diffColor = AppTheme.emeraldGreen;
                diffLabel = 'SESUAI (Uang laci pas)';
              } else if (diff < 0) {
                diffColor = AppTheme.dangerRed;
                diffLabel = 'SELISIH KURANG (${_currencyFormat.format(diff.abs())})';
              } else {
                diffColor = Colors.blue;
                diffLabel = 'SELISIH LEBIH (${_currencyFormat.format(diff)})';
              }
            }

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_clock_rounded, color: AppTheme.dangerRed, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tutup Shift & Rekonsiliasi Kas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 2),
                                const Text('Hitung uang fisik di laci kas sebelum shift diakhiri', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kas Seharusnya Ada
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282B38) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kas Sistem (Seharusnya Ada):', style: TextStyle(fontSize: 12.5)),
                            Text(
                              _currencyFormat.format(expectedCash),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.emeraldGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Input Uang Fisik Aktual
                      TextField(
                        controller: actualCashCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Uang Fisik Aktual di Laci Kas',
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          hintText: '0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Status Selisih
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: diffColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Hasil Rekonsiliasi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              diffLabel,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: diffColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Selesai
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: actualCashCtrl.text.trim().isEmpty
                                  ? null
                                  : () async {
                                      final closed = await shiftProvider.closeShift(actualCash: actual);
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Shift kasir berhasil ditutup dan direkonsiliasi! ✅'),
                                            backgroundColor: AppTheme.emeraldGreen,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );

                                        final summaryMsg = '*Laporan Tutup Shift Resto*\n'
                                            'Kasir: ${closed.cashierName}\n'
                                            'Modal Awal: ${_currencyFormat.format(closed.initialCash)}\n'
                                            'Penjualan Tunai: ${_currencyFormat.format(closed.totalCashSales)}\n'
                                            'Penjualan QRIS: ${_currencyFormat.format(closed.totalQrisSales)}\n'
                                            'Kasbon Masuk: ${_currencyFormat.format(closed.totalDebtRepaidCash)}\n'
                                            'Kas Keluar: ${_currencyFormat.format(closed.totalCashOut)}\n'
                                            'Kas Seharusnya: ${_currencyFormat.format(closed.expectedCash)}\n'
                                            'Kas Fisik: ${_currencyFormat.format(closed.actualCash)}\n'
                                            'Selisih: ${_currencyFormat.format(closed.difference)}';

                                        if (settings.phoneWA.isNotEmpty) {
                                          WhatsappService.openWhatsApp(
                                            phone: settings.phoneWA,
                                            message: summaryMsg,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAmber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Selesaikan & Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPaymentDialog(
    BuildContext context,
    PosProvider pos,
    ShiftProvider shift,
    dynamic settings,
  ) {
    if (!shift.hasActiveShift) {
      _promptStartShift(context);
      return;
    }

    final auth = context.read<AuthProvider>();
    final debtProvider = context.read<CustomerDebtProvider>();

    final serviceCharge = pos.calculateServiceCharge(settings);
    final taxAmount = pos.calculateTax(settings, null, serviceCharge);
    final grandTotal = pos.calculateCartGrandTotal(settings);
    final initialPaid = pos.activeEditingTab?.paidAmount ?? 0;
    final payableAmount = (grandTotal - initialPaid).clamp(0, 999999999);

    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        totalAmount: initialPaid > 0 ? payableAmount : grandTotal,
        initialCustomerName: pos.customerName,
        onPaymentCompleted: ({
          required String paymentMethod,
          required int amountPaid,
          required int change,
          String? customerId,
          String? customerName,
        }) async {
          final tableToNotify = pos.selectedTableNo ?? pos.activeEditingTab?.tableNo;
          final onlineIdToNotify = pos.activeEditingTab?.onlineOrderId;

          final currentOrder = OrderModel(
            id: 'ord_temp',
            shiftId: shift.activeShift!.id,
            tableNo: pos.selectedTableNo,
            customerName: customerName ?? pos.customerName,
            items: List.from(pos.cartItems),
            discountAmount: pos.cartDiscountAmount,
            discountPercent: pos.cartDiscountPercent,
            serviceChargeAmount: serviceCharge,
            taxAmount: taxAmount,
            paidAmount: grandTotal,
            onlineOrderId: onlineIdToNotify,
          );

          // 1. Catat transaksi di POS
          final trx = await pos.completeCheckout(
            shiftId: shift.activeShift!.id,
            cashierId: auth.currentUser?.id ?? 'cashier_unknown',
            cashierName: auth.currentUser?.name ?? 'Kasir',
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
            change: change,
            discountAmount: pos.cartDiscountAmount,
            discountPercent: pos.cartDiscountPercent,
            serviceChargeAmount: serviceCharge,
            taxAmount: taxAmount,
            customerId: customerId,
            customerName: customerName,
          );

          // 2. SINKRONISASI STATUS PELUNASAN KE CLOUD FIRESTORE
          // Mengabari HP tamu meja secara realtime bahwa pesanan telah lunas
          if (tableToNotify != null && context.mounted) {
            try {
              final onlineProvider = context.read<OnlineOrderProvider>();
              await onlineProvider.markTableOrderPaid(
                tableNo: tableToNotify,
                orderId: onlineIdToNotify ?? '',
                paymentMethod: paymentMethod,
              );
            } catch (e) {
              debugPrint('Gagal sinkron pelunasan ke cloud: $e');
            }
          }

          // 3. Perbarui catatan shift (mencegah double-counting jika sudah ada DP / pembayaran ronde 1)
          final recordedAmount = initialPaid > 0 ? payableAmount : trx.totalAmount;
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

          // 4. Cetak Otomatis Struk jika diaktifkan di Pengaturan Toko
          if (settings.autoPrintReceipt) {
            try {
              PrinterReceiptService.printReceiptDirect(
                settings: settings,
                order: currentOrder,
                receiptNo: trx.id.replaceAll('trx_', ''),
                orderTime: DateTime.now(),
                cashierName: trx.cashierName,
                paymentMethod: paymentMethod,
                amountPaid: amountPaid,
                change: change,
              );
            } catch (e) {
              debugPrint('Gagal cetak otomatis struk: $e');
            }
          }

          // 5. Tampilkan dialog kirim nota via WhatsApp & Cetak Struk Thermal Fisik
          if (context.mounted) {
            final receiptMsg = WhatsappService.generateReceiptMessage(
              storeName: settings.storeName,
              storeAddress: settings.address,
              receiptNo: trx.id.replaceAll('trx_', ''),
              order: currentOrder,
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
                    ? debtProvider.customers.firstWhere((c) => c.id == customerId).phoneWA
                    : '',
                receiptMessage: receiptMsg,
                settings: settings,
                order: currentOrder,
                receiptNo: trx.id.replaceAll('trx_', ''),
                cashierName: trx.cashierName,
                paymentMethod: paymentMethod,
                amountPaid: amountPaid,
                change: change,
                orderTime: DateTime.now(),
                onPrintThermal: () {
                  PrinterReceiptService.printReceiptDirect(
                    settings: settings,
                    order: currentOrder,
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
}

/// Widget Garis Putus-putus Struk Thermal (Dashed Divider)
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1.0,
    this.color = const Color(0xFF6B7280),
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        if (!boxWidth.isFinite || boxWidth <= 0) {
          return Divider(height: height, color: color);
        }
        final count = (boxWidth / (dashWidth + dashSpace)).floor();
        return SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// CustomPainter untuk menghasilkan efek gerigi sobekan kertas struk (Sawtooth Paper Tear)
class SawtoothPainter extends CustomPainter {
  final Color color;
  final double triangleWidth;
  final double triangleHeight;

  SawtoothPainter({
    required this.color,
    this.triangleWidth = 10,
    this.triangleHeight = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    double x = 0;
    while (x < size.width) {
      path.lineTo(x + triangleWidth / 2, triangleHeight);
      path.lineTo(x + triangleWidth, 0);
      x += triangleWidth;
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

