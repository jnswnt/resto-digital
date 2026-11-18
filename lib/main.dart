import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/customer_debt_provider.dart';
import 'providers/theme_provider.dart';
import 'app.dart';

import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';
import 'services/background_order_service.dart';
import 'providers/online_order_provider.dart';
import 'providers/analytics_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi penyimpanan lokal dan starter kit resto
  final storageService = await StorageService.init();
  final settings = storageService.getSettings();
  final cloudSyncService = CloudSyncService(
    projectId: settings.firebaseProjectId,
    apiKey: settings.firebaseApiKey,
    restoId: settings.restoId,
  );

  // Inisialisasi Notifikasi Sistem & Layanan Latar Belakang Android (Khusus platform Native Android)
  if (!kIsWeb) {
    try {
      await NotificationService().initialize(requestAlertPermission: true);
      await BackgroundOrderService().initialize();
    } catch (e) {
      debugPrint('[Main] Kendala inisialisasi background/notification service: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(storageService.prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider(storageService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => PosProvider(storageService)),
        ChangeNotifierProvider(create: (_) => ShiftProvider(storageService)),
        ChangeNotifierProvider(create: (_) => CustomerDebtProvider(storageService)),
        ChangeNotifierProvider(create: (_) => OnlineOrderProvider(cloudSyncService)),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider(storageService)),
      ],
      child: const PosRestoApp(),
    ),
  );
}

