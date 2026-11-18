import '../models/category_model.dart';
import '../models/product_model.dart';

/// Jenis template data awal katalog saat registrasi tenant baru
enum TemplateBusinessType {
  coffeeShop,
  restaurant,
  blank,
}

/// Layanan penyedia template katalog menu untuk proses Onboarding Tenant Baru
class OnboardingTemplateService {
  /// Mendapatkan daftar kategori berdasarkan tipe usaha
  static List<CategoryModel> getCategories(TemplateBusinessType type) {
    switch (type) {
      case TemplateBusinessType.coffeeShop:
        return [
          CategoryModel(id: 'cat_coffee', name: 'Kopi & Espresso', sortOrder: 1, iconName: 'local_cafe'),
          CategoryModel(id: 'cat_noncoffee', name: 'Minuman Non-Kopi', sortOrder: 2, iconName: 'local_drink'),
          CategoryModel(id: 'cat_pastry', name: 'Pastry & Camilan', sortOrder: 3, iconName: 'bakery_dining'),
          CategoryModel(id: 'cat_toast', name: 'Toast & Makanan Ringan', sortOrder: 4, iconName: 'lunch_dining'),
        ];
      case TemplateBusinessType.restaurant:
        return [
          CategoryModel(id: 'cat_makanan', name: 'Makanan Utama', sortOrder: 1, iconName: 'restaurant'),
          CategoryModel(id: 'cat_paket', name: 'Paket Hemat', sortOrder: 2, iconName: 'lunch_dining'),
          CategoryModel(id: 'cat_minuman', name: 'Minuman Segar', sortOrder: 3, iconName: 'local_drink'),
          CategoryModel(id: 'cat_camilan', name: 'Camilan & Appetizer', sortOrder: 4, iconName: 'fastfood'),
        ];
      case TemplateBusinessType.blank:
        return [];
    }
  }

  /// Mendapatkan daftar produk menu berdasarkan tipe usaha
  static List<ProductModel> getProducts(TemplateBusinessType type) {
    switch (type) {
      case TemplateBusinessType.coffeeShop:
        return [
          ProductModel(
            id: 'coffee_1',
            name: 'Kopi Susu Gula Aren',
            categoryId: 'cat_coffee',
            buyPrice: 8000,
            sellPrice: 18000,
            stock: 100,
            unit: 'Cup',
            imageUrl: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'coffee_2',
            name: 'Americano Dingin (Iced)',
            categoryId: 'cat_coffee',
            buyPrice: 5000,
            sellPrice: 16000,
            stock: 100,
            unit: 'Cup',
            imageUrl: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'coffee_3',
            name: 'Caffe Latte Art',
            categoryId: 'cat_coffee',
            buyPrice: 9000,
            sellPrice: 22000,
            stock: 80,
            unit: 'Cup',
            imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'noncoffee_1',
            name: 'Matcha Green Tea Latte',
            categoryId: 'cat_noncoffee',
            buyPrice: 10000,
            sellPrice: 24000,
            stock: 60,
            unit: 'Cup',
            imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'noncoffee_2',
            name: 'Signature Dark Chocolate',
            categoryId: 'cat_noncoffee',
            buyPrice: 9000,
            sellPrice: 22000,
            stock: 70,
            unit: 'Cup',
            imageUrl: 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'pastry_1',
            name: 'Butter Croissant Crispy',
            categoryId: 'cat_pastry',
            buyPrice: 9000,
            sellPrice: 18000,
            stock: 30,
            unit: 'Pcs',
            imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'toast_1',
            name: 'Roti Toast Coklat Keju',
            categoryId: 'cat_toast',
            buyPrice: 8000,
            sellPrice: 20000,
            stock: 40,
            unit: 'Porsi',
            imageUrl: 'https://images.unsplash.com/photo-1584776296944-ab6fb57b0bdd?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'toast_2',
            name: 'French Fries Seasoned',
            categoryId: 'cat_toast',
            buyPrice: 6000,
            sellPrice: 15000,
            stock: 50,
            unit: 'Porsi',
            imageUrl: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=500&auto=format&fit=crop&q=80',
          ),
        ];

      case TemplateBusinessType.restaurant:
        return [
          ProductModel(
            id: 'resto_1',
            name: 'Nasi Goreng Spesial Resto',
            categoryId: 'cat_makanan',
            buyPrice: 12000,
            sellPrice: 22000,
            stock: 50,
            unit: 'Porsi',
            imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'resto_2',
            name: 'Ayam Bakar Madu + Nasi',
            categoryId: 'cat_makanan',
            buyPrice: 15000,
            sellPrice: 28000,
            stock: 40,
            unit: 'Porsi',
            imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'resto_3',
            name: 'Mie Goreng Seafood Spesial',
            categoryId: 'cat_makanan',
            buyPrice: 14000,
            sellPrice: 25000,
            stock: 35,
            unit: 'Porsi',
            imageUrl: 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'resto_4',
            name: 'Soto Ayam Lamongan',
            categoryId: 'cat_makanan',
            buyPrice: 10000,
            sellPrice: 20000,
            stock: 30,
            unit: 'Mangkuk',
            imageUrl: 'https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'resto_5',
            name: 'Es Teh Manis Jumbo',
            categoryId: 'cat_minuman',
            buyPrice: 1500,
            sellPrice: 5000,
            stock: 200,
            unit: 'Gelas',
            imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop&q=80',
          ),
          ProductModel(
            id: 'resto_6',
            name: 'Jus Alpukat Kocok',
            categoryId: 'cat_minuman',
            buyPrice: 7000,
            sellPrice: 15000,
            stock: 30,
            unit: 'Gelas',
            imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&auto=format&fit=crop&q=80',
          ),
        ];

      case TemplateBusinessType.blank:
        return [];
    }
  }
}
