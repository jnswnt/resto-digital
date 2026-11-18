import 'package:flutter/foundation.dart';

/// Implementasi printer thermal untuk platform native (Android, Windows, Linux, macOS).
/// Pada perangkat fisik yang belum memiliki driver Bluetooth langsung,
/// ini mencatat payload struk dan membiarkan dialog preview cetak menangani interaksi.
void printThermalHtmlCrossPlatform(String htmlContent) {
  debugPrint('[PrinterIO] Struk thermal siap dicetak (${htmlContent.length} karakter).');
}
