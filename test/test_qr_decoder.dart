import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:mini_resto_pos/services/qris_service.dart';

void main() {
  test('Test decoding rendered QR dengan QrisService multi-pass decoder', () async {
    const testPayload =
        '00020101021126540013ID.LINKAJA.WWW01189360091100213038590210000000000051440014ID.CO.QRIS.WWW0215ID10200213038590303UMI5204581253033605802ID5913RESTO DIGITAL6007JAKARTA61051234062070703A0163047A94';

    final painter = QrPainter(
      data: testPayload,
      version: QrVersions.auto,
      gapless: true,
    );

    final image = await painter.toImage(500);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // 1. Decode gambar QR murni
    final decoded = await QrisService.decodeQrFromImageBytes(pngBytes);
    expect(decoded, testPayload);

    // 2. Simulasi foto poster kasir (QR di tengah dengan frame / padding)
    final decodedImg = img.decodeImage(pngBytes)!;
    final poster = img.Image(width: 1000, height: 1400);
    img.fill(poster, color: img.ColorRgb8(240, 240, 240));
    img.compositeImage(poster, decodedImg, dstX: 250, dstY: 450);

    final posterBytes = Uint8List.fromList(img.encodePng(poster));
    final decodedPoster = await QrisService.decodeQrFromImageBytes(posterBytes);
    expect(decodedPoster, testPayload);
  });
}
