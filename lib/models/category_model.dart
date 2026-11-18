/// Model data Kategori Produk (Minuman, Makanan, Rokok, Camilan)
class CategoryModel {
  final String id;
  final String name;
  final int sortOrder;
  final String iconName;

  CategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.iconName = 'coffee',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sortOrder': sortOrder,
      'iconName': iconName,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sortOrder: map['sortOrder'] ?? 0,
      iconName: map['iconName'] ?? 'coffee',
    );
  }
}
