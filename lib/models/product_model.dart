/// Model data Produk / Menu Resto.
/// Menyimpan harga beli, harga jual, kuantitas stok, satuan, serta foto menu (opsional).
class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final int buyPrice;
  final int sellPrice;
  final int stock;
  final bool trackStock;
  final String unit; // 'Gelas', 'Porsi', 'Bungkus', 'Batang', 'Pcs'
  final String? imageUrl; // URL foto menu makanan/minuman

  ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.buyPrice,
    required this.sellPrice,
    this.stock = 0,
    this.trackStock = true,
    this.unit = 'Pcs',
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'stock': stock,
      'trackStock': trackStock,
      'unit': unit,
      'imageUrl': imageUrl,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      categoryId: map['categoryId'] ?? '',
      buyPrice: (map['buyPrice'] as num?)?.toInt() ?? 0,
      sellPrice: (map['sellPrice'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      trackStock: map['trackStock'] is bool
          ? map['trackStock'] as bool
          : (map['trackStock'] == 1 || map['trackStock'] == null),
      unit: map['unit'] ?? 'Pcs',
      imageUrl: map['imageUrl'],
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    int? buyPrice,
    int? sellPrice,
    int? stock,
    bool? trackStock,
    String? unit,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      trackStock: trackStock ?? this.trackStock,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
