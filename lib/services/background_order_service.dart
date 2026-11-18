import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_service.dart';
import 'notification_service.dart';

/// Layanan Latar Belakang Android (Android Foreground Service).
/// Menjaga aplikasi POS tetap siaga memantau pesanan meja online dari Cloud Firestore
/// bahkan ketika aplikasi di-minimize, layar ponsel mati, atau kasir membuka aplikasi lain.
class BackgroundOrderService {
  static final BackgroundOrderService _instance = BackgroundOrderService._internal();
  factory BackgroundOrderService() => _instance;
  BackgroundOrderService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;

  /// Memeriksa apakah layanan latar belakang sedang berjalan aktif
  Future<bool> isRunning() async {
    if (kIsWeb) return false;
    return await _service.isRunning();
  }

  /// Mengaktifkan atau menonaktifkan layanan siaga latar belakang
  Future<void> setServiceEnabled(bool enable) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_order_monitoring_enabled', enable);

    final isCurrentlyRunning = await _service.isRunning();
    if (enable && !isCurrentlyRunning) {
      await _service.startService();
    } else if (!enable && isCurrentlyRunning) {
      _service.invoke('stopService');
    }
  }

  /// Inisialisasi konfigurasi Layanan Latar Belakang POS Resto
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('bg_order_monitoring_enabled') ?? true;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: isEnabled,
        isForegroundMode: true,
        notificationChannelId: NotificationService.serviceChannelId,
        initialNotificationTitle: 'POS Resto Siaga',
        initialNotificationContent: 'Memantau pesanan meja online secara aktif...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: isEnabled,
        onForeground: onBackgroundServiceStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;
    debugPrint('[BackgroundOrderService] Layanan latar belakang POS telah dikonfigurasi.');
  }
}

/// Callback background iOS jika didukung
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Titik Masuk (Entry Point) Layanan Latar Belakang Android
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Inisialisasi notifikasi lokal di isolate background (tanpa memicu popup izin UI)
  final notificationService = NotificationService();
  try {
    await notificationService.initialize(requestAlertPermission: false);
  } catch (e) {
    debugPrint('[BackgroundService] Gagal init notification di background: $e');
  }

  final syncService = CloudSyncService();
  final Set<String> knownOrderIds = {};
  final Set<String> knownCallIds = {};
  bool isFirstRun = true;

  // Muat riwayat ID yang sudah pernah dinotifikasikan dari SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedOrders = prefs.getStringList('bg_notified_orders') ?? [];
    final savedCalls = prefs.getStringList('bg_notified_calls') ?? [];
    knownOrderIds.addAll(savedOrders);
    knownCallIds.addAll(savedCalls);
  } catch (e) {
    debugPrint('[BackgroundService] Kendala memuat cache order: $e');
  }

  // Tangani event stop dari aplikasi utama
  service.on('stopService').listen((event) {
    debugPrint('[BackgroundService] Menerima instruksi stopService.');
    service.stopSelf();
  });

  // Polling periodik Cloud Firestore setiap 6 detik
  Timer.periodic(const Duration(seconds: 6), (timer) async {
    try {
      final results = await Future.wait([
        syncService.fetchOnlineOrders(),
        syncService.fetchTableCalls(),
      ]);

      final orders = results[0] as List;
      final calls = results[1] as List;

      // 1. Periksa Pesanan Baru yang Berstatus Pending
      for (final o in orders) {
        if (o.isPending) {
          if (!knownOrderIds.contains(o.orderId)) {
            knownOrderIds.add(o.orderId);

            // Jangan memicu dering saat service baru pertama kali menyala untuk pesanan lama
            if (!isFirstRun) {
              await notificationService.showOrderNotification(
                orderId: o.orderId,
                tableNo: o.tableNo,
                customerName: o.customerName,
                totalAmount: o.totalAmount,
                totalItems: o.totalItems,
              );
            }
          }
        }
      }

      // 2. Periksa Panggilan Pelayan Baru yang Berstatus Pending
      for (final c in calls) {
        if (c.isPending) {
          if (!knownCallIds.contains(c.callId)) {
            knownCallIds.add(c.callId);

            if (!isFirstRun) {
              await notificationService.showWaiterCallNotification(
                callId: c.callId,
                tableNo: c.tableNo,
                note: c.note,
              );
            }
          }
        }
      }

      // Simpan pembaruan ID ke SharedPreferences agar tidak hilang jika proses di-restart
      if (!isFirstRun) {
        final prefs = await SharedPreferences.getInstance();
        // Batasi maksimal 100 ID terakhir agar hemat memori
        final ordersToSave = knownOrderIds.length > 100
            ? knownOrderIds.toList().sublist(knownOrderIds.length - 100)
            : knownOrderIds.toList();
        final callsToSave = knownCallIds.length > 100
            ? knownCallIds.toList().sublist(knownCallIds.length - 100)
            : knownCallIds.toList();
        await prefs.setStringList('bg_notified_orders', ordersToSave);
        await prefs.setStringList('bg_notified_calls', callsToSave);
      }

      isFirstRun = false;
    } catch (e) {
      debugPrint('[BackgroundService] Polling error di background: $e');
    }
  });
}
