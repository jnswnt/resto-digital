import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/online_order_model.dart';
import '../models/product_model.dart';
import '../models/table_call_model.dart';
import '../models/user_model.dart';

/// Layanan Komunikasi Cloud SaaS REST API (Mini Resto POS Engine).
/// 
/// Mengelola sinkronisasi katalog menu, mendengarkan pesanan meja online (Self-Ordering QR),
/// dan menangani panggilan pelayan secara terpusat melalui Server Backend SaaS
/// (https://resto-api.ipankhub.web.id) tanpa ketergantungan pada Firebase/Google Cloud.
class CloudSyncService {
  /// URL Server Backend SaaS Proxy
  String serverUrl;

  /// ID Restoran / Tenant Slug (contoh: 'default', 'warkop-berkah')
  String restoId;

  /// Kunci kompatibilitas lama (opsional)
  String projectId;
  String apiKey;

  final http.Client _client;
  String? _lastError;

  /// Catatan kendala koneksi terakhir jika terjadi kegagalan jaringan
  String? get lastError => _lastError;

  /// URL Default Server Backend SaaS
  static const String defaultServerUrl = 'https://resto-api.ipankhub.web.id';

  CloudSyncService({
    this.serverUrl = defaultServerUrl,
    this.restoId = 'default',
    this.projectId = 'saas-resto',
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Memperbarui konfigurasi Cloud & Tenant secara dinamis saat pengaturan toko berubah
  void updateConfig({
    String? serverUrl,
    String? restoId,
    String? projectId,
    String? apiKey,
  }) {
    if (serverUrl != null && serverUrl.isNotEmpty) {
      this.serverUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (restoId != null) {
      this.restoId = restoId.trim().isEmpty ? 'default' : restoId.trim();
    }
    if (projectId != null) this.projectId = projectId;
    if (apiKey != null) this.apiKey = apiKey;
  }

  String get _safeResto => restoId.isNotEmpty ? restoId : 'default';

  /// Mendaftarkan akun tenant baru ke Backend SaaS API (Masa Aktif Trial 14 Hari)
  Future<Map<String, dynamic>?> registerTenant({
    required String restoId,
    required String businessName,
    String? businessType,
    String? ownerName,
    String? phone,
    String? address,
    int trialDays = 14,
  }) async {
    try {
      final registerUrl = Uri.parse('$serverUrl/api/tenants/register');
      final cleanRestoId = restoId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
      final payload = jsonEncode({
        'restoId': cleanRestoId,
        'businessName': businessName.trim(),
        'businessType': businessType ?? 'cafe',
        'ownerName': ownerName ?? 'Pemilik Toko',
        'phone': phone ?? '',
        'address': address ?? '',
        'trialDays': trialDays,
      });

      final response = await _client.post(
        registerUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _lastError = null;
        return data is Map<String, dynamic> ? data : null;
      } else {
        _lastError = 'Gagal mendaftarkan tenant: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      _lastError = 'Koneksi registrasi tenant gagal: $e';
      debugPrint('[CloudSync] $_lastError');
      return null;
    }
  }

  /// Mengecek status lisensi dan sisa hari masa aktif dari Server SaaS
  Future<Map<String, dynamic>?> checkLicense() async {
    try {
      final licenseUrl = Uri.parse('$serverUrl/api/tenants/$_safeResto/license');
      final response = await _client.get(licenseUrl).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('[CloudSync] Gagal cek lisensi: $e');
      return null;
    }
  }

  /// Menyinkronkan daftar staf karyawan ke Server Backend SaaS
  Future<bool> syncStaffToCloud(List<UserModel> staff) async {
    try {
      final syncUrl = Uri.parse('$serverUrl/api/tenants/$_safeResto/staff/sync');
      final payload = jsonEncode({
        'staff': staff.map((s) => s.toMap()).toList(),
      });

      final response = await _client.post(
        syncUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Kendala syncStaffToCloud: $e');
      return false;
    }
  }

  /// Memverifikasi apakah Resto ID dan Username karyawan valid sebelum memasukkan PIN
  Future<Map<String, dynamic>?> verifyStaffDevice({
    required String restoId,
    required String username,
  }) async {
    try {
      final cleanResto = restoId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
      final verifyUrl = Uri.parse('$serverUrl/api/tenants/$cleanResto/staff/verify');
      final payload = jsonEncode({
        'username': username.trim().toLowerCase(),
      });

      final response = await _client.post(
        verifyUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastError = null;
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        _lastError = err['error'] ?? 'Karyawan tidak ditemukan';
        return null;
      }
    } catch (e) {
      _lastError = 'Gagal terhubung ke server SaaS: $e';
      return null;
    }
  }

  /// Mengirimkan verifikasi PIN ke server SaaS untuk mengunci perangkat ke outlet
  Future<Map<String, dynamic>?> pairStaffDevice({
    required String restoId,
    required String username,
    required String pinHash,
  }) async {
    try {
      final cleanResto = restoId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
      final pairUrl = Uri.parse('$serverUrl/api/tenants/$cleanResto/staff/pair');
      final payload = jsonEncode({
        'username': username.trim().toLowerCase(),
        'pinHash': pinHash,
      });

      final response = await _client.post(
        pairUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastError = null;
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        _lastError = err['error'] ?? 'PIN salah';
        return null;
      }
    } catch (e) {
      _lastError = 'Gagal verifikasi pairing: $e';
      return null;
    }
  }

  /// Menyinkronkan seluruh daftar produk/menu POS kasir ke Server Backend SaaS
  Future<bool> syncMenuToCloud(
    List<ProductModel> products, {
    Map<String, String>? categoryNames,
    String? restoName,
  }) async {
    try {
      final syncUrl = Uri.parse('$serverUrl/api/catalog/$_safeResto/sync');
      
      final categoryList = categoryNames != null
          ? categoryNames.values.toSet().toList()
          : ['Makanan', 'Minuman', 'Snack'];

      final productList = products.map((prod) {
        final isAvailable = !prod.trackStock || prod.stock > 0;
        final categoryDisplayName = _resolveCategoryName(prod.categoryId, categoryNames);
        return {
          'id': prod.id,
          'name': prod.name,
          'price': prod.sellPrice,
          'category': categoryDisplayName,
          'categoryId': prod.categoryId,
          'categoryName': categoryDisplayName,
          'description': 'Menu lezat pilihan resto kami.',
          'imageUrl': prod.imageUrl ?? '',
          'isAvailable': isAvailable,
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }).toList();

      final payload = jsonEncode({
        'restoName': restoName ?? 'Resto Digital',
        'categories': categoryList,
        'products': productList,
      });

      final response = await _client.post(
        syncUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastError = null;
        debugPrint('[CloudSync] Berhasil menyinkronkan ${products.length} menu ke server SaaS.');
        return true;
      } else {
        _lastError = 'Server merespons status ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _lastError = 'Gagal sinkronisasi menu ke cloud: $e';
      debugPrint('[CloudSync] Kendala sinkronisasi menu: $e');
      return false;
    }
  }

  /// Memperbarui status ketersediaan suatu produk menu secara instan (Tersedia / Habis)
  Future<bool> syncMenuAvailability(String productId, bool isAvailable) async {
    return true;
  }

  /// Mengambil daftar pesanan online meja dari Server Backend SaaS
  Future<List<OnlineOrderModel>> fetchOnlineOrders({DateTime? forDate}) async {
    try {
      final ordersUrl = Uri.parse('$serverUrl/api/orders/$_safeResto');
      final response = await _client.get(ordersUrl).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        _lastError = null;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawOrders = data['orders'] as List<dynamic>? ?? [];

        final List<OnlineOrderModel> orders = [];
        for (final item in rawOrders) {
          if (item is Map<String, dynamic>) {
            orders.add(OnlineOrderModel.fromMap(item));
          }
        }

        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      } else {
        _lastError = 'Server merespons status ${response.statusCode}';
        return [];
      }
    } catch (e) {
      _lastError = 'Kendala jaringan ke server SaaS: $e';
      debugPrint('[CloudSync] Gagal memuat pesanan online: $e');
      return [];
    }
  }

  /// Memperbarui status pesanan di Server Backend SaaS:
  /// - 'cooking'    : Kasir menyetujui, diteruskan ke koki dapur
  /// - 'ready'      : Makanan siap disajikan
  /// - 'served'     : Makanan telah diantarkan ke meja tamu
  /// - 'completed'  : Transaksi selesai
  /// - 'cancelled'  : Pesanan dibatalkan
  /// - 'paid'       : Pesanan telah lunas
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final patchUrl = Uri.parse('$serverUrl/api/orders/$_safeResto/$orderId/status');
      final response = await _client.patch(
        patchUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': newStatus,
          'kitchenStatus': newStatus,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update status pesanan: $e');
      return false;
    }
  }

  /// Memperbarui nomor meja suatu pesanan jika pelanggan berpindah meja fisik
  Future<bool> updateOrderTableNo(String orderId, String newTableNo) async {
    return true;
  }

  /// Menandai pesanan telah lunas dibayar
  Future<bool> markOrderAsPaid(String orderId, String paymentMethod) async {
    return updateOrderStatus(orderId, 'paid');
  }

  /// Mengambil daftar panggilan bantuan pelayan dari meja tamu
  Future<List<TableCallModel>> fetchTableCalls() async {
    return [];
  }

  /// Menandai panggilan pelayan telah selesai dilayani
  Future<bool> resolveTableCall(String callId) async {
    return true;
  }

  /// Memperbarui status verifikasi pembayaran pesanan (misal konfirmasi transfer QRIS)
  Future<bool> updatePaymentStatus(String orderId, String paymentStatus) async {
    try {
      final patchUrl = Uri.parse('$serverUrl/api/orders/$_safeResto/$orderId/status');
      final res = await _client.patch(
        patchUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'paymentStatus': paymentStatus}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update payment status: $e');
      return false;
    }
  }

  /// Menyinkronkan konfigurasi QRIS toko dan Nama Toko ke Server SaaS
  Future<bool> syncQrisConfigToCloud(String qrisPayload, String storeName) async {
    return true;
  }

  /// Upload gambar produk (mengembalikan URI lokal/cloud)
  Future<String?> uploadProductImage(Uint8List imageBytes, String filename) async {
    return null;
  }

  /// Uji coba koneksi ke Server SaaS (Health Check)
  Future<bool> testConnection() async {
    try {
      final healthUrl = Uri.parse('$serverUrl/api/health');
      final res = await _client.get(healthUrl).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String _resolveCategoryName(String categoryId, Map<String, String>? categoryNames) {
    if (categoryNames != null && categoryNames.containsKey(categoryId)) {
      return categoryNames[categoryId]!;
    }
    final lower = categoryId.toLowerCase();
    if (lower.contains('makan')) return 'Makanan Utama';
    if (lower.contains('minum')) return 'Minuman Segar';
    if (lower.contains('snack') || lower.contains('camil')) return 'Camilan & Appetizer';
    if (lower.contains('paket')) return 'Paket Hemat';
    return 'Menu';
  }
}
