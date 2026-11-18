import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/online_order_model.dart';
import '../models/product_model.dart';
import '../models/table_call_model.dart';

/// Layanan Komunikasi Cloud Firestore REST API.
/// Mengelola sinkronisasi katalog menu resto ke Firebase Cloud,
/// mendengarkan pesanan online meja (Self-Ordering),
/// menangani panggilan bantuan pelayan dari meja (Call Waiter),
/// serta mengelola autentikasi Firebase ID Token untuk hak akses kasir.
class CloudSyncService {
  String projectId;
  String apiKey;
  String restoId;
  final http.Client _client;

  String? _idToken;
  DateTime? _tokenExpiry;
  String? _lastError;

  /// Catatan kendala koneksi terakhir jika terjadi gagal fetch (misal offline/DNS error)
  String? get lastError => _lastError;

  CloudSyncService({
    this.projectId = 'restodigital-pos',
    this.apiKey = 'AIzaSyBL9UgLYEtq32Upsp38Xa_C_Vt2Fgzwy6w',
    this.restoId = 'default',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Memperbarui konfigurasi Cloud & Tenant secara dinamis saat pemilik toko mengubah pengaturan
  void updateConfig({
    String? projectId,
    String? apiKey,
    String? restoId,
  }) {
    if (projectId != null && projectId.isNotEmpty && projectId != this.projectId) {
      this.projectId = projectId;
      _idToken = null; // Reset token auth jika project berubah
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      this.apiKey = apiKey;
    }
    if (restoId != null) {
      this.restoId = restoId.trim();
    }
  }

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Mendapatkan path koleksi terisolasi berdasarkan restoId (Multi-Tenant)
  String _getCollectionPath(String collectionName) {
    if (restoId.isNotEmpty && restoId != 'default') {
      return '$_baseUrl/restos/$restoId/$collectionName';
    }
    return '$_baseUrl/$collectionName';
  }

  /// Memastikan aplikasi Kasir memiliki Firebase Auth ID Token yang valid
  /// menggunakan Anonymous Sign-In via Google Identity Toolkit REST API.
  Future<void> _ensureAuthenticated() async {
    if (_idToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    try {
      final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
      );
      final response = await _client.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'returnSecureToken': true}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _idToken = data['idToken'] as String?;
        final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
        // Simpan batas waktu kedaluwarsa dengan margin 1 menit sebelum habis
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        debugPrint('[CloudSync] Kasir terautentikasi ke Firebase Auth (Token valid).');
      } else {
        debugPrint('[CloudSync] Auth respon ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[CloudSync] Gagal memperoleh Firebase ID Token: $e');
    }
  }

  /// Membuat header HTTP permintaan, menyertakan Bearer Token jika tersedia
  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_idToken != null && _idToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_idToken';
    }
    return headers;
  }

  /// Menyinkronkan seluruh daftar produk/menu POS kasir ke koleksi Firestore `resto_menu`.
  /// Menyertakan field `isAvailable` (ketersediaan stok) dan nama kategori yang ramah dibaca tamu resto.
  Future<bool> syncMenuToCloud(
    List<ProductModel> products, {
    Map<String, String>? categoryNames,
  }) async {
    try {
      await _ensureAuthenticated();
      debugPrint('[CloudSync] Memulai sinkronisasi ${products.length} menu ke Firestore...');

      for (final prod in products) {
        final isAvailable = !prod.trackStock || prod.stock > 0;
        final categoryDisplayName = _resolveCategoryName(prod.categoryId, categoryNames);
        final colPath = _getCollectionPath('resto_menu');
        final docUrl = Uri.parse('$colPath/${prod.id}?key=$apiKey');
        final body = jsonEncode({
          'fields': {
            'id': {'stringValue': prod.id},
            'name': {'stringValue': prod.name},
            'price': {'integerValue': prod.sellPrice.toString()},
            'category': {'stringValue': categoryDisplayName},
            'categoryId': {'stringValue': prod.categoryId},
            'categoryName': {'stringValue': categoryDisplayName},
            'description': {'stringValue': 'Menu lezat pilihan resto kami.'},
            'icon': {'stringValue': _getCategoryIcon(prod.categoryId)},
            'imageUrl': {'stringValue': prod.imageUrl ?? ''},
            'isAvailable': {'booleanValue': isAvailable},
            'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
          }
        });

        final response = await _client.patch(
          docUrl,
          headers: _getHeaders(),
          body: body,
        );

        if (response.statusCode != 200) {
          debugPrint('[CloudSync] Gagal upload item ${prod.name}: ${response.body}');
        }
      }

      debugPrint('[CloudSync] Sinkronisasi katalog menu selesai.');
      return true;
    } catch (e) {
      debugPrint('[CloudSync] Kendala sinkronisasi menu: $e');
      return false;
    }
  }

  /// Memperbarui status ketersediaan suatu produk menu secara instan (Tersedia / Habis)
  Future<bool> syncMenuAvailability(String productId, bool isAvailable) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('resto_menu');
      final url = Uri.parse(
        '$colPath/$productId?updateMask.fieldPaths=isAvailable&updateMask.fieldPaths=updatedAt&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'isAvailable': {'booleanValue': isAvailable},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update ketersediaan menu: $e');
      return false;
    }
  }

  /// Mengambil daftar pesanan online meja dari Firestore koleksi `table_orders`.
  /// Menggunakan query terfilter untuk mengambil hanya pesanan yang dibuat pada hari ini (today),
  /// mencegah transfer ribuan dokumen historis dan menghemat kuota Firestore.
  Future<List<OnlineOrderModel>> fetchOnlineOrders({DateTime? forDate}) async {
    try {
      final now = forDate ?? DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final queryIso = todayStart.toUtc().toIso8601String();

      // Gunakan query Firestore runQuery untuk memfilter pesanan yang dibuat pada hari ini
      final String runQueryUrlStr;
      if (restoId.isNotEmpty && restoId != 'default') {
        runQueryUrlStr = '$_baseUrl/restos/$restoId:runQuery?key=$apiKey';
      } else {
        runQueryUrlStr = '$_baseUrl:runQuery?key=$apiKey';
      }
      final runQueryUrl = Uri.parse(runQueryUrlStr);
      final queryBody = jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': 'table_orders'}
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'createdAt'},
              'op': 'GREATER_THAN_OR_EQUAL',
              'value': {'stringValue': queryIso},
            }
          },
          'orderBy': [
            {
              'field': {'fieldPath': 'createdAt'},
              'direction': 'DESCENDING',
            }
          ]
        }
      });

      final response = await _client.post(
        runQueryUrl,
        headers: _getHeaders(),
        body: queryBody,
      );

      if (response.statusCode == 200) {
        _lastError = null;
        final list = jsonDecode(response.body) as List<dynamic>? ?? [];
        final List<OnlineOrderModel> orders = [];

        for (final item in list) {
          final doc = item['document'] as Map<String, dynamic>?;
          if (doc != null) {
            final name = doc['name'] as String? ?? '';
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            final order = OnlineOrderModel.fromFirestoreRest(name, fields);
            if (!order.createdAt.isBefore(todayStart)) {
              orders.add(order);
            }
          }
        }

        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      } else {
        // Fallback jika query REST runQuery belum siap indeks atau respons error
        debugPrint('[CloudSync] runQuery HTTP ${response.statusCode}, fallback ke list terfilter');
        return _fetchOnlineOrdersFallback(todayStart);
      }
    } catch (e) {
      _lastError = 'Gagal memuat pesanan online: $e';
      debugPrint('[CloudSync] Gagal memuat pesanan online: $e');
      return [];
    }
  }

  /// Fallback mengambil pesanan online dengan filter hari ini di memori jika runQuery tidak tersedia
  Future<List<OnlineOrderModel>> _fetchOnlineOrdersFallback(DateTime todayStart) async {
    try {
      final colPath = _getCollectionPath('table_orders');
      final url = Uri.parse('$colPath?pageSize=100&key=$apiKey');
      final response = await _client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        _lastError = null;
        final data = jsonDecode(response.body);
        final documents = data['documents'] as List<dynamic>? ?? [];

        final List<OnlineOrderModel> orders = [];
        for (final doc in documents) {
          final name = doc['name'] as String? ?? '';
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final order = OnlineOrderModel.fromFirestoreRest(name, fields);
          if (!order.createdAt.isBefore(todayStart)) {
            orders.add(order);
          }
        }

        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      } else {
        _lastError = 'Server Cloud Firestore merespons status ${response.statusCode}';
        return [];
      }
    } catch (e) {
      _lastError = 'Gagal memuat pesanan online: $e';
      return [];
    }
  }

  /// Memperbarui status pesanan di Firestore:
  /// - 'processing' : Kasir menyetujui, pesanan diproses di dapur
  /// - 'completed'  : Makanan disajikan / transaksi selesai
  /// - 'rejected'   : Pesanan ditolak kasir
  /// - 'paid'       : Pesanan telah lunas dibayar
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('table_orders');
      final url = Uri.parse(
        '$colPath/$orderId?updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'status': {'stringValue': newStatus},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update status order: $e');
      return false;
    }
  }

  /// Memperbarui nomor meja pesanan di Firestore saat kasir melakukan Pindah Meja (Move Table)
  Future<bool> updateOrderTableNo(String orderId, String newTableNo) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('table_orders');
      final url = Uri.parse(
        '$colPath/$orderId?updateMask.fieldPaths=tableNo&updateMask.fieldPaths=updatedAt&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'tableNo': {'stringValue': newTableNo},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update tableNo order: $e');
      return false;
    }
  }

  /// Memperbarui status pelunasan transaksi pesanan meja ke Cloud Firestore.
  /// Memperbarui status menjadi 'paid', paymentStatus menjadi 'paid', serta mencatat paymentMethod.
  Future<bool> markOrderAsPaid(String orderId, String paymentMethod) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('table_orders');
      final url = Uri.parse(
        '$colPath/$orderId?updateMask.fieldPaths=status&updateMask.fieldPaths=paymentStatus&updateMask.fieldPaths=paymentMethod&updateMask.fieldPaths=updatedAt&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'status': {'stringValue': 'paid'},
          'paymentStatus': {'stringValue': 'paid'},
          'paymentMethod': {'stringValue': paymentMethod},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('[CloudSync] Berhasil tandai pesanan $orderId lunas (paid) via $paymentMethod');
        return true;
      } else {
        debugPrint('[CloudSync] Gagal markOrderAsPaid $orderId: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[CloudSync] Kendala markOrderAsPaid: $e');
      return false;
    }
  }

  /// Memperbarui status verifikasi pembayaran pesanan (misal konfirmasi transfer QRIS mandiri)
  Future<bool> updatePaymentStatus(String orderId, String paymentStatus) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('table_orders');
      final url = Uri.parse(
        '$colPath/$orderId?updateMask.fieldPaths=paymentStatus&updateMask.fieldPaths=updatedAt&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'paymentStatus': {'stringValue': paymentStatus},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal update paymentStatus: $e');
      return false;
    }
  }

  /// Mengambil panggilan bantuan pelayan aktif dari koleksi `table_calls`
  Future<List<TableCallModel>> fetchTableCalls() async {
    try {
      final colPath = _getCollectionPath('table_calls');
      final url = Uri.parse('$colPath?key=$apiKey');
      final response = await _client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = data['documents'] as List<dynamic>? ?? [];

        final List<TableCallModel> calls = [];
        for (final doc in documents) {
          final name = doc['name'] as String? ?? '';
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final call = TableCallModel.fromFirestoreRest(name, fields);
          if (call.isPending) {
            calls.add(call);
          }
        }

        calls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return calls;
      }
      return [];
    } catch (e) {
      _lastError = 'Gagal terhubung ke Cloud Firestore: $e';
      debugPrint('[CloudSync] Gagal fetch table calls: $e');
      return [];
    }
  }

  /// Menandai panggilan bantuan pelayan telah selesai dilayani
  Future<bool> resolveTableCall(String callId) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('table_calls');
      final url = Uri.parse(
        '$colPath/$callId?updateMask.fieldPaths=status&key=$apiKey',
      );

      final body = jsonEncode({
        'fields': {
          'status': {'stringValue': 'resolved'},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal resolve table call: $e');
      return false;
    }
  }

  /// Menyinkronkan konfigurasi QRIS toko dan Nama Toko ke `resto_config/settings`
  Future<bool> syncQrisConfigToCloud(String qrisPayload, String storeName) async {
    try {
      await _ensureAuthenticated();
      final colPath = _getCollectionPath('resto_config');
      final url = Uri.parse('$colPath/settings?key=$apiKey');
      final body = jsonEncode({
        'fields': {
          'qrisPayload': {'stringValue': qrisPayload},
          'storeName': {'stringValue': storeName},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      });

      final response = await _client.patch(
        url,
        headers: _getHeaders(),
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudSync] Gagal sync QRIS ke Cloud: $e');
      return false;
    }
  }

  String _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('makan') || lower.contains('food')) return '🍛';
    if (lower.contains('minum') || lower.contains('drink') || lower.contains('kopi') || lower.contains('teh')) return '🥤';
    if (lower.contains('snack') || lower.contains('camil') || lower.contains('goreng')) return '🍟';
    return '🍽️';
  }

  /// Mendapatkan nama kategori ramah manusia untuk antarmuka web pemesanan meja resto.
  /// Mencegah ID teknis seperti 'cat_makanan' tampil di hadapan pelanggan.
  String _resolveCategoryName(String categoryId, Map<String, String>? categoryNames) {
    // 1. Periksa apakah ada nama kategori dari koleksi kategori kasir (POS)
    if (categoryNames != null && categoryNames.containsKey(categoryId)) {
      final name = categoryNames[categoryId]?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    // 2. Kamus pemetaan bawaan mini-resto-pos
    final Map<String, String> defaultMap = {
      'cat_makanan': 'Makanan Utama',
      'cat_minuman': 'Minuman Segar',
      'cat_camilan': 'Camilan & Appetizer',
      'cat_paket': 'Paket Hemat',
      'cat_rokok': 'Rokok & Lainnya',
      'makanan': 'Makanan Utama',
      'minuman': 'Minuman Segar',
      'camilan': 'Camilan & Appetizer',
      'paket': 'Paket Hemat',
    };

    final lower = categoryId.toLowerCase();
    if (defaultMap.containsKey(lower)) {
      return defaultMap[lower]!;
    }

    // 3. Otomatis membersihkan prefix 'cat_' atau 'category_' jika pengguna membuat kategori baru
    var cleaned = categoryId.replaceFirst(RegExp(r'^(cat|category)[_-]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Menu';

    // 4. Ubah menjadi format Title Case yang rapi
    return cleaned
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  /// Mengunggah berkas foto menu makanan/minuman ke Firebase Cloud Storage REST API.
  /// Menghasilkan tautan publik (download URL) yang dapat diakses langsung oleh
  /// Web Pemesanan Tamu (web_order) maupun aplikasi POS kasir.
  Future<String?> uploadProductImage(Uint8List imageBytes, String filename) async {
    try {
      await _ensureAuthenticated();
      final storageBucket = '$projectId.firebasestorage.app';
      final cleanFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final objectPath = (restoId.isNotEmpty && restoId != 'default')
          ? '$restoId/products/$cleanFilename'
          : 'products/$cleanFilename';
      final encodedPath = Uri.encodeComponent(objectPath);

      final uploadUrl = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o?name=$encodedPath&uploadType=media',
      );

      final headers = <String, String>{
        'Content-Type': 'image/jpeg',
      };
      if (_idToken != null && _idToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_idToken';
      }

      final response = await _client.post(
        uploadUrl,
        headers: headers,
        body: imageBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final downloadTokens = data['downloadTokens'] as String?;
        if (downloadTokens != null && downloadTokens.isNotEmpty) {
          final firstToken = downloadTokens.split(',').first.trim();
          final publicUrl =
              'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedPath?alt=media&token=$firstToken';
          debugPrint('[CloudSync] Foto menu berhasil diunggah ke Firebase Storage: $publicUrl');
          return publicUrl;
        } else {
          final mediaUrl =
              'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedPath?alt=media';
          return mediaUrl;
        }
      } else {
        debugPrint('[CloudSync] Gagal upload foto ke Firebase Storage (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudSync] Kendala upload foto menu: $e');
      return null;
    }
  }
}

