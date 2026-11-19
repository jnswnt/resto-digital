import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/online_order_model.dart';
import '../models/product_model.dart';
import '../models/table_call_model.dart';
import '../services/cloud_sync_service.dart';
import 'pos_provider.dart';

import '../services/sound_service.dart';
import '../services/notification_service.dart';

/// Provider Pengelolaan Pesanan Online Meja & Panggilan Pelayan (Self-Ordering).
/// Mengontrol pemantauan realtime pesanan masuk, panggilan pelayan (Call Waiter),
/// audio alert notifikasi di kasir, dan sinkronisasi status ketersediaan menu.
class OnlineOrderProvider with ChangeNotifier {
  final CloudSyncService _syncService;
  final SoundService _soundService;

  List<OnlineOrderModel> _onlineOrders = [];
  List<TableCallModel> _tableCalls = [];
  bool _isLoading = false;
  bool _isSyncingMenu = false;
  Timer? _pollingTimer;

  final Set<String> _knownOrderIds = {};
  final Set<String> _knownCallIds = {};
  bool _isFirstFetch = true;

  OnlineOrderProvider(
    this._syncService, {
    SoundService? soundService,
    bool autoStart = false,
  }) : _soundService = soundService ?? SoundService() {
    if (autoStart) {
      startListening();
    }
  }

  List<OnlineOrderModel> get onlineOrders => List.unmodifiable(_onlineOrders);
  List<TableCallModel> get tableCalls => List.unmodifiable(_tableCalls);
  bool get isLoading => _isLoading;
  bool get isSyncingMenu => _isSyncingMenu;
  bool get isSoundEnabled => _soundService.isSoundEnabled;

  /// Pesan kendala jaringan/koneksi cloud jika ada
  String? get syncError => _syncService.lastError;
  bool get hasSyncError => _syncService.lastError != null;

  /// Mengaktifkan atau menonaktifkan suara notifikasi
  void setSoundEnabled(bool enabled) {
    _soundService.setSoundEnabled(enabled);
    notifyListeners();
  }

  /// Uji coba memutar suara notifikasi pesanan masuk
  Future<void> testNotificationSound() async {
    await _soundService.testSound();
  }

  /// Daftar pesanan meja baru yang masih menunggu persetujuan kasir
  List<OnlineOrderModel> get pendingOrders =>
      _onlineOrders.where((o) => o.isPending).toList();

  /// Jumlah pesanan baru yang membutuhkan perhatian kasir
  int get pendingCount => pendingOrders.length;

  /// Panggilan bantuan pelayan yang belum dilayani
  List<TableCallModel> get pendingCalls =>
      _tableCalls.where((c) => c.isPending).toList();

  /// Jumlah panggilan pelayan yang belum dilayani
  int get pendingCallsCount => pendingCalls.length;

  /// Memulai pemantauan pesanan & panggilan masuk berkala dari Cloud (interval 4 detik)
  void startListening({Duration interval = const Duration(seconds: 4)}) {
    _pollingTimer?.cancel();
    fetchAll();
    _pollingTimer = Timer.periodic(interval, (_) => fetchAll());
  }

  /// Menghentikan pemantauan berkala
  void stopListening() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Memperbarui konfigurasi CloudSyncService secara dinamis saat pengaturan cloud berubah
  void syncWithSettings(dynamic settings) {
    _syncService.updateConfig(
      projectId: settings.firebaseProjectId as String?,
      apiKey: settings.firebaseApiKey as String?,
      restoId: settings.restoId as String?,
    );
    final isEnabled = settings.isCloudSyncEnabled as bool? ?? true;
    if (!isEnabled) {
      stopListening();
      _onlineOrders = [];
      _tableCalls = [];
      notifyListeners();
    } else {
      if (_pollingTimer == null) {
        startListening();
      } else {
        fetchAll();
      }
    }
  }

