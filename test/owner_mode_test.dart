import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/providers/auth_provider.dart';
import 'package:mini_resto_pos/providers/settings_provider.dart';
import 'package:mini_resto_pos/providers/theme_provider.dart';
import 'package:mini_resto_pos/views/screens/settings_screen.dart';
import 'package:mini_resto_pos/models/user_model.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SettingsProvider settingsProvider;
  late AuthProvider authProvider;
  late ThemeProvider themeProvider;

  setUp(() async {
    await initializeDateFormatting('id_ID', null);

    final saltOwner = AuthService.generateSalt();
    final hashOwner = AuthService.hashPin('9999', saltOwner);

    final saltCashier = AuthService.generateSalt();
    final hashCashier = AuthService.hashPin('1234', saltCashier);

    final users = [
      UserModel(
        id: 'owner_1',
        name: 'Owner Resto',
        pinHash: hashOwner,
        salt: saltOwner,
        role: 'owner',
        isActive: true,
      ),
      UserModel(
        id: 'cashier_1',
        name: 'Kasir Utama',
        pinHash: hashCashier,
        salt: saltCashier,
        role: 'cashier',
        isActive: true,
      ),
    ];

    final settings = SettingsModel(
      storeName: 'Resto Digital',
      address: 'Jl. Pemuda No. 88',
      phoneWA: '081234567890',
      ownerPinHash: hashOwner,
      ownerSalt: saltOwner,
    );

    SharedPreferences.setMockInitialValues({
      'pos_warkop_users': jsonEncode(users.map((u) => u.toMap()).toList()),
      'pos_warkop_settings': jsonEncode(settings.toMap()),
    });

    final prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    settingsProvider = SettingsProvider(storage);
    authProvider = AuthProvider(storage);
    themeProvider = ThemeProvider(prefs);
  });

  group('Pengujian Logika AuthProvider - Mode Owner', () {
    test('Kasir login awal tidak memiliki hak isOwnerMode', () async {
      final loggedIn = await authProvider.loginWithPin('1234');
      expect(loggedIn, isTrue);
      expect(authProvider.currentUser?.isOwner, isFalse);
      expect(authProvider.isOwnerMode, isFalse);
    });

    test('Kasir membuka mode Owner dengan PIN Owner valid lalu mengunci kembali', () async {
      await authProvider.loginWithPin('1234');
      expect(authProvider.isOwnerMode, isFalse);

      // Coba PIN salah
      final wrongUnlock = authProvider.unlockOwnerMode('0000');
      expect(wrongUnlock, isFalse);
      expect(authProvider.isOwnerMode, isFalse);

      // Coba PIN Owner benar
      final successUnlock = authProvider.unlockOwnerMode('9999');
      expect(successUnlock, isTrue);
      expect(authProvider.isOwnerMode, isTrue);

      // Kunci kembali
      authProvider.lockOwnerMode();
      expect(authProvider.isOwnerMode, isFalse);
    });

    test('Mode Owner otomatis di-reset saat kasir logout atau lockScreen', () async {
      await authProvider.loginWithPin('1234');
      authProvider.unlockOwnerMode('9999');
      expect(authProvider.isOwnerMode, isTrue);

      // Lock screen
      authProvider.lockScreen();
      expect(authProvider.isOwnerMode, isFalse);
    });

    test('Owner murni login selalu memiliki isOwnerMode true', () async {
      final loggedIn = await authProvider.loginWithPin('9999');
      expect(loggedIn, isTrue);
      expect(authProvider.currentUser?.isOwner, isTrue);
      expect(authProvider.isOwnerMode, isTrue);
    });
  });

  group('Pengujian Widget SettingsScreen - Inline Lock & Fallback', () {
    testWidgets('SettingsScreen menampilkan inline lock card untuk kasir dan mengeksekusi onCancel', (tester) async {
      await authProvider.loginWithPin('1234'); // Login kasir
      bool cancelClicked = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SettingsScreen(
              embedded: true,
              onCancel: () {
                cancelClicked = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan inline lock screen tampil, bukan popup modal dialog
      expect(find.text('Proteksi Hak Akses Owner'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsOneWidget);
      expect(find.text('Batal / Kembali'), findsOneWidget);

      // Menekan tombol Batal / Kembali
      await tester.tap(find.text('Batal / Kembali'));
      await tester.pumpAndSettle();

      expect(cancelClicked, isTrue);
    });

    testWidgets('Memasukkan PIN Owner di SettingsScreen membuka menu dan lockOwnerMode menguncinya kembali', (tester) async {
      await authProvider.loginWithPin('1234'); // Login kasir

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: SettingsScreen(embedded: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Layar awal terkunci
      expect(find.text('Proteksi Hak Akses Owner'), findsOneWidget);

      // Input PIN salah
      await tester.enterText(find.byType(TextField), '1111');
      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('PIN Owner tidak valid!'), findsOneWidget);
      expect(authProvider.isOwnerMode, isFalse);

      // Input PIN benar
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pumpAndSettle();

      // Menu pengaturan terbuka
      expect(authProvider.isOwnerMode, isTrue);
      expect(find.text('OPERASIONAL RESTO & MEJA'), findsOneWidget);
      expect(find.text('Proteksi Hak Akses Owner'), findsNothing);

      // Skenario Auto-Lock / Manual Lock: kasir kembali ke menu lain
      authProvider.lockOwnerMode();
      await tester.pumpAndSettle();

      // Terkunci kembali
      expect(authProvider.isOwnerMode, isFalse);
      expect(find.text('Proteksi Hak Akses Owner'), findsOneWidget);
    });

    test('Memperbarui Profil Nama dan PIN Owner melalui SettingsProvider & AuthProvider', () async {
      // Login sebagai Owner
      await authProvider.loginWithPin('9999');
      expect(authProvider.currentUser?.name, 'Owner Resto');

      // Update profil Owner
      final updated = await settingsProvider.updateOwnerProfile(
        name: 'H. Sukri (Pemilik Baru)',
        newPin: '8888',
      );

      expect(updated, isNotNull);
      expect(updated?.name, 'H. Sukri (Pemilik Baru)');
      expect(settingsProvider.ownerUser?.name, 'H. Sukri (Pemilik Baru)');

      // Sinkronkan ke auth provider
      authProvider.updateCurrentUserName(updated!.name);
      expect(authProvider.currentUser?.name, 'H. Sukri (Pemilik Baru)');

      // Verifikasi PIN baru berfungsi
      expect(authProvider.verifyOwnerPin('8888'), isTrue);
      expect(authProvider.verifyOwnerPin('9999'), isFalse);
    });
  });
}
