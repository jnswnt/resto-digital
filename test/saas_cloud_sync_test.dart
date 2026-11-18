import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_resto_pos/services/cloud_sync_service.dart';

void main() {
  test('CloudSyncService berhasil mengambil pesanan dari SaaS Backend', () async {
    final syncService = CloudSyncService(restoId: 'default');
    final orders = await syncService.fetchOnlineOrders();
    debugPrint('Jumlah pesanan online yang didapat: ${orders.length}');
    for (final o in orders) {
      debugPrint('Order: ${o.orderId} | Meja: ${o.tableNo} | Customer: ${o.customerName} | Total: ${o.totalAmount}');
    }
    expect(orders, isNotEmpty);
  });
}
