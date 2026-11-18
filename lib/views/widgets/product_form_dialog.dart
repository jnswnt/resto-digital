import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/product_model.dart';
import '../../providers/pos_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/file_helper.dart';
import '../../theme/app_theme.dart';
import 'product_image_view.dart';

/// Dialog Form Tambah dan Edit Menu Produk Resto.
/// Mendukung pengaturan nama, harga, kategori, stok, serta foto menu
/// baik melalui tautan URL web maupun unggah foto dari galeri HP owner.
class ProductFormDialog extends StatefulWidget {
  final ProductModel? productToEdit;

  const ProductFormDialog({super.key, this.productToEdit});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _buyPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _imageUrlCtrl;

  late String _selectedCategoryId;
  late String _selectedUnit;
  late bool _trackStock;

  // Status Sumber Foto (Tautan URL vs Galeri)
  bool _isGalleryMode = false;
  XFile? _pickedImageFile;
  String? _localImagePath;
  bool _isSaving = false;

  final List<String> _units = ['Gelas', 'Porsi', 'Pcs', 'Bungkus', 'Batang', 'Botol'];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _sellPriceCtrl = TextEditingController(text: p != null ? '${p.sellPrice}' : '');
    _buyPriceCtrl = TextEditingController(text: p != null ? '${p.buyPrice}' : '');
    _stockCtrl = TextEditingController(text: p != null ? '${p.stock}' : '100');
    _imageUrlCtrl = TextEditingController(text: p?.imageUrl ?? '');

    // Deteksi otomatis apakah foto saat ini berupa berkas lokal atau URL web
    final initialUrl = p?.imageUrl ?? '';
    final isHttp = initialUrl.startsWith('http://') || initialUrl.startsWith('https://');
    if (initialUrl.isNotEmpty && !isHttp) {
      _isGalleryMode = true;
      _localImagePath = initialUrl;
    } else {
      _isGalleryMode = false;
    }

    final pos = context.read<PosProvider>();
    final validCatIds = pos.categories.map((c) => c.id).toList();

    _selectedCategoryId = (p != null && validCatIds.contains(p.categoryId))
        ? p.categoryId
        : (validCatIds.isNotEmpty ? validCatIds.first : 'cat_minuman');

