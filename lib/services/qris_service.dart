import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';

/// Data hasil ekstraksi metadata QRIS resto (Standar EMVCo / QRIS Indonesia).
class QrisMerchantInfo {
  final String merchantName;
  final String merchantCity;
  final String postalCode;
  final String acquirerName;
  final String nmid;
  final bool isDynamic;
  final bool isValid;
  final String rawPayload;
  final String? errorMessage;

  const QrisMerchantInfo({
    this.merchantName = '',
    this.merchantCity = '',
    this.postalCode = '',
    this.acquirerName = '',
    this.nmid = '',
    this.isDynamic = false,
    this.isValid = false,
    this.rawPayload = '',
    this.errorMessage,
  });
}

/// Representasi elemen Tag-Length-Value (TLV) standar EMVCo.
class QrisTlv {
  final String tag;
  final int length;
  final String value;
  final int startIndex;
  final int endIndex;

  const QrisTlv({
    required this.tag,
    required this.length,
    required this.value,
    required this.startIndex,
    required this.endIndex,
  });
}

/// LuminanceSource efisien berbasis package:image untuk ZXing decoder
class _ImageLuminanceSource extends LuminanceSource {
  final Uint8List _buffer;

  _ImageLuminanceSource.fromImage(img.Image image)
      : _buffer = Uint8List(image.width * image.height),
        super(image.width, image.height) {
    final w = image.width;
    final h = image.height;
    final pixel = image.getPixel(0, 0);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        image.getPixel(x, y, pixel);
        if (image.numChannels > 3 && pixel.a == 0) {
          _buffer[y * w + x] = 255;
        } else if (image.numChannels == 1) {
          _buffer[y * w + x] = (pixel.rNormalized * 255).round();
        } else {
          _buffer[y * w + x] = (pixel.luminanceNormalized * 255).round();
        }
      }
    }
  }

  @override
  Uint8List getRow(int y, Uint8List? row) {
    if (y < 0 || y >= height) throw ArgumentError('Row out of bounds: $y');
    final r = (row == null || row.length < width) ? Uint8List(width) : row;
    List.copyRange(r, 0, _buffer, y * width, (y + 1) * width);
    return r;
  }

  @override
  Uint8List get matrix => Uint8List.fromList(_buffer);
}

