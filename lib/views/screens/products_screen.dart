import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/pos_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_image_view.dart';

/// Layar Katalog & Manajemen Menu Produk Resto.
/// Layar mandiri yang dapat diakses langsung dari sidebar/drawer untuk
/// menambah menu baru, mengubah harga jual/modal, dan mengelola stok.
class ProductsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenMenuDrawer;

  const ProductsScreen({
    super.key,
    this.embedded = false,
    this.onOpenMenuDrawer,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _selectedCategory = 'all';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    // Filter produk berdasarkan kategori dan query pencarian lokal
    final allProducts = pos.filteredProducts.where((p) {
      final matchCat = _selectedCategory == 'all' || p.categoryId == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    Widget bodyContent = Column(
      children: [
        // 1. Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search Input
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222430) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari menu resto...',
                    hintStyle: TextStyle(fontSize: 13, color: textMuted),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(height: 10),

              // Category Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('all', 'Semua Menu', isDark, pos),
                    ...pos.categories.map((cat) => _buildCategoryPill(cat.id, cat.name, isDark, pos)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Daftar Menu Produk (ListView Bebas Overflow)
        Expanded(
          child: allProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 56, color: textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada menu ditemukan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Silakan ubah kata kunci atau tambah menu baru',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: allProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final product = allProducts[i];
                    return _buildProductCard(context, product, currencyFormat, isDark, textColor, textMuted, borderColor);
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, allProducts.length, isDark, textColor, textMuted, borderColor),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Menu Resto')),
      body: bodyContent,
    );
  }

  // Header yang Responsif & Anti-Overflow
  Widget _buildEmbeddedHeader(
    BuildContext context,
    int totalCount,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Katalog Menu Resto',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isCompact ? '$totalCount menu terdaftar' : 'Kelola $totalCount menu, harga jual, modal, dan stok',
                      style: TextStyle(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Tambah Menu
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const ProductFormDialog(),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isCompact ? 'Tambah' : 'Tambah Menu Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 16,
                    vertical: isCompact ? 8 : 10,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill(String catId, String name, bool isDark, PosProvider pos) {
    final isSelected = _selectedCategory == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = catId),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryAmber
                : (isDark ? const Color(0xFF242735) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  // Kartu Produk 2-Baris Vertikal (Bebas Overflow di Smartphone Apapun)
  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    NumberFormat currencyFormat,
    bool isDark,
    Color textColor,
    Color textMuted,
    Color borderColor,
  ) {
    final margin = product.sellPrice - product.buyPrice;
    final isLowStock = product.trackStock && product.stock <= 10;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Foto/Ikon Menu + Nama Menu + Aksi Edit
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImageView(
                  imageUrl: product.imageUrl,
                  width: 38,
                  height: 38,
                  fallbackIcon: _getCategoryIconData(product.categoryId),
                  fallbackIconSize: 20,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tombol Edit
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ProductFormDialog(productToEdit: product),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 18, color: textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Divider Tipis
          Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // Baris 2: Harga Jual + Modal/Margin + Badge Stok
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Info Harga
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jual: ${currencyFormat.format(product.sellPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldGreen,
                      fontSize: 13,
                    ),
                  ),
                  if (product.buyPrice > 0)
                    Text(
                      'Modal: ${currencyFormat.format(product.buyPrice)} (Laba: +${currencyFormat.format(margin)})',
                      style: TextStyle(fontSize: 10, color: textMuted),
                    ),
                ],
              ),

              // Badge Stok & Toggle Ketersediaan Web
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLowStock
                          ? AppTheme.dangerRed.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFD1FAE5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLowStock ? AppTheme.dangerRed.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      product.trackStock ? 'Stok: ${product.stock} ${product.unit}' : 'Tanpa Stok',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLowStock
                            ? AppTheme.dangerRed
                            : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Tombol Cepat Toggle Menu Habis di Web
                  Consumer<OnlineOrderProvider>(
                    builder: (context, onlineProvider, _) {
                      final isAvail = onlineProvider.isProductAvailable(
                        product.id,
                        fallback: !product.trackStock || product.stock > 0,
                      );
                      return InkWell(
                        onTap: () async {
                          final newStatus = !isAvail;
                          await onlineProvider.toggleProductAvailability(product.id, newStatus);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newStatus
                                      ? '${product.name} sekarang berstatus TERSEDIA di Web.'
                                      : '${product.name} ditandai HABIS di Web Pemesanan Tamu.',
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: newStatus ? AppTheme.emeraldGreen : AppTheme.dangerRed,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Tooltip(
                          message: isAvail
                              ? 'Status Web: Tersedia (Klik untuk ubah jadi Habis)'
                              : 'Status Web: Habis (Klik untuk sediakan kembali)',
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isAvail ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              size: 16,
                              color: isAvail
                                  ? (isDark ? const Color(0xFF34D399) : AppTheme.emeraldGreen)
                                  : AppTheme.dangerRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mendapatkan ikon relevan berdasarkan kategori produk
  IconData _getCategoryIconData(String categoryId) {
    if (categoryId == 'cat_makanan') {
      return Icons.restaurant_rounded;
    } else if (categoryId == 'cat_minuman') {
      return Icons.local_drink_rounded;
    } else if (categoryId == 'cat_camilan') {
      return Icons.fastfood_rounded;
    } else if (categoryId == 'cat_paket') {
      return Icons.lunch_dining_rounded;
    } else if (categoryId == 'cat_rokok') {
      return Icons.smoking_rooms_rounded;
    }
    return Icons.coffee_rounded;
  }
}
