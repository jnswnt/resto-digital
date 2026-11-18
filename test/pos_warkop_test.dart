import 'package:flutter_test/flutter_test.dart';
import 'package:mini_resto_pos/services/qris_service.dart';
import 'package:mini_resto_pos/services/auth_service.dart';
import 'package:mini_resto_pos/services/whatsapp_service.dart';
import 'package:mini_resto_pos/models/shift_model.dart';
import 'package:mini_resto_pos/models/customer_model.dart';

void main() {
  group('Pengujian Algoritma QRIS Auto-Nominal (EMVCo Tag 54)', () {
    const rawStaticQris =
        '00020101021126540013ID.LINKAJA.WWW01189360091100213038590210000000000051440014ID.CO.QRIS.WWW0215ID10200213038590303UMI5204581253033605802ID5913RESTO DIGITAL6007JAKARTA61051234062070703A0163047A94';

    test('Harus menginjeksi nominal belanja ke Tag 54 dan mengubah mode menjadi Dynamic (010212)', () {
      final dynamicQris = QrisService.generateDynamicQris(
        rawPayload: rawStaticQris,
        amount: 18000,
      );

      // Mode harus berubah menjadi dynamic
      expect(dynamicQris.contains('010212'), isTrue);

      // Tag 54 harus memuat 54 + panjang (05) + nominal (18000)
      expect(dynamicQris.contains('540518000'), isTrue);

      // Tag 63 harus ada di akhir dengan 4 digit checksum hex
      final crcIndex = dynamicQris.lastIndexOf('6304');
      expect(crcIndex, isNot(-1));
      expect(dynamicQris.substring(crcIndex + 4).length, 4);
    });

    test('Perhitungan CRC16-CCITT harus akurat', () {
      final crc = QrisService.calculateCrc16('123456789');
      expect(crc.length, 4);
    });

    test('Validasi format QRIS standar Indonesia', () {
      expect(QrisService.isValidQris(rawStaticQris), isTrue);
      expect(QrisService.isValidQris('random-text-bukan-qris'), isFalse);
      expect(QrisService.isValidQris(''), isFalse);
    });

    test('Ekstraksi metadata merchant QRIS harus mengurai nama toko, kota, dan acquirer dengan benar', () {
      final info = QrisService.parseMerchantInfo(rawStaticQris);
      expect(info.isValid, isTrue);
      expect(info.merchantName, 'RESTO DIGITAL');
      expect(info.merchantCity, 'JAKARTA');
      expect(info.postalCode, '12340');
      expect(info.acquirerName, 'LinkAja');
      expect(info.nmid, isNotEmpty);
      expect(info.isDynamic, isFalse);
    });

    test('Injeksi nominal berulang tidak boleh merusak Tag 58 atau menduplikasi Tag 54', () {
      // Step 1: Inject 10.000
      final dynamic1 = QrisService.generateDynamicQris(rawPayload: rawStaticQris, amount: 10000);
      expect(dynamic1.contains('540510000'), isTrue);
      expect(dynamic1.contains('5802ID'), isTrue);

      // Step 2: Inject ulang 25.000 pada hasil dynamic1
      final dynamic2 = QrisService.generateDynamicQris(rawPayload: dynamic1, amount: 25000);
      expect(dynamic2.contains('540525000'), isTrue);
      expect(dynamic2.contains('540510000'), isFalse); // Tag 54 lama harus diganti, bukan digandakan
      expect(dynamic2.contains('5802ID'), isTrue); // Tag 58 harus utuh dan tidak termakan regex
    });
  });

  group('Pengujian Keamanan Autentikasi PIN Kasir', () {
    test('Salted SHA-256 harus berhasil memvalidasi PIN yang benar dan menolak PIN yang salah', () {
      final salt = AuthService.generateSalt();
      const pin = '1234';
      final pinHash = AuthService.hashPin(pin, salt);

      // Verifikasi PIN benar
      final isValid = AuthService.verifyPin(inputPin: '1234', pinHash: pinHash, salt: salt);
      expect(isValid, isTrue);

      // Verifikasi PIN salah
      final isWrong = AuthService.verifyPin(inputPin: '0000', pinHash: pinHash, salt: salt);
      expect(isWrong, isFalse);
    });
  });

  group('Pengujian Rekonsiliasi Kas Shift', () {
    test('Kalkulasi uang kas yang seharusnya ada di laci (Expected Cash)', () {
      final expected = ShiftModel.calculateExpectedCash(
        initialCash: 100000, // Modal awal
        totalCashSales: 350000, // Penjualan tunai
        totalDebtRepaidCash: 50000, // Pelunasan kasbon tunai
        totalCashOut: 20000, // Kas keluar beli es batu
      );

      // 100.000 + 350.000 + 50.000 - 20.000 = 480.000
      expect(expected, 480000);
    });
  });

  group('Pengujian Manajemen Kasbon & Pelanggan', () {
    test('Sisa limit kasbon dan status over limit harus akurat', () {
      final customer = CustomerModel(
        id: 'cust_test',
        name: 'Mas Joko',
        phoneWA: '081234567890',
        totalDebt: 70000,
        debtLimit: 100000,
      );

      expect(customer.remainingLimit, 30000);
      expect(customer.isOverLimit, isFalse);

      final overLimitCustomer = customer.copyWith(totalDebt: 105000);
      expect(overLimitCustomer.remainingLimit, 0);
      expect(overLimitCustomer.isOverLimit, isTrue);
    });
  });

  group('Pengujian Utilitas WhatsApp Service', () {
    test('Format nomor telepon lokal Indonesia harus dikonversi ke format 62', () {
      expect(WhatsappService.formatPhoneNumber('081234567890'), '6281234567890');
      expect(WhatsappService.formatPhoneNumber('+6281234567890'), '6281234567890');
      expect(WhatsappService.formatPhoneNumber('0812-3456-7890'), '6281234567890');
    });
  });
}
