import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/storage_service.dart';

/// Provider Manajemen Kasbon & Pelanggan Resto.
/// Menangani pencatatan piutang baru, validasi limit kasbon,
/// dan pembayaran cicilan / pelunasan kasbon.
class CustomerDebtProvider with ChangeNotifier {
  final StorageService _storageService;
  final _uuid = const Uuid();

  List<CustomerModel> _customers = [];
  String _searchQuery = '';

  CustomerDebtProvider(this._storageService) {
    loadCustomers();
  }

  List<CustomerModel> get customers => List.unmodifiable(_customers);
  String get searchQuery => _searchQuery;

  void loadCustomers() {
    _customers = _storageService.getCustomers();
    notifyListeners();
  }

  /// Total akumulasi seluruh piutang kasbon di resto
  int get totalAllDebts =>
      _customers.fold(0, (sum, cust) => sum + cust.totalDebt);

  /// Pelanggan yang memiliki saldo kasbon (> 0), diurutkan dari utang terbesar
  List<CustomerModel> get debtors {
    final list = _customers.where((c) => c.totalDebt > 0).toList();
    list.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
    return list;
  }

  /// Hasil pencarian pelanggan berdasarkan nama atau nomor telepon
  List<CustomerModel> get filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    final query = _searchQuery.toLowerCase();
    return _customers.where((c) {
      return c.name.toLowerCase().contains(query) || c.phoneWA.contains(query);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Menambah pelanggan baru
  Future<CustomerModel> addCustomer({
    required String name,
    required String phoneWA,
    int debtLimit = 100000,
  }) async {
    final newCust = CustomerModel(
      id: 'cust_${_uuid.v4().substring(0, 8)}',
      name: name,
      phoneWA: phoneWA,
      totalDebt: 0,
      debtLimit: debtLimit,
      createdAt: DateTime.now(),
    );

    _customers.add(newCust);
    await _storageService.saveCustomers(_customers);
    notifyListeners();
    return newCust;
  }

  /// Memperbarui informasi pelanggan
  Future<void> updateCustomer(CustomerModel updated) async {
    final index = _customers.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      _customers[index] = updated;
      await _storageService.saveCustomers(_customers);
      notifyListeners();
    }
  }

  /// Menghapus pelanggan (hanya jika total kasbon sudah nol)
  Future<bool> deleteCustomer(String customerId) async {
    final cust = _customers.firstWhere((c) => c.id == customerId, orElse: () => CustomerModel(id: '', name: '', phoneWA: ''));
    if (cust.id.isEmpty || cust.totalDebt > 0) {
      return false; // Tidak bisa menghapus pelanggan yang masih memiliki utang
    }

    _customers.removeWhere((c) => c.id == customerId);
    await _storageService.saveCustomers(_customers);
    notifyListeners();
    return true;
  }

  /// Memeriksa apakah pelanggan dapat mengambil kasbon sejumlah [amount]
  bool canTakeDebt(String customerId, int amount) {
    final cust = _customers.firstWhere(
      (c) => c.id == customerId,
      orElse: () => CustomerModel(id: '', name: '', phoneWA: ''),
    );
    if (cust.id.isEmpty) return false;
    return (cust.totalDebt + amount) <= cust.debtLimit;
  }

  /// Mencatat kasbon baru pada transaksi belanja
  Future<void> recordNewDebt({
    required String customerId,
    required int amount,
    required String orderId,
  }) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index >= 0) {
      final cust = _customers[index];
      _customers[index] = cust.copyWith(
        totalDebt: cust.totalDebt + amount,
      );
      await _storageService.saveCustomers(_customers);
      notifyListeners();
    }
  }

  /// Mencatat pembayaran cicilan atau pelunasan kasbon pelanggan
  Future<void> repayDebt({
    required String customerId,
    required int amountPaid,
  }) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index >= 0) {
      final cust = _customers[index];
      final newDebt = (cust.totalDebt - amountPaid).clamp(0, 999999999);
      _customers[index] = cust.copyWith(totalDebt: newDebt);
      await _storageService.saveCustomers(_customers);
      notifyListeners();
    }
  }
}
