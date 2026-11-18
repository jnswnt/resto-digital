import 'package:intl/intl.dart';
import '../models/order_model.dart';

/// Layanan Pembuatan Tiket Pesanan Dapur (Kitchen Order Ticket / KOT).
/// Mengonversi pesanan meja menjadi format teks struk thermal khusus koki dapur.
class KitchenTicketService {
  /// Menghasilkan format teks struk KOT 58mm / 80mm yang bersih dan mudah dibaca koki
  static String buildKitchenTicketText({
    required String tableNo,
    required String customerName,
    required List<OrderItem> items,
    String? orderId,
    DateTime? orderTime,
    bool isAdditionalOrder = false,
    int? roundNumber,
  }) {
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(orderTime ?? DateTime.now());
    final tableLabel = tableNo.startsWith('Meja') ? tableNo.toUpperCase() : 'MEJA $tableNo'.toUpperCase();

    final buffer = StringBuffer();

    buffer.writeln('================================');
    buffer.writeln('     TIKET DAPUR / KOT          ');
    if (isAdditionalOrder || (roundNumber != null && roundNumber > 1)) {
      buffer.writeln('  ** PESANAN TAMBAHAN (ROUND ${roundNumber ?? 2}) **');
    }
    buffer.writeln('================================');
    buffer.writeln('LOKASI : $tableLabel');
    buffer.writeln('TAMU   : $customerName');
    buffer.writeln('WAKTU  : $timeStr');
    if (orderId != null && orderId.isNotEmpty) {
      buffer.writeln('REF ID : #$orderId');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('QTY  ITEM & CATATAN KHUSUS      ');
    buffer.writeln('--------------------------------');

    for (final item in items) {
      buffer.writeln('${item.qty.toString().padRight(4)} ${item.name}');
      if (item.notes.isNotEmpty) {
        buffer.writeln('     >> [RASA: ${item.notes.toUpperCase()}]');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL: ${items.fold(0, (sum, i) => sum + i.qty)} PORSI/ITEM');
    buffer.writeln('================================');
    buffer.writeln('       SEGERA DIMASAK           ');
    buffer.writeln('================================\n\n');

    return buffer.toString();
  }
}
