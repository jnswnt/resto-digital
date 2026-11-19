import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_resto_pos/models/user_model.dart';
import 'package:mini_resto_pos/services/auth_service.dart';
import 'package:mini_resto_pos/services/cloud_sync_service.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:mini_resto_pos/services/onboarding_template_service.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Onboarding & Registrasi Tenant SaaS (Cara 2)', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DatabaseHelper.instance;
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
    });

    test('OnboardingTemplateService menyediakan template yang valid', () {
      // 1. Template Coffee Shop
      final coffeeCats = OnboardingTemplateService.getCategories(TemplateBusinessType.coffeeShop);
      final coffeeProds = OnboardingTemplateService.getProducts(TemplateBusinessType.coffeeShop);
      expect(coffeeCats.length, 4);
      expect(coffeeProds.length, greaterThanOrEqualTo(5));
      expect(coffeeProds.any((p) => p.name.contains('Kopi Susu')), isTrue);

      // 2. Template Restaurant
      final restoCats = OnboardingTemplateService.getCategories(TemplateBusinessType.restaurant);
      final restoProds = OnboardingTemplateService.getProducts(TemplateBusinessType.restaurant);
      expect(restoCats.length, 4);
      expect(restoProds.length, greaterThanOrEqualTo(5));
      expect(restoProds.any((p) => p.name.contains('Nasi Goreng')), isTrue);

      // 3. Template Blank (Mulai dari Nol)
      final blankCats = OnboardingTemplateService.getCategories(TemplateBusinessType.blank);
      final blankProds = OnboardingTemplateService.getProducts(TemplateBusinessType.blank);
      expect(blankCats.isEmpty, isTrue);
      expect(blankProds.isEmpty, isTrue);
    });

    test('CloudSyncService.registerTenant berhasil mendaftarkan tenant ke Server SaaS', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/tenants/register') {
          final body = jsonDecode(request.body);
          expect(body['restoId'], 'kopi-senja');
          expect(body['businessName'], 'Kopi Senja');
          expect(body['trialDays'], 14);

          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Tenant berhasil didaftarkan.',
              'tenant': {
                'restoId': 'kopi-senja',
                'businessName': 'Kopi Senja',
                'subscriptionStatus': 'trial',
                'daysLeft': 14,
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = CloudSyncService(client: mockClient, restoId: 'kopi-senja');
      final result = await service.registerTenant(
        restoId: 'kopi-senja',
        businessName: 'Kopi Senja',
        businessType: 'cafe',
        ownerName: 'Bambang',
        phone: '081234567890',
        trialDays: 14,
      );

      expect(result, isNotNull);
      expect(result!['success'], isTrue);
      expect(result['tenant']['restoId'], 'kopi-senja');
    });

    test('StorageService.setupNewTenant mengonfigurasi data awal tenant baru secara utuh', () async {
      final storage = await StorageService.init(dbHelper: dbHelper);

      // Jalankan setup tenant baru dengan Template Coffee Shop
      await storage.setupNewTenant(
        storeName: 'Kopi Senja',
        restoId: 'kopi-senja',
        businessType: 'cafe',
        address: 'Jl. Riau No. 45, Bandung',
        phoneWA: '081234567890',
        ownerName: 'Bambang',
        ownerPin: '8888',
        cashierName: 'Rina',
        cashierPin: '1234',
        templateType: TemplateBusinessType.coffeeShop,
      );

      // 1. Verifikasi Settings
      final settings = storage.getSettings();
      expect(settings.storeName, 'Kopi Senja');
      expect(settings.restoId, 'kopi-senja');
      expect(settings.businessType, 'cafe');
      expect(settings.isOnboarded, isTrue);
      expect(settings.subscriptionStatus, 'trial');
      expect(settings.trialDaysRemaining, greaterThanOrEqualTo(13));
      expect(settings.isSubscriptionActive, isTrue);

      // 2. Verifikasi Users (Owner & Kasir baru)
      final users = storage.getUsers();
      expect(users.length, 3);
      final owner = users.firstWhere((u) => u.isOwner);
      expect(owner.name, 'Bambang (Owner)');
      final cashier = users.firstWhere((u) => u.isCashier);
      expect(cashier.name, 'Rina (Kasir)');

      // 3. Verifikasi Katalog Produk terisi sesuai template
      final categories = storage.getCategories();
      final products = storage.getProducts();
      expect(categories.length, 4);
      expect(products.any((p) => p.name.contains('Kopi Susu')), isTrue);
      expect(products.any((p) => p.name.contains('Americano')), isTrue);
    });

    test('StorageService.setupNewTenant dengan Template Blank menghasilkan menu bersih', () async {
      final storage = await StorageService.init(dbHelper: dbHelper);

      await storage.setupNewTenant(
        storeName: 'Warkop Bersih',
        restoId: 'warkop-bersih',
        businessType: 'warung',
        address: 'Jl. Melati',
        phoneWA: '0899999999',
        ownerName: 'Siti',
        ownerPin: '7777',
        cashierName: 'Doni',
        cashierPin: '1111',
        templateType: TemplateBusinessType.blank,
      );

      final settings = storage.getSettings();
      expect(settings.storeName, 'Warkop Bersih');
      expect(settings.isOnboarded, isTrue);

      // Menu harus 0 (bersih tanpa dummy sama sekali)
      expect(storage.getCategories().isEmpty, isTrue);
      expect(storage.getProducts().isEmpty, isTrue);
    });

    test('Simulasi Penautan HP Karyawan (Lukman Koki Dapur - Toko Samelona)', () async {
      final salt = AuthService.generateSalt();
      final pinHash = AuthService.hashPin('5555', salt);

      final mockClient = MockClient((request) async {
        // Stage 1: Verifikasi Resto ID & Username
        if (request.url.path == '/api/tenants/samelona/staff/verify') {
          final body = jsonDecode(request.body);
          if (body['username'] == 'lukman') {
            return http.Response(
              jsonEncode({
                'success': true,
                'restoId': 'samelona',
                'restoName': 'Toko Samelona',
                'staff': {
                  'id': 'user_lukman',
                  'name': 'Lukman',
                  'username': 'lukman',
                  'role': 'kitchen',
                  'salt': salt,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'error': 'Karyawan tidak ditemukan'}), 404);
        }

        // Stage 2: Verifikasi PIN & Pairing
        if (request.url.path == '/api/tenants/samelona/staff/pair') {
          final body = jsonDecode(request.body);
          if (body['username'] == 'lukman' && body['pinHash'] == pinHash) {
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Perangkat berhasil ditautkan ke Toko Samelona',
                'restoId': 'samelona',
                'restoName': 'Toko Samelona',
                'staff': {
                  'id': 'user_lukman',
                  'name': 'Lukman',
                  'username': 'lukman',
                  'role': 'kitchen',
                  'pinHash': pinHash,
                  'salt': salt,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'error': 'PIN salah'}), 401);
        }

        return http.Response('Not Found', 404);
      });

      final cloudSync = CloudSyncService(client: mockClient, restoId: 'samelona');

      // 1. Uji Stage 1: Lukman masukkan Resto ID: samelona & Username: lukman
      final verify = await cloudSync.verifyStaffDevice(restoId: 'samelona', username: 'lukman');
      expect(verify, isNotNull);
      expect(verify!['success'], isTrue);
      expect(verify['staff']['role'], 'kitchen');

      // 2. Uji Stage 2: Lukman masukkan PIN 5555
      final pair = await cloudSync.pairStaffDevice(
        restoId: 'samelona',
        username: 'lukman',
        pinHash: pinHash,
      );
      expect(pair, isNotNull);
      expect(pair!['success'], isTrue);

      // 3. Simpan konfigurasi ke HP Lukman secara lokal
      final storage = await StorageService.init(dbHelper: dbHelper);
      final staffUser = UserModel(
        id: pair['staff']['id'],
        name: pair['staff']['name'],
        username: pair['staff']['username'],
        role: pair['staff']['role'],
        pinHash: pinHash,
        salt: salt,
      );

      await storage.pairStaffDevice(
        restoId: 'samelona',
        storeName: 'Toko Samelona',
        staffUser: staffUser,
      );

      // 4. Verifikasi status HP Lukman sekarang
      final settings = storage.getSettings();
      expect(settings.restoId, 'samelona');
      expect(settings.storeName, 'Toko Samelona');
      expect(settings.isOnboarded, isTrue); // HP Lukman resmi tertaut!

      final users = storage.getUsers();
      expect(users.length, 1);
      expect(users.first.name, 'Lukman');
      expect(users.first.isKitchen, isTrue); // Terdeteksi sebagai Koki Dapur!
    });

    test('Otentikasi Akun Google Owner (Multi-Outlet & Penautan Instan)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/google') {
          final body = jsonDecode(request.body);
          if (body['email'] == 'owner@samelona.com') {
            return http.Response(
              jsonEncode({
                'success': true,
                'isNewUser': false,
                'user': {'email': 'owner@samelona.com', 'name': 'Owner Samelona'},
                'tenants': [
                  {
                    'restoId': 'samelona-1',
                    'businessName': 'Toko Samelona - Cabang 1',
                    'subscriptionStatus': 'trial',
                    'daysLeft': 14,
                  },
                  {
                    'restoId': 'samelona-2',
                    'businessName': 'Toko Samelona - Cabang 2',
                    'subscriptionStatus': 'active',
                    'daysLeft': 30,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({
                'success': true,
                'isNewUser': true,
                'user': {'email': body['email'], 'name': body['name']},
                'tenants': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        } else if (request.url.path == '/api/tenants/samelona-1/details') {
          return http.Response(
            jsonEncode({
              'success': true,
              'tenant': {
                'restoId': 'samelona-1',
                'businessName': 'Toko Samelona - Cabang 1',
                'ownerEmail': 'owner@samelona.com',
                'subscriptionStatus': 'trial',
              },
              'catalog': {'categories': [], 'products': []},
              'staff': [
                {
                  'id': 'u_owner',
                  'name': 'Owner Samelona',
                  'role': 'owner',
                  'pinHash': 'hash123',
                  'salt': 'salt123',
                  'isActive': true,
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final cloudSync = CloudSyncService(client: mockClient);

      // 1. Uji Login Akun Google Owner yang sudah memiliki 2 cabang
      final authExisting = await cloudSync.authenticateWithGoogle(
        email: 'owner@samelona.com',
        name: 'Owner Samelona',
      );
      expect(authExisting, isNotNull);
      expect(authExisting!['isNewUser'], isFalse);
      expect((authExisting['tenants'] as List).length, 2);

      // 2. Uji Penautan Tablet ke Cabang 1
      final details = await cloudSync.fetchTenantDetails('samelona-1');
      expect(details, isNotNull);
      expect(details!['tenant']['restoId'], 'samelona-1');

      final storage = await StorageService.init(dbHelper: dbHelper);
      await storage.linkOwnerTenant(
        restoId: 'samelona-1',
        storeName: 'Toko Samelona - Cabang 1',
        ownerEmail: 'owner@samelona.com',
        subscriptionStatus: 'trial',
      );

      final settings = storage.getSettings();
      expect(settings.restoId, 'samelona-1');
      expect(settings.storeName, 'Toko Samelona - Cabang 1');
      expect(settings.ownerEmail, 'owner@samelona.com');
      expect(settings.isOnboarded, isTrue);

      // 3. Uji Login Akun Google Baru (Belum punya tenant)
      final authNew = await cloudSync.authenticateWithGoogle(
        email: 'newowner@gmail.com',
        name: 'Budi Baru',
      );
      expect(authNew, isNotNull);
      expect(authNew!['isNewUser'], isTrue);
      expect((authNew['tenants'] as List).isEmpty, isTrue);
    });
  });
}
