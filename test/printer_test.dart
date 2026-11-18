import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mini_resto_pos/models/settings_model.dart';
import 'package:mini_resto_pos/providers/settings_provider.dart';
import 'package:mini_resto_pos/services/storage_service.dart';
import 'package:mini_resto_pos/services/printer_receipt_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Pengujian PrinterReceiptService & Format Struk Thermal', () {
    test('Lebar kolom thermal harus 32 untuk 58mm dan 48 untuk 80mm', () {
      expect(PrinterReceiptService.getColumnWidth('58mm'), 32);
      expect(PrinterReceiptService.getColumnWidth('80mm'), 48);
    });

    test('Helper twoColumnText meratakan teks kiri dan kanan dengan presisi', () {
      final line58 = PrinterReceiptService.twoColumnText('Total:', 'Rp 50.000', 32);
      expect(line58.length, 32);
      expect(line58.startsWith('Total:'), isTrue);
      expect(line58.endsWith('Rp 50.000'), isTrue);

      final line80 = PrinterReceiptService.twoColumnText('Total Tagihan:', 'Rp 150.000', 48);
      expect(line80.length, 48);
      expect(line80.startsWith('Total Tagihan:'), isTrue);
      expect(line80.endsWith('Rp 150.000'), isTrue);
    });

    test('buildTextReceipt menghasilkan format struk thermal kasir yang lengkap', () {
      final settings = SettingsModel(
        storeName: 'Resto Digital',
        address: 'Jl. Merdeka No. 45',
        phoneWA: '081234567890',
        paperSize: '58mm',
        receiptHeader: 'Selamat Menikmati Hidangan',
        receiptFooter: 'Terima kasih atas kunjungannya',
        showCashierName: true,
        showCustomerInfo: true,
        showOrderNotes: true,
        showQrFooter: true,
      );

      final sampleOrder = PrinterReceiptService.generateSampleOrder();
      final receiptText = PrinterReceiptService.buildTextReceipt(
        settings: settings,
        order: sampleOrder,
        receiptNo: 'TRX-1001',
        orderTime: DateTime(2026, 11, 17, 12, 30),
        cashierName: 'Budi Kasir',
        paymentMethod: 'Tunai',
        amountPaid: 100000,
        change: 23000,
      );

      expect(receiptText.contains('RESTO DIGITAL'), isTrue);
      expect(receiptText.contains('TRX-1001'), isTrue);
      expect(receiptText.contains('Budi Kasir'), isTrue);
      expect(receiptText.contains('Nasi Goreng Spesial Resto'), isTrue);
      expect(receiptText.contains('Pedas sedang'), isTrue);
      expect(receiptText.contains('Terima kasih atas kunjungannya'), isTrue);
    });

    test('buildHtmlReceipt menghasilkan markup HTML thermal siap cetak', () {
      final settings = SettingsModel(paperSize: '58mm');
      final sampleOrder = PrinterReceiptService.generateSampleOrder();

      final html = PrinterReceiptService.buildHtmlReceipt(
        settings: settings,
        order: sampleOrder,
        receiptNo: 'TRX-2002',
        orderTime: DateTime.now(),
        cashierName: 'Siti Kasir',
        paymentMethod: 'QRIS',
        amountPaid: 77000,
        change: 0,
      );

      expect(html.contains('58mm auto'), isTrue);
      expect(html.contains('Nasi Goreng Spesial Resto'), isTrue);
      expect(html.contains('#TRX-2002'), isTrue);
      expect(html.contains('QRIS'), isTrue);
    });
  });

  group('Pengujian SettingsProvider - Konfigurasi Printer & Struk', () {
    test('updatePrinterReceiptSettings berhasil memperbarui state dan persisten', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final provider = SettingsProvider(storage);

      expect(provider.settings.paperSize, '58mm');
      expect(provider.settings.printerType, 'browser');

      await provider.updatePrinterReceiptSettings(
        printerType: 'bluetooth',
        paperSize: '80mm',
        printerName: 'Epson TM-T82',
        printerIpAddress: '192.168.1.150',
        printerPort: 9100,
        autoPrintReceipt: true,
        autoPrintKitchen: true,
        autoCut: true,
        numberOfCopies: 2,
        receiptHeader: 'Restoran Keluarga Terbaik',
        receiptFooter: 'Sampai Jumpa Kembali!',
        showCustomerInfo: true,
        showCashierName: true,
        showOrderNotes: true,
        showQrFooter: true,
      );

      expect(provider.settings.paperSize, '80mm');
      expect(provider.settings.printerType, 'bluetooth');
      expect(provider.settings.printerName, 'Epson TM-T82');
      expect(provider.settings.autoPrintReceipt, isTrue);
      expect(provider.settings.numberOfCopies, 2);
      expect(provider.settings.receiptHeader, 'Restoran Keluarga Terbaik');
    });
  });
}
