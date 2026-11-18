import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_resto_pos/services/cloud_sync_service.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:mini_resto_pos/services/onboarding_template_service.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

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
      expect(settings.trialDaysRemaining, 14);
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
  });
}