  /// Mengambil daftar pesanan online dan panggilan pelayan dari cloud
  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _syncService.fetchOnlineOrders(),
        _syncService.fetchTableCalls(),
      ]);

      final orders = results[0] as List<OnlineOrderModel>;
      final calls = results[1] as List<TableCallModel>;

      final currentPendingOrders = orders.where((o) => o.isPending).toList();
      final currentPendingCalls = calls.where((c) => c.isPending).toList();

      if (_isFirstFetch) {
        _isFirstFetch = false;
        // Catat semua ID yang sudah ada saat aplikasi pertama kali dibuka
        for (final o in orders) {
          _knownOrderIds.add(o.orderId);
        }
        for (final c in calls) {
          _knownCallIds.add(c.callId);
        }

        // Jika saat kasir standby sudah ada pesanan/panggilan pending, bunyikan alarm alert!
        if (currentPendingOrders.isNotEmpty || currentPendingCalls.isNotEmpty) {
          _triggerAudioAlert();
        }
      } else {
        // Deteksi apakah ada pesanan atau panggilan baru yang belum pernah dicatat
        bool hasNewOrder = false;
        for (final o in currentPendingOrders) {
          if (!_knownOrderIds.contains(o.orderId)) {
            hasNewOrder = true;
            _knownOrderIds.add(o.orderId);
            // Munculkan notifikasi sistem Android
            NotificationService().showOrderNotification(
              orderId: o.orderId,
              tableNo: o.tableNo,
              customerName: o.customerName,
              totalAmount: o.totalAmount,
              totalItems: o.totalItems,
            );
          }
        }

        bool hasNewCall = false;
        for (final c in currentPendingCalls) {
          if (!_knownCallIds.contains(c.callId)) {
            hasNewCall = true;
            _knownCallIds.add(c.callId);
            // Munculkan notifikasi sistem Android
            NotificationService().showWaiterCallNotification(
              callId: c.callId,
              tableNo: c.tableNo,
              note: c.note,
            );
          }
        }

        // Catat semua ID lainnya agar tidak terpicu ulang jika statusnya berubah
        for (final o in orders) {
          _knownOrderIds.add(o.orderId);
        }
        for (final c in calls) {
          _knownCallIds.add(c.callId);
        }

        if (hasNewOrder || hasNewCall) {
          _triggerAudioAlert();
        }
      }

      // Jika sinkronisasi berhasil atau data baru ditemukan, perbarui state
      if (_syncService.lastError == null || orders.isNotEmpty) {
        _onlineOrders = orders;
        _tableCalls = calls;
      }
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal fetch orders/calls: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _triggerAudioAlert() {
    _soundService.playOrderAlert();
  }

  /// Kasir menerima pesanan online meja:
  /// 1. Status di Cloud diperbarui menjadi 'processing' (HP Pelanggan beralih ke "Diproses")
  /// 2. Pesanan otomatis dimasukkan ke sistem POS kasir sebagai Open Tab secara langsung TANPA MENGHAPUS keranjang aktif kasir
  Future<bool> acceptOrder({
    required OnlineOrderModel order,
    required PosProvider posProvider,
    required String shiftId,
  }) async {
    try {
      final success = await _syncService.updateOrderStatus(order.orderId, 'processing');
      
      final tableLabel = order.tableNo.startsWith('Meja')
          ? order.tableNo
          : 'Meja ${order.tableNo.padLeft(2, '0')}';

      // Helper normalisasi nama meja
      String normTable(String t) => t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final targetNorm = normTable(tableLabel);

      // Cek apakah meja ini sudah memiliki open tab aktif di kasir
      final hasExistingOpenTab = posProvider.openOrders.any(
        (o) => o.tableNo != null && normTable(o.tableNo!) == targetNorm,
      );

      final isQrisPaid = order.paymentMethod == 'qris' && order.paymentStatus == 'paid';
      final paidAmountForThisOrder = isQrisPaid ? order.totalAmount : 0;

      if (hasExistingOpenTab) {
        // Meja sudah aktif (Pesanan Tambahan / Round 2): Gabungkan item ke tagihan yang sama
        await posProvider.appendItemsToOpenTab(
          tableNo: tableLabel,
          newItems: order.items,
          customerName: order.customerName,
          additionalPaidAmount: paidAmountForThisOrder,
          onlineOrderId: order.orderId,
        );
      } else {
        // Pesanan Meja Baru: Buat open tab baru di kasir secara langsung tanpa mengganggu keranjang kasir
        await posProvider.createOpenTabDirectly(
          shiftId: shiftId,
          tableNo: tableLabel,
          customerName: order.customerName,
          items: order.items,
          onlineOrderId: order.orderId,
          paidAmount: paidAmountForThisOrder,
        );
      }

      final idx = _onlineOrders.indexWhere((o) => o.orderId == order.orderId);
      if (idx >= 0) {
        _onlineOrders[idx] = _onlineOrders[idx].copyWith(status: 'processing');
      }

      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal menerima order: $e');
      return false;
    }
  }

  /// Memperbarui status pesanan meja menjadi lunas (paid) di Cloud Firestore.
  /// Memicu perubahan instan di layar HP tamu ke status lunas.
  Future<bool> markTableOrderPaid({
    required String tableNo,
    required String orderId,
    required String paymentMethod,
  }) async {
    try {
      bool anyUpdated = false;

      // Normalisasi meja
      String cleanTable(String t) => t.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final targetClean = cleanTable(tableNo);

      // 1. Perbarui semua pesanan aktif untuk meja ini di Cloud
      for (final o in _onlineOrders) {
        final matchesId = o.orderId == orderId;
        final matchesTable = targetClean.isNotEmpty && cleanTable(o.tableNo) == targetClean && !o.isPaid;

        if (matchesId || matchesTable) {
          final res = await _syncService.markOrderAsPaid(o.orderId, paymentMethod);
          if (res) {
            anyUpdated = true;
            final idx = _onlineOrders.indexWhere((item) => item.orderId == o.orderId);
            if (idx >= 0) {
              _onlineOrders[idx] = _onlineOrders[idx].copyWith(status: 'paid', paymentStatus: 'paid');
            }
          }
        }
      }

      // 2. Jika tidak ditemukan di cache online orders, coba langsung update dengan orderId
      if (!anyUpdated && orderId.isNotEmpty && !orderId.startsWith('ord_')) {
        anyUpdated = await _syncService.markOrderAsPaid(orderId, paymentMethod);
      }

      notifyListeners();
      return anyUpdated;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal markTableOrderPaid: $e');
      return false;
    }
  }

  /// Kasir memverifikasi transfer dana QRIS mandiri dari HP tamu
  /// Memperbarui status di Cloud Firestore, model OnlineOrder, dan pesanan lokal di PosProvider
  Future<bool> verifyQrisPayment(String orderId, {PosProvider? posProvider}) async {
    try {
      final success = await _syncService.updatePaymentStatus(orderId, 'paid');
      final idx = _onlineOrders.indexWhere((o) => o.orderId == orderId);
      if (idx >= 0) {
        final onlineOrder = _onlineOrders[idx];
        _onlineOrders[idx] = onlineOrder.copyWith(paymentStatus: 'paid');

        // Sinkronisasi status tagihan lunas ke POS lokal agar tidak ditagih ulang di kasir
        if (posProvider != null) {
          await posProvider.markOnlineOrderAsPaid(
            onlineOrderId: orderId,
            tableNo: onlineOrder.tableNo,
            paidAmount: onlineOrder.totalAmount,
          );
        }

        notifyListeners();
      } else if (posProvider != null) {
        await posProvider.markOnlineOrderAsPaid(onlineOrderId: orderId);
      }
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal verifyQrisPayment: $e');
      return false;
    }
  }

  /// Kasir menandai pesanan telah disajikan / selesai
  Future<bool> markOrderCompleted(String orderId) async {
    try {
      final success = await _syncService.updateOrderStatus(orderId, 'completed');
      final idx = _onlineOrders.indexWhere((o) => o.orderId == orderId);
      if (idx >= 0) {
        _onlineOrders[idx] = _onlineOrders[idx].copyWith(status: 'completed');
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal mark completed: $e');
      return false;
    }
  }

  /// Memperbarui nomor meja pesanan di cloud saat kasir memindahkan meja tamu
  Future<bool> updateOrderTableNo(String orderId, String newTableNo) async {
    try {
      final success = await _syncService.updateOrderTableNo(orderId, newTableNo);
      final idx = _onlineOrders.indexWhere((o) => o.orderId == orderId);
      if (idx >= 0) {
        _onlineOrders[idx] = _onlineOrders[idx].copyWith(tableNo: newTableNo);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal updateOrderTableNo: $e');
      return false;
    }
  }

  /// Kasir menolak pesanan (misalnya menu habis)
  Future<bool> rejectOrder(String orderId) async {
    try {
      final success = await _syncService.updateOrderStatus(orderId, 'rejected');
      final idx = _onlineOrders.indexWhere((o) => o.orderId == orderId);
      if (idx >= 0) {
        _onlineOrders[idx] = _onlineOrders[idx].copyWith(status: 'rejected');
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal menolak order: $e');
      return false;
    }
  }

  /// Kasir menandai panggilan bantuan pelayan telah selesai dilayani
  Future<bool> resolveTableCall(String callId) async {
    try {
      final success = await _syncService.resolveTableCall(callId);
      final idx = _tableCalls.indexWhere((c) => c.callId == callId);
      if (idx >= 0) {
        _tableCalls[idx] = _tableCalls[idx].copyWith(status: 'resolved');
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[OnlineOrderProvider] Gagal resolve table call: $e');
      return false;
    }
  }

  final Map<String, bool> _cloudProductAvailability = {};

  /// Cek status ketersediaan produk di cloud
  bool isProductAvailable(String productId, {bool fallback = true}) {
    return _cloudProductAvailability[productId] ?? fallback;
  }

  /// Toggle ketersediaan menu (Tersedia / Habis) langsung ke cloud web
  Future<bool> toggleProductAvailability(String productId, bool isAvailable) async {
    final success = await _syncService.syncMenuAvailability(productId, isAvailable);
    if (success) {
      _cloudProductAvailability[productId] = isAvailable;
      notifyListeners();
    }
    return success;
  }

  /// Menyinkronkan seluruh daftar menu dari POS kasir ke Cloud Firestore
  Future<bool> syncMenuCatalog(
    List<ProductModel> products, {
    Map<String, String>? categoryNames,
  }) async {
    _isSyncingMenu = true;
    notifyListeners();

    try {
      final success = await _syncService.syncMenuToCloud(
        products,
        categoryNames: categoryNames,
      );
      return success;
    } finally {
      _isSyncingMenu = false;
      notifyListeners();
    }
  }

  /// Menyinkronkan konfigurasi QRIS toko ke Cloud
  Future<bool> syncQrisConfig(String qrisPayload, String storeName) async {
    return await _syncService.syncQrisConfigToCloud(qrisPayload, storeName);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