/// Layanan untuk validasi, decoding dari gambar, ekstraksi metadata,
/// dan konversi string QRIS statis resto menjadi QRIS dinamis otomatis (Tag 54).
class QrisService {
  /// Menghitung CRC16-CCITT (Polynomial 0x1021, Initial Value 0xFFFF).
  static String calculateCrc16(String input) {
    int crc = 0xFFFF;
    final bytes = input.codeUnits;

    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Mengurai string payload QRIS menjadi daftar elemen TLV level utama.
  static List<QrisTlv> parseTlvs(String payload) {
    final List<QrisTlv> tlvs = [];
    int index = 0;
    while (index + 4 <= payload.length) {
      final tag = payload.substring(index, index + 2);
      final lenStr = payload.substring(index + 2, index + 4);
      final len = int.tryParse(lenStr);
      if (len == null || index + 4 + len > payload.length) {
        break;
      }
      final val = payload.substring(index + 4, index + 4 + len);
      tlvs.add(QrisTlv(
        tag: tag,
        length: len,
        value: val,
        startIndex: index,
        endIndex: index + 4 + len,
      ));
      index += 4 + len;
    }
    return tlvs;
  }

  /// Mencari nilai tag tertentu dalam daftar TLV string payload.
  static String? findTagValue(String payload, String targetTag) {
    final tlvs = parseTlvs(payload);
    for (final tlv in tlvs) {
      if (tlv.tag == targetTag) {
        return tlv.value;
      }
    }
    return null;
  }

  /// Memverifikasi apakah string [rawPayload] memenuhi spesifikasi dasar QRIS Indonesia:
  /// 1. Diawali Format Indicator Tag 00 ('000201')
  /// 2. Memuat Tag 58 Country Code ('5802ID' atau Tag 58 = 'ID')
  /// 3. Memuat Tag 53 Currency Code ('5303360' atau Tag 53 = '360')
  static bool isValidQris(String rawPayload) {
    final clean = rawPayload.trim();
    if (clean.length < 20 || !clean.startsWith('000201')) {
      return false;
    }

    final hasCountry = clean.contains('5802ID') || findTagValue(clean, '58')?.toUpperCase() == 'ID';
    final hasCurrency = clean.contains('5303360') || findTagValue(clean, '53') == '360';
    final hasMerchantAccount = clean.contains('ID.CO.QRIS') ||
        clean.contains('ID.LINKAJA') ||
        clean.contains('GO-PAY') ||
        clean.contains('GOPAY') ||
        clean.contains('BCA') ||
        clean.contains('UMI') ||
        RegExp(r'(2[6-9]|3[0-9]|4[0-9]|5[0-1])\d{2}').hasMatch(clean);

    return hasCountry && hasCurrency && hasMerchantAccount;
  }

  /// Mengekstrak informasi nama resto, kota, acquirer, dan NMID dari payload QRIS.
  static QrisMerchantInfo parseMerchantInfo(String rawPayload) {
    final clean = rawPayload.trim();
    if (clean.isEmpty) {
      return const QrisMerchantInfo(
        errorMessage: 'Payload QRIS kosong',
      );
    }

    if (!isValidQris(clean)) {
      return QrisMerchantInfo(
        rawPayload: clean,
        isValid: false,
        errorMessage: 'Format QRIS tidak memenuhi standar nasional Indonesia (EMVCo/QRIS)',
      );
    }

    // Ekstraksi nilai tag penting
    final tag01 = findTagValue(clean, '01');
    final isDynamic = tag01 == '12';

    String merchantName = findTagValue(clean, '59')?.trim() ?? '';
    String merchantCity = findTagValue(clean, '60')?.trim() ?? '';
    String postalCode = findTagValue(clean, '61')?.trim() ?? '';

    // Deteksi nama acquirer/bank penyedia
    String acquirer = '';
    final upper = clean.toUpperCase();
    if (upper.contains('LINKAJA')) {
      acquirer = 'LinkAja';
    } else if (upper.contains('GO-PAY') || upper.contains('GOPAY')) {
      acquirer = 'GoPay';
    } else if (upper.contains('BCA')) {
      acquirer = 'BCA';
    } else if (upper.contains('MANDIRI')) {
      acquirer = 'Bank Mandiri';
    } else if (upper.contains('BRI')) {
      acquirer = 'BRI';
    } else if (upper.contains('BNI')) {
      acquirer = 'BNI';
    } else if (upper.contains('SHOPEE')) {
      acquirer = 'ShopeePay';
    } else if (upper.contains('DANA')) {
      acquirer = 'DANA';
    } else if (upper.contains('OVO')) {
      acquirer = 'OVO';
    } else if (upper.contains('NOBU')) {
      acquirer = 'Nobu Bank';
    } else {
      acquirer = 'QRIS Nasional (NMID)';
    }

    // Cari NMID jika ada (biasanya diawali ID10...)
    String nmid = '';
    final nmidMatch = RegExp(r'ID\d{11,15}').firstMatch(clean);
    if (nmidMatch != null) {
      nmid = nmidMatch.group(0) ?? '';
    }

    return QrisMerchantInfo(
      merchantName: merchantName.isNotEmpty ? merchantName : 'Resto (Nama Tidak Tertera)',
      merchantCity: merchantCity.isNotEmpty ? merchantCity : 'Indonesia',
      postalCode: postalCode,
      acquirerName: acquirer,
      nmid: nmid,
      isDynamic: isDynamic,
      isValid: true,
      rawPayload: clean,
    );
  }

  static String? _tryDecodeZxing(img.Image image) {
    final source = _ImageLuminanceSource.fromImage(image);
    final reader = MultiFormatReader();
    final hint = DecodeHint(
      possibleFormats: [BarcodeFormat.qrCode],
      tryHarder: true,
    );

    // 1. Coba HybridBinarizer (standar cepat & adaptif)
    try {
      final res = reader.decode(BinaryBitmap(HybridBinarizer(source)), hint);
      if (res.text.isNotEmpty) return res.text;
    } catch (_) {}

    // 2. Coba GlobalHistogramBinarizer (fallback jika kontras tidak merata / inverted)
    try {
      final res = reader.decode(
        BinaryBitmap(GlobalHistogramBinarizer(source)),
        DecodeHint(
          possibleFormats: [BarcodeFormat.qrCode],
          tryHarder: true,
          alsoInverted: true,
        ),
      );
      if (res.text.isNotEmpty) return res.text;
    } catch (_) {}

    return null;
  }

  /// Mendekode QR Code dari bytes file gambar menggunakan multi-pass adaptive pipeline.
  /// Mampu mendeteksi foto resolusi tinggi kamera HP, poster kasir, maupun screenshot e-wallet.
  static Future<String?> decodeQrFromImageBytes(Uint8List imageBytes) async {
    try {
      final origImage = img.decodeImage(imageBytes);
      if (origImage == null) return null;

      // Pass 1: Gambar asli
      final res1 = _tryDecodeZxing(origImage);
      if (res1 != null && res1.isNotEmpty) return res1.trim();

      // Pass 2: Downscaled ke resolusi optimal 1000px (mengatasi kamera HP 12MP/50MP)
      final maxDim = origImage.width > origImage.height ? origImage.width : origImage.height;
      if (maxDim > 1000) {
        final scale = 1000 / maxDim;
        final resized1000 = img.copyResize(
          origImage,
          width: (origImage.width * scale).round(),
          height: (origImage.height * scale).round(),
        );
        final res2 = _tryDecodeZxing(resized1000);
        if (res2 != null && res2.isNotEmpty) return res2.trim();
      }

      // Pass 3: Downscaled ke 650px (jika gambar QR memiliki modul kecil/noise)
      if (maxDim > 650) {
        final scale = 650 / maxDim;
        final resized650 = img.copyResize(
          origImage,
          width: (origImage.width * scale).round(),
          height: (origImage.height * scale).round(),
        );
        final res3 = _tryDecodeZxing(resized650);
        if (res3 != null && res3.isNotEmpty) return res3.trim();
      }

      // Pass 4: Crop area tengah 75% (menghilangkan border/header/footer poster akrilik kasir)
      if (origImage.width > 250 && origImage.height > 250) {
        final cropW = (origImage.width * 0.75).round();
        final cropH = (origImage.height * 0.75).round();
        final cropX = (origImage.width - cropW) ~/ 2;
        final cropY = (origImage.height - cropH) ~/ 2;
        final centerCrop = img.copyCrop(origImage, x: cropX, y: cropY, width: cropW, height: cropH);
        final res4 = _tryDecodeZxing(centerCrop);
        if (res4 != null && res4.isNotEmpty) return res4.trim();
      }

      // Pass 5: Rotasi 90, 180, 270 (jika foto miring atau EXIF orientation kamera terabaikan)
      for (final angle in [90, 180, 270]) {
        final rotated = img.copyRotate(origImage, angle: angle);
        final resRot = _tryDecodeZxing(rotated);
        if (resRot != null && resRot.isNotEmpty) return resRot.trim();
      }

      // Pass 6: Penyesuaian kontras tinggi & Grayscale
      final contrastImg = img.adjustColor(img.grayscale(origImage), contrast: 1.35);
      final resContrast = _tryDecodeZxing(contrastImg);
      if (resContrast != null && resContrast.isNotEmpty) return resContrast.trim();
    } catch (e) {
      debugPrint('QrisService: Gagal membaca QR dari gambar: $e');
    }
    return null;
  }

  /// Menghapus Tag 54 lama tanpa merusak tag numerik di sebelahnya (aman dari greedy regex).
  static String _removeExistingTag54(String payload) {
    int idx = 0;
    while (true) {
      idx = payload.indexOf('54', idx);
      if (idx == -1) break;

      // Pastikan ada cukup karakter untuk 2 digit length
      if (idx + 4 <= payload.length) {
        final lenStr = payload.substring(idx + 2, idx + 4);
        final len = int.tryParse(lenStr);
        if (len != null && len > 0 && idx + 4 + len <= payload.length) {
          final val = payload.substring(idx + 4, idx + 4 + len);
          // Tag 54 adalah nominal, harus berupa digit angka bulat/desimal
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(val)) {
            return payload.substring(0, idx) + payload.substring(idx + 4 + len);
          }
        }
      }
      idx += 2;
    }
    return payload;
  }

