import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Layanan Notifikasi Sistem Android (Heads-Up Alert dengan Suara & Getar).
/// Menampilkan banner notifikasi prioritas tinggi saat ada pesanan online baru dari meja
/// atau panggilan bantuan pelayan, bahkan saat aplikasi sedang tidak dalam standby.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Channel ID Notifikasi Prioritas Tinggi untuk Pesanan Masuk
  static const String orderChannelId = 'mini_resto_orders';
  static const String orderChannelName = 'Pesanan Resto Masuk';

  /// Channel ID Notifikasi Panggilan Pelayan
  static const String waiterChannelId = 'mini_resto_waiter';
  static const String waiterChannelName = 'Panggilan Pelayan Meja';

  /// Channel ID Notifikasi Layanan Latar Belakang (Foreground Service)
  static const String serviceChannelId = 'mini_resto_service';
  static const String serviceChannelName = 'Layanan Siaga POS Resto';

  /// Inisialisasi plugin notifikasi dan pembuatan notification channels Android
  Future<void> initialize({
    Function(String? payload)? onNotificationTap,
    bool requestAlertPermission = false,
  }) async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NotificationService] Notifikasi disentuh, payload: ${response.payload}');
        if (onNotificationTap != null) {
          onNotificationTap(response.payload);
        }
      },
    );

    // Buat Notification Channels untuk Android 8.0+ (Oreo ke atas)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 1. Channel Pesanan Baru (Maksimum: Pop-up / Heads-Up + Suara + Getar)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          orderChannelId,
          orderChannelName,
          description: 'Notifikasi saat pelanggan mengirim pesanan meja mandiri',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // 2. Channel Panggilan Pelayan (Prioritas Tinggi)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          waiterChannelId,
          waiterChannelName,
          description: 'Notifikasi saat tamu meja menekan tombol Panggil Pelayan',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // 3. Channel Layanan Latar Belakang (Low Importance, Tanpa Dering Berulang)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          serviceChannelId,
          serviceChannelName,
          description: 'Notifikasi status siaga pemantauan pesanan latar belakang',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );

      // Hanya minta izin interaktif jika diminta oleh UI utama (Bukan di Background Isolate)
      if (requestAlertPermission) {
        await requestPermission();
      }
    }

    _isInitialized = true;
    debugPrint('[NotificationService] Layanan notifikasi Android siap digunakan.');
  }

  /// Meminta izin notifikasi secara eksplisit pada Android 13+ (Hanya dipanggil dari UI Isolate)
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Request permission dilewati (bukan UI context): $e');
    }
    return true;
  }

  /// Menampilkan notifikasi heads-up saat ada pesanan meja baru masuk
  Future<void> showOrderNotification({
    required String orderId,
    required String tableNo,
    required String customerName,
    required int totalAmount,
    required int totalItems,
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      orderChannelId,
      orderChannelName,
      channelDescription: 'Notifikasi saat pelanggan mengirim pesanan meja mandiri',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Pesanan Meja $tableNo Masuk!',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEA580C),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'Pelanggan: $customerName\n'
        'Jumlah: $totalItems Menu (Rp $totalAmount)\n'
        'Ketuk untuk membuka dan menyetujui pesanan.',
        contentTitle: '🔔 Pesanan Baru Masuk! - Meja $tableNo',
        summaryText: 'Pesanan Online Meja',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final notificationId = orderId.hashCode;

    await _notificationsPlugin.show(
      id: notificationId,
      title: '🔔 Pesanan Baru Masuk! - Meja $tableNo',
      body: '$customerName memesan $totalItems item (Rp $totalAmount)',
      notificationDetails: notificationDetails,
      payload: 'order:$orderId',
    );
  }

  /// Menampilkan notifikasi heads-up saat ada tamu meja memanggil pelayan
  Future<void> showWaiterCallNotification({
    required String callId,
    required String tableNo,
    required String note,
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      waiterChannelId,
      waiterChannelName,
      channelDescription: 'Notifikasi saat tamu meja menekan tombol Panggil Pelayan',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Panggilan dari Meja $tableNo!',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFD97706),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        note.isNotEmpty ? 'Catatan: $note' : 'Tamu membutuhkan bantuan pelayan di meja.',
        contentTitle: '🛎️ Panggilan Pelayan! - Meja $tableNo',
        summaryText: 'Panggilan Meja',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final notificationId = callId.hashCode;

    await _notificationsPlugin.show(
      id: notificationId,
      title: '🛎️ Panggilan Pelayan! - Meja $tableNo',
      body: 'Meja $tableNo memanggil pelayan: ${note.isNotEmpty ? note : "Bantuan di meja"}',
      notificationDetails: notificationDetails,
      payload: 'call:$callId',
    );
  }

  /// Menampilkan notifikasi uji coba untuk memvalidasi suara & getaran di HP kasir
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    await showOrderNotification(
      orderId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      tableNo: '08',
      customerName: 'Budi Santoso (Uji Coba)',
      totalAmount: 48000,
      totalItems: 3,
    );
  }
}
