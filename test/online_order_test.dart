import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mini_resto_pos/models/online_order_model.dart';
import 'package:mini_resto_pos/models/order_model.dart';
import 'package:mini_resto_pos/models/table_call_model.dart';
import 'package:mini_resto_pos/services/cloud_sync_service.dart';
import 'package:mini_resto_pos/services/database_helper.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/services/kitchen_ticket_service.dart';
import 'package:mini_resto_pos/services/sound_service.dart';
import 'package:mini_resto_pos/providers/online_order_provider.dart';
import 'package:mini_resto_pos/providers/pos_provider.dart';

void main() {
  group('OnlineOrderModel Tests', () {
    test('Membuat dan memvalidasi siklus status pesanan', () {
      final order = OnlineOrderModel(
        orderId: 'ORD-987654',
        tableNo: '03',
        customerName: 'Budi Santoso',
        totalAmount: 58000,
        status: 'pending',
        items: [
          OrderItem(
            productId: 'm1',
            name: 'Nasi Goreng Spesial Resto',
            price: 28000,
            qty: 1,
            notes: 'Pedas Sedang, Telur Setengah Matang',
          ),
          OrderItem(
            productId: 'm3',
            name: 'Mie Goreng Seafood',
            price: 30000,
            qty: 1,
            notes: 'Tanpa MSG',
          ),
        ],
      );

      // 1. Status Awal: Menunggu Konfirmasi
      expect(order.isPending, isTrue);
      expect(order.statusLabel, equals('Menunggu Konfirmasi'));
      expect(order.items.length, equals(2));
      expect(order.items[0].notes, equals('Pedas Sedang, Telur Setengah Matang'));

      // 2. Transisi ke: Diproses (Diterima Kasir)
      final processingOrder = order.copyWith(status: 'processing');
      expect(processingOrder.isProcessing, isTrue);
      expect(processingOrder.statusLabel, equals('Diproses'));

      // 3. Transisi ke: Disajikan / Selesai
      final completedOrder = processingOrder.copyWith(status: 'completed');
      expect(completedOrder.isCompleted, isTrue);
      expect(completedOrder.statusLabel, equals('Disajikan / Selesai'));
    });

    test('Parsing dari Firestore REST API Document Format', () {
      final firestoreDocName =
          'projects/restodigital-pos/databases/(default)/documents/table_orders/ORD-123456';

      final firestoreFields = {
        'orderId': {'stringValue': 'ORD-123456'},
        'tableNo': {'stringValue': '05'},
        'customerName': {'stringValue': 'Siti Rahma'},
        'status': {'stringValue': 'pending'},
        'totalAmount': {'integerValue': '45000'},
        'createdAt': {'stringValue': '2026-09-11T12:00:00.000Z'},
        'updatedAt': {'stringValue': '2026-09-11T12:00:00.000Z'},
        'items': {
          'arrayValue': {
            'values': [
              {
                'mapValue': {
                  'fields': {
                    'id': {'stringValue': 'm2'},
                    'name': {'stringValue': 'Ayam Bakar Madu'},
                    'price': {'integerValue': '32000'},
                    'qty': {'integerValue': '1'},
                    'note': {'stringValue': 'Sambal dipisah'},
                  }
                }
              },
              {
                'mapValue': {
                  'fields': {
                    'id': {'stringValue': 'm6'},
                    'name': {'stringValue': 'Es Jeruk Peras'},
                    'price': {'integerValue': '13000'},
                    'qty': {'integerValue': '1'},
                    'note': {'stringValue': 'Gula sedikit'},
                  }
                }
              }
            ]
          }
        }
      };

      final parsed = OnlineOrderModel.fromFirestoreRest(firestoreDocName, firestoreFields);

      expect(parsed.orderId, equals('ORD-123456'));
      expect(parsed.tableNo, equals('05'));
      expect(parsed.customerName, equals('Siti Rahma'));
      expect(parsed.totalAmount, equals(45000));
      expect(parsed.status, equals('pending'));
      expect(parsed.statusLabel, equals('Menunggu Konfirmasi'));
      expect(parsed.items.length, equals(2));
      expect(parsed.items[0].name, equals('Ayam Bakar Madu'));
      expect(parsed.items[0].notes, equals('Sambal dipisah'));
      expect(parsed.items[1].name, equals('Es Jeruk Peras'));
      expect(parsed.items[1].notes, equals('Gula sedikit'));
    });
  });

  group('TableCallModel & KitchenTicketService Tests', () {
    test('TableCallModel pembuatan dan parsing Firestore REST', () {
      final call = TableCallModel(
        callId: 'CALL-101',
        tableNo: '03',
        requestType: 'Sendok / Garpu / Piring',
        notes: 'Minta 2 sendok kecil',
      );

      expect(call.isPending, isTrue);
      expect(call.tableNo, equals('03'));
      expect(call.requestType, equals('Sendok / Garpu / Piring'));
      expect(call.notes, equals('Minta 2 sendok kecil'));

      final firestoreDoc = 'projects/restodigital-pos/databases/(default)/documents/table_calls/CALL-102';
      final fields = {
        'callId': {'stringValue': 'CALL-102'},
        'tableNo': {'stringValue': '07'},
        'requestType': {'stringValue': 'Refill Air / Es Batu'},
        'notes': {'stringValue': 'Es batu 1 mangkuk'},
        'status': {'stringValue': 'pending'},
        'createdAt': {'stringValue': '2026-09-12T07:30:00.000Z'},
      };

      final parsedCall = TableCallModel.fromFirestoreRest(firestoreDoc, fields);
      expect(parsedCall.callId, equals('CALL-102'));
      expect(parsedCall.tableNo, equals('07'));
      expect(parsedCall.requestType, equals('Refill Air / Es Batu'));
      expect(parsedCall.isPending, isTrue);
    });

    test('KitchenTicketService menghasilkan format teks KOT yang akurat', () {
      final items = [
        OrderItem(
          productId: 'p1',
          name: 'Nasi Goreng Spesial Resto',
          price: 28000,
          qty: 2,
          notes: 'Pedas Sedang, Tanpa Bawang Goreng',
        ),
        OrderItem(
          productId: 'p2',
          name: 'Es Teh Manis',
          price: 6000,
          qty: 2,
          notes: 'Es Sedikit',
        ),
      ];

      final ticket = KitchenTicketService.buildKitchenTicketText(
        tableNo: '03',
        customerName: 'Ahmad Fauzi',
        items: items,
        orderId: 'ORD-778899',
      );

      expect(ticket, contains('TIKET DAPUR / KOT'));
      expect(ticket, contains('MEJA 03'));
      expect(ticket, contains('Ahmad Fauzi'));
      expect(ticket, contains('ORD-778899'));
      expect(ticket, contains('2    Nasi Goreng Spesial Resto'));
      expect(ticket, contains('>> [RASA: PEDAS SEDANG, TANPA BAWANG GORENG]'));
      expect(ticket, contains('2    Es Teh Manis'));
      expect(ticket, contains('>> [RASA: ES SEDIKIT]'));
      expect(ticket, contains('TOTAL: 4 PORSI/ITEM'));
    });
  });

  group('SoundService & OnlineOrderProvider Alert Tests', () {
    test('SoundService mengontrol status aktif dan nonaktif nada notifikasi', () {
      final soundService = SoundService();
      expect(soundService.isSoundEnabled, isTrue);

      soundService.setSoundEnabled(false);
      expect(soundService.isSoundEnabled, isFalse);

      soundService.setSoundEnabled(true);
      expect(soundService.isSoundEnabled, isTrue);
    });
  });

  group('Kategori 3: Self-Order & Cloud Sync Tests', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('3.1 Verifikasi QRIS Online: Memperbarui status di cloud dan mengupdate paidAmount pesanan meja di PosProvider lokal', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper();
      await dbHelper.initDatabase(customPath: inMemoryDatabasePath);
      final storageService = StorageService(prefs, dbHelper);
      final posProvider = PosProvider(storageService);

      // 1. Buat pesanan meja terbuka di PosProvider dengan DP 0 (menunggu verifikasi QRIS)
      final localOrder = await posProvider.createOpenTabDirectly(
        shiftId: 'shift_test',
        tableNo: 'Meja 03',
        customerName: 'Budi QRIS',
        items: [
          OrderItem(productId: 'm1', name: 'Nasi Goreng', price: 25000, qty: 2), // Total 50000
        ],
        onlineOrderId: 'ORD-QRIS-999',
        paidAmount: 0,
      );

      expect(localOrder.paidAmount, equals(0));
      expect(localOrder.total, equals(50000));

      // 2. Mock CloudSyncService yang mensimulasikan update payment status ke Firestore
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('table_orders/ORD-QRIS-999')) {
          return http.Response(jsonEncode({'name': request.url.path}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final syncService = CloudSyncService(client: mockClient);
      final onlineProvider = OnlineOrderProvider(syncService, soundService: SoundService());

      // 3. Verifikasi QRIS dieksekusi oleh kasir dengan menyertakan posProvider
      final verifySuccess = await onlineProvider.verifyQrisPayment(
        'ORD-QRIS-999',
        posProvider: posProvider,
      );

      expect(verifySuccess, isTrue);

      // 4. Verifikasi: Pesanan lokal di PosProvider kini berstatus LUNAS (paidAmount == total)
      final updatedOrder = posProvider.openOrders.firstWhere((o) => o.onlineOrderId == 'ORD-QRIS-999');
      expect(updatedOrder.paidAmount, equals(50000));
      expect(updatedOrder.paidAmount >= updatedOrder.total, isTrue); // Tamu tidak ditagih ulang di kasir!
    });

    test('3.2 Query Pesanan Hari Ini: fetchOnlineOrders memfilter pesanan yang dibuat hari ini dan mengabaikan pesanan kemarin', () async {
      final now = DateTime.now();
      final todayDocTime = DateTime(now.year, now.month, now.day, 10, 30).toIso8601String();
      final yesterdayDocTime = DateTime(now.year, now.month, now.day - 1, 14, 0).toIso8601String();

      // Mock Client Firestore yang mengembalikan respons runQuery dengan 2 dokumen (hari ini & kemarin)
      final mockClient = MockClient((request) async {
        if (request.url.path.contains(':runQuery')) {
          final queryResult = [
            {
              'document': {
                'name': 'projects/p/databases/(default)/documents/table_orders/ORD-TODAY-01',
                'fields': {
                  'orderId': {'stringValue': 'ORD-TODAY-01'},
                  'tableNo': {'stringValue': '02'},
                  'customerName': {'stringValue': 'Tamu Hari Ini'},
                  'totalAmount': {'integerValue': '35000'},
                  'status': {'stringValue': 'pending'},
                  'createdAt': {'stringValue': todayDocTime},
                  'items': {'arrayValue': {'values': []}},
                }
              }
            },
            {
              'document': {
                'name': 'projects/p/databases/(default)/documents/table_orders/ORD-YESTERDAY-02',
                'fields': {
                  'orderId': {'stringValue': 'ORD-YESTERDAY-02'},
                  'tableNo': {'stringValue': '09'},
                  'customerName': {'stringValue': 'Tamu Kemarin'},
                  'totalAmount': {'integerValue': '20000'},
                  'status': {'stringValue': 'completed'},
                  'createdAt': {'stringValue': yesterdayDocTime},
                  'items': {'arrayValue': {'values': []}},
                }
              }
            }
          ];
          return http.Response(jsonEncode(queryResult), 200);
        }
        return http.Response('Not Found', 404);
      });

      final syncService = CloudSyncService(client: mockClient);

      // Eksekusi fetchOnlineOrders untuk hari ini
      final orders = await syncService.fetchOnlineOrders();

      // Verifikasi: Hanya pesanan hari ini yang dikembalikan
      expect(orders.length, equals(1));
      expect(orders.first.orderId, equals('ORD-TODAY-01'));
      expect(orders.first.customerName, equals('Tamu Hari Ini'));
    });

    test('3.3 Multi-Tenant Resto Isolation: CloudSyncService mengarahkan koleksi ke /restos/{restoId} saat restoId dikonfigurasi', () async {
      final requestedUrls = <String>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response(jsonEncode({'name': request.url.path}), 200);
      });

      // Inisialisasi service dengan tenant kustom
      final syncService = CloudSyncService(
        projectId: 'resto-custom-project',
        apiKey: 'custom_key_123',
        restoId: 'warkop_berkah_01',
        client: mockClient,
      );

      // 1. Eksekusi update ketersediaan menu
      await syncService.syncMenuAvailability('p1', false);

      // Verifikasi URL mencakup namespace multi-tenant
      expect(requestedUrls.any((u) => u.contains('restos/warkop_berkah_01/resto_menu/p1')), isTrue);
      expect(requestedUrls.any((u) => u.contains('projects/resto-custom-project')), isTrue);

      // 2. Eksekusi markOrderAsPaid
      await syncService.markOrderAsPaid('ORD-123', 'qris');
      expect(requestedUrls.any((u) => u.contains('restos/warkop_berkah_01/table_orders/ORD-123')), isTrue);

      // 3. Eksekusi resolveTableCall
      await syncService.resolveTableCall('CALL-999');
      expect(requestedUrls.any((u) => u.contains('restos/warkop_berkah_01/table_calls/CALL-999')), isTrue);

      // 4. UpdateConfig beralih kembali ke default
      syncService.updateConfig(restoId: 'default');
      requestedUrls.clear();

      await syncService.syncMenuAvailability('p2', true);
      expect(requestedUrls.any((u) => u.contains('/resto_menu/p2') && !u.contains('restos/')), isTrue);
    });
  });
}