  /// Menginjeksi nominal belanja [amount] ke dalam payload string [rawPayload].
  /// Mengubah Point of Initiation Method menjadi Dynamic (010212)
  /// dan menyisipkan Tag 54 (Transaction Amount) menggunakan manipulasi TLV yang aman.
  static String generateDynamicQris({
    required String rawPayload,
    required int amount,
  }) {
    if (rawPayload.isEmpty || amount <= 0) {
      return rawPayload;
    }

    String payload = rawPayload.trim();

    // 1. Buang tag CRC 63 yang ada di akhir (format '6304xxxx')
    final crcIndex = payload.lastIndexOf('6304');
    if (crcIndex != -1 && (payload.length - crcIndex) <= 10) {
      payload = payload.substring(0, crcIndex);
    }

    // 2. Ubah mode dari Static (010211) menjadi Dynamic (010212)
    if (payload.contains('010211')) {
      payload = payload.replaceFirst('010211', '010212');
    } else if (!payload.contains('010212') && payload.startsWith('000201')) {
      // Sisipkan Tag 01 jika belum ada
      payload = '000201010212${payload.substring(6)}';
    }

    // 3. Buang Tag 54 lama dengan aman
    payload = _removeExistingTag54(payload);

    // 4. Siapkan Tag 54 baru dengan nominal pesanan
    final amountStr = amount.toString();
    final amountLength = amountStr.length.toString().padLeft(2, '0');
    final tag54String = '54$amountLength$amountStr';

    // 5. Sisipkan Tag 54 sebelum Tag 58 (Country Code '5802ID')
    const tag58 = '5802ID';
    final tag58Index = payload.indexOf(tag58);

    if (tag58Index != -1) {
      payload = payload.substring(0, tag58Index) + tag54String + payload.substring(tag58Index);
    } else {
      // Jika Tag 5802ID tidak tepat ada, cari Tag 5802
      final tag58Short = payload.indexOf('5802');
      if (tag58Short != -1) {
        payload = payload.substring(0, tag58Short) + tag54String + payload.substring(tag58Short);
      } else {
        payload = payload + tag54String;
      }
    }

    // 6. Tambahkan prefix Tag 63 ('6304') untuk kalkulasi checksum baru
    final stringToCrc = '${payload}6304';
    final newCrc = calculateCrc16(stringToCrc);

    return '$stringToCrc$newCrc';
  }
}
