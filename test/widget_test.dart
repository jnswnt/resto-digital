import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/providers/auth_provider.dart';
import 'package:mini_resto_pos/providers/settings_provider.dart';
import 'package:mini_resto_pos/providers/pos_provider.dart';
import 'package:mini_resto_pos/providers/shift_provider.dart';
import 'package:mini_resto_pos/providers/customer_debt_provider.dart';
import 'package:mini_resto_pos/providers/online_order_provider.dart';
import 'package:mini_resto_pos/services/cloud_sync_service.dart';
import 'package:mini_resto_pos/providers/theme_provider.dart';
import 'package:mini_resto_pos/providers/analytics_provider.dart';
import 'package:mini_resto_pos/views/screens/lock_screen.dart';
import 'package:mini_resto_pos/views/screens/settings_screen.dart';
import 'package:mini_resto_pos/app.dart';
import 'package:provider/provider.dart';
import 'package:mini_resto_pos/models/online_order_model.dart';
import 'package:mini_resto_pos/models/table_call_model.dart';
import 'package:mini_resto_pos/models/user_model.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/models/category_model.dart';
import 'package:mini_resto_pos/models/product_model.dart';
import 'package:mini_resto_pos/services/auth_service.dart';

class MockCloudSyncService extends CloudSyncService {
  @override
  Future<List<OnlineOrderModel>> fetchOnlineOrders({DateTime? forDate}) async => [];

  @override
  Future<List<TableCallModel>> fetchTableCalls() async => [];
}

class FakeStorageService extends StorageService {
  final List<CategoryModel> _cats;
  final List<ProductModel> _prods;

  FakeStorageService(super.prefs, {List<CategoryModel>? categories, List<ProductModel>? products})
      : _cats = categories ?? [],
        _prods = products ?? [];

  @override
  List<CategoryModel> getCategories() => _cats;

  @override
  List<ProductModel> getProducts() => _prods;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Aplikasi harus menampilkan LockScreen (Numpad) saat pertama dibuka', (WidgetTester tester) async {
    await initializeDateFormatting('id_ID', null);
    
    final salt = AuthService.generateSalt();
    final initialUsers = [
      UserModel(
        id: 'user_owner',
        name: 'Owner Resto',
        role: 'owner',
        pinHash: AuthService.hashPin('9999', salt),
        salt: salt,
        isActive: true,
      ),
    ];
    final initialSettings = SettingsModel(
      storeName: 'Resto Digital',
      address: 'Jl. Pemuda No. 88',
      phoneWA: '081234567890',
      ownerPinHash: AuthService.hashPin('9999', salt),
      ownerSalt: salt,
    );

    SharedPreferences.setMockInitialValues({
      'pos_warkop_users': jsonEncode(initialUsers.map((u) => u.toMap()).toList()),
      'pos_warkop_settings': jsonEncode(initialSettings.toMap()),
    });
    final prefs = await SharedPreferences.getInstance();
    final storageService = FakeStorageService(prefs);

    final onlineOrderProvider = OnlineOrderProvider(MockCloudSyncService());
    onlineOrderProvider.stopListening();
    final analyticsProvider = AnalyticsProvider(storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(storageService.prefs)),
          ChangeNotifierProvider(create: (_) => AuthProvider(storageService)),
          ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
          ChangeNotifierProvider(create: (_) => PosProvider(storageService)),
          ChangeNotifierProvider(create: (_) => ShiftProvider(storageService)),
          ChangeNotifierProvider(create: (_) => CustomerDebtProvider(storageService)),
          ChangeNotifierProvider<OnlineOrderProvider>.value(value: onlineOrderProvider),
          ChangeNotifierProvider<AnalyticsProvider>.value(value: analyticsProvider),
        ],
        child: const PosRestoApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verifikasi bahwa layar LockScreen dan numpad tampil
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Resto Digital'), findsOneWidget);

    // Hentikan timer dan unmount widget
    onlineOrderProvider.stopListening();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('SettingsScreen harus memuat List Sub Menu (Profil, Denah Meja, QRIS, Kasir) tanpa Tab', (WidgetTester tester) async {
    await initializeDateFormatting('id_ID', null);
    
    final salt = AuthService.generateSalt();
    final ownerUser = UserModel(
      id: 'owner_1',
      name: 'Owner Resto',
      role: 'owner',
      pinHash: AuthService.hashPin('9999', salt),
      salt: salt,
      isActive: true,
    );
    final initialSettings = SettingsModel(
      storeName: 'Resto Digital',
      address: 'Jl. Pemuda No. 88',
      phoneWA: '081234567890',
      ownerPinHash: AuthService.hashPin('9999', salt),
      ownerSalt: salt,
    );

    SharedPreferences.setMockInitialValues({
      'pos_warkop_users': jsonEncode([ownerUser.toMap()]),
      'pos_warkop_settings': jsonEncode(initialSettings.toMap()),
    });
    final prefs = await SharedPreferences.getInstance();
    final storageService = FakeStorageService(prefs);

    final authProvider = AuthProvider(storageService);
    final onlineOrderProvider = OnlineOrderProvider(MockCloudSyncService());
    onlineOrderProvider.stopListening();

    await authProvider.loginWithPin('9999');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(storageService.prefs)),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
          ChangeNotifierProvider<OnlineOrderProvider>.value(value: onlineOrderProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi List Sub Menu tersedia
    expect(find.text('Profil Restoran & Struk'), findsOneWidget);
    expect(find.text('Denah Meja & Area Resto'), findsOneWidget);
    expect(find.text('QRIS Pembayaran Toko'), findsOneWidget);
    expect(find.text('Manajemen Akun Kasir'), findsOneWidget);

    // Hentikan timer dan unmount widget
    onlineOrderProvider.stopListening();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
