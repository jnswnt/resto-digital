import 'dart:js_interop';

@JS('window.printThermalHtml')
external void _printThermalHtmlJS(JSString content);

/// Implementasi printer thermal untuk platform Flutter Web.
/// Memanggil fungsi JavaScript global untuk memicu dialog cetak printer thermal sistem browser.
void printThermalHtmlCrossPlatform(String htmlContent) {
  try {
    _printThermalHtmlJS(htmlContent.toJS);
  } catch (e) {
    // Abaikan jika pemanggilan JS gagal atau window ditolak browser
  }
}