    _selectedUnit = (p != null && _units.contains(p.unit)) ? p.unit : 'Gelas';
    _trackStock = p?.trackStock ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sellPriceCtrl.dispose();
    _buyPriceCtrl.dispose();
    _stockCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  /// Memilih foto produk langsung dari galeri perangkat owner
  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImageFile = picked;
          _localImagePath = picked.path;
          _imageUrlCtrl.text = picked.path;
        });
      }
    } catch (e) {
      debugPrint('[ProductForm] Gagal membuka galeri: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka galeri perangkat: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final pos = context.read<PosProvider>();
      final name = _nameCtrl.text.trim();
      final sellPrice = int.tryParse(_sellPriceCtrl.text.trim()) ?? 0;
      final buyPrice = int.tryParse(_buyPriceCtrl.text.trim()) ?? 0;
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

      String? finalImageUrl;

      if (_isGalleryMode) {
        if (_pickedImageFile != null) {
          // 1. Kompresi gambar agar ringan dan hemat bandwidth saat di Web Tamu
          final bytes = await _pickedImageFile!.readAsBytes();
          var decoded = img.decodeImage(bytes);
          Uint8List compressedBytes = bytes;
          if (decoded != null) {
            if (decoded.width > 800 || decoded.height > 800) {
              decoded = img.copyResize(decoded, width: 800);
            }
            compressedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
          }

          final targetId = widget.productToEdit?.id ?? 'p_${_uuid.v4().substring(0, 8)}';

          // 2. Simpan salinan lokal gambar via file helper lintas platform (Web / Native)
          final localSavedPath = await savePlatformLocalImage(
            compressedBytes,
            '$targetId.jpg',
          );
          if (localSavedPath != null && localSavedPath.isNotEmpty) {
            finalImageUrl = localSavedPath;
          }

          // 3. Unggah ke Firebase Cloud Storage REST API agar Web Tamu (web_order) dapat menampilkannya
          try {
            final cloudSync = CloudSyncService();
            final cloudUrl = await cloudSync.uploadProductImage(
              compressedBytes,
              '$targetId.jpg',
            );
            if (cloudUrl != null && cloudUrl.isNotEmpty) {
              finalImageUrl = cloudUrl;
            }
          } catch (e) {
            debugPrint('[ProductForm] Unggah cloud tertunda: $e');
          }
        } else if (_localImagePath != null && _localImagePath!.isNotEmpty) {
          finalImageUrl = _localImagePath;
        }
      } else {
        final textUrl = _imageUrlCtrl.text.trim();
        finalImageUrl = textUrl.isNotEmpty ? textUrl : null;
      }

      if (widget.productToEdit != null) {
        // Mode Edit Produk
        final updated = widget.productToEdit!.copyWith(
          name: name,
          categoryId: _selectedCategoryId,
          sellPrice: sellPrice,
          buyPrice: buyPrice,
          stock: stock,
          unit: _selectedUnit,
          trackStock: _trackStock,
          imageUrl: finalImageUrl,
        );
        await pos.updateProduct(updated);
      } else {
        // Mode Tambah Produk Baru
        final newProduct = ProductModel(
          id: 'p_${_uuid.v4().substring(0, 8)}',
          name: name,
          categoryId: _selectedCategoryId,
          sellPrice: sellPrice,
          buyPrice: buyPrice,
          stock: stock,
          unit: _selectedUnit,
          trackStock: _trackStock,
          imageUrl: finalImageUrl,
        );
        await pos.addProduct(newProduct);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productToEdit != null
                ? 'Menu "$name" berhasil diperbarui'
                : 'Menu "$name" berhasil ditambahkan'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProductForm] Kendala saat menyimpan produk: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kendala saat menyimpan: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProduct() async {
    if (widget.productToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Menu?'),
        content: Text('Apakah Anda yakin ingin menghapus "${widget.productToEdit!.name}" dari katalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final pos = context.read<PosProvider>();
      await pos.deleteProduct(widget.productToEdit!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menu "${widget.productToEdit!.name}" telah dihapus'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final pos = context.watch<PosProvider>();
    final isEdit = widget.productToEdit != null;

    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E202B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 440;
          final contentPadding = isMobile ? 16.0 : 24.0;

          return Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: EdgeInsets.all(contentPadding),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Dialog
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppTheme.primaryAmber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Menu Resto' : 'Tambah Menu Resto Baru',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEdit)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.dangerRed,
                              size: 20,
                            ),
                            tooltip: 'Hapus Menu',
                            onPressed: _deleteProduct,
                          ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Nama Menu
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Menu / Minuman / Makanan *',
                        hintText: 'Contoh: Kopi Jahe Panas',
                        prefixIcon: Icon(Icons.fastfood_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nama menu wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    // 2. Kategori Menu (Baris Penuh agar Teks Bebas Overflow)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori Menu *',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: pos.categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // -------------------------------------------------------------
                    // Bagian Foto Menu (Tautan Link vs Upload Galeri)
                    // -------------------------------------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Foto Menu Produk',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (_isGalleryMode && (_pickedImageFile != null || (_localImagePath != null && _localImagePath!.isNotEmpty)))
                          Text(
                            'Galeri Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Toggle Pilihan Mode: Link Web vs Unggah dari Galeri
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isGalleryMode = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isGalleryMode
                                      ? (isDark ? const Color(0xFF2E3245) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isGalleryMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.link_rounded,
                                      size: 16,
                                      color: !_isGalleryMode ? AppTheme.primaryAmber : textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tautan Link URL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !_isGalleryMode ? FontWeight.bold : FontWeight.w500,
                                        color: !_isGalleryMode ? textColor : textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isGalleryMode = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isGalleryMode
                                      ? (isDark ? const Color(0xFF2E3245) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isGalleryMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 16,
                                      color: _isGalleryMode ? AppTheme.primaryAmber : textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pilih dari Galeri',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _isGalleryMode ? FontWeight.bold : FontWeight.w500,
                                        color: _isGalleryMode ? textColor : textMuted,
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
                    const SizedBox(height: 10),

                    // Konten Input sesuai Mode yang Dipilih
                    if (!_isGalleryMode) ...[
                      // Mode 1: Tautan Link URL
                      TextFormField(
                        controller: _imageUrlCtrl,
                        decoration: InputDecoration(
                          labelText: 'URL Foto Menu (Opsional)',
                          hintText: 'https://images.unsplash.com/...',
                          prefixIcon: const Icon(Icons.image_outlined),
                          suffixIcon: _imageUrlCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _imageUrlCtrl.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ProductImageView(
                              imageUrl: _imageUrlCtrl.text.trim(),
                              width: 52,
                              height: 52,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Pratinjau foto dari internet. Foto akan otomatis muncul di POS dan Web Meja.',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      // Mode 2: Unggah dari Galeri HP / Komputer
                      if (_pickedImageFile != null || (_localImagePath != null && _localImagePath!.isNotEmpty)) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardSurface : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              ProductImageView(
                                imageUrl: _pickedImageFile?.path ?? _localImagePath,
                                width: 56,
                                height: 56,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedImageFile != null
                                          ? 'Foto Galeri Dipilih'
                                          : 'Foto Tersimpan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Akan dikompresi otomatis & disinkronkan ke Web Meja.',
                                      style: TextStyle(fontSize: 11, color: textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryAmber),
                                tooltip: 'Ganti Foto',
                                onPressed: _pickImageFromGallery,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                                tooltip: 'Hapus Foto',
                                onPressed: () {
                                  setState(() {
                                    _pickedImageFile = null;
                                    _localImagePath = null;
                                    _imageUrlCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: _pickImageFromGallery,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCardSurface : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryAmber.withValues(alpha: 0.5),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 24,
                                    color: AppTheme.primaryAmber,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ketuk untuk Pilih Foto dari Galeri',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mendukung format JPG, PNG, WEBP',
                                  style: TextStyle(fontSize: 11, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),

                    // 3. Satuan & Stok Awal (Berdampingan Proporsional)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Satuan
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Satuan',
                              prefixIcon: Icon(Icons.straighten_rounded),
                            ),
                            items: _units.map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text(u, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedUnit = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Stok Awal
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            enabled: _trackStock,
                            decoration: InputDecoration(
                              labelText: 'Stok Awal',
                              hintText: '100',
                              prefixIcon: const Icon(Icons.inventory_2_outlined),
                              suffixText: _selectedUnit,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. Harga Jual & Harga Modal
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sellPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga Jual (Rp) *',
                              hintText: '5000',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              if (int.tryParse(v.trim()) == null) return 'Harus angka';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _buyPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga Modal (Rp)',
                              hintText: '3000',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 5. Card Toggle Pelacakan Stok
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242735) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        title: const Text(
                          'Lacak Stok Barang',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _trackStock
                              ? 'Stok berkurang otomatis saat menu terjual'
                              : 'Tanpa batasan stok fisik',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                        value: _trackStock,
                        activeThumbColor: AppTheme.primaryAmber,
                        activeTrackColor: AppTheme.primaryAmber.withValues(alpha: 0.5),
                        onChanged: (val) => setState(() => _trackStock = val),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Tombol Aksi Bawah (Responsif Anti-Overflow & Status Simpan)
                    if (isMobile) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProduct,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            _isSaving
                                ? 'Menyimpan Menu...'
                                : (isEdit ? 'Simpan Perubahan' : 'Tambah Menu Baru'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAmber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isEdit)
                            TextButton.icon(
                              onPressed: _isSaving ? null : _deleteProduct,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.dangerRed,
                                size: 18,
                              ),
                              label: const Text(
                                'Hapus Menu',
                                style: TextStyle(
                                  color: AppTheme.dangerRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const SizedBox(),
                          TextButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isEdit)
                            TextButton.icon(
                              onPressed: _isSaving ? null : _deleteProduct,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.dangerRed,
                                size: 18,
                              ),
                              label: const Text(
                                'Hapus Menu',
                                style: TextStyle(color: AppTheme.dangerRed),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProduct,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              _isSaving
                                  ? 'Menyimpan...'
                                  : (isEdit ? 'Simpan Perubahan' : 'Tambah Menu Baru'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
