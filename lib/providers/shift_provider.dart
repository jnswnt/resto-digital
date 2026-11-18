import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/shift_model.dart';
import '../models/cash_movement_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

/// Provider Manajemen Shift Kasir & Arus Kas Laci.
/// Mengelola modal awal, penjualan, petty cash (kas keluar beli es/galon),
/// dan rekonsiliasi kas saat tutup shift.
class ShiftProvider with ChangeNotifier {
  final StorageService _storageService;
  final _uuid = const Uuid();

  ShiftModel? _activeShift;
  List<CashMovementModel> _cashMovements = [];

  ShiftProvider(this._storageService) {
    loadActiveShift();
  }

  ShiftModel? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift != null && _activeShift!.status == 'open';
  List<CashMovementModel> get cashMovements => List.unmodifiable(_cashMovements);

  /// Memuat shift aktif dari penyimpanan lokal
  void loadActiveShift() {
    final activeId = _storageService.getActiveShiftId();
    if (activeId != null) {
      final shifts = _storageService.getShifts();
      final found = shifts.firstWhere(
        (s) => s.id == activeId && s.status == 'open',
        orElse: () => ShiftModel(
          id: '',
          userId: '',
          cashierName: '',
          startedAt: DateTime.now(),
          initialCash: 0,
        ),
      );

      if (found.id.isNotEmpty) {
        _activeShift = found;
        _loadMovementsForShift(found.id);
      } else {
        _activeShift = null;
      }
    } else {
      _activeShift = null;
    }
    notifyListeners();
  }

  void _loadMovementsForShift(String shiftId) {
    final allMovements = _storageService.getCashMovements();
    _cashMovements = allMovements.where((m) => m.shiftId == shiftId).toList();
  }

  /// Membuka shift baru dengan menginput modal awal kasir
  Future<ShiftModel> startShift({
    required UserModel cashier,
    required int initialCash,
  }) async {
    final shiftId = 'shift_${DateTime.now().millisecondsSinceEpoch}';
    final newShift = ShiftModel(
      id: shiftId,
      userId: cashier.id,
      cashierName: cashier.name,
      startedAt: DateTime.now(),
      initialCash: initialCash,
      expectedCash: initialCash,
      status: 'open',
    );

    final shifts = _storageService.getShifts();
    shifts.add(newShift);
    await _storageService.saveShifts(shifts);
    await _storageService.setActiveShiftId(shiftId);

    _activeShift = newShift;
    _cashMovements = [];
    notifyListeners();
    return newShift;
  }

  /// Mencatat penjualan tunai masuk ke laci
  Future<void> recordCashSale(int amount) async {
    if (_activeShift == null) return;
    final updated = _activeShift!.copyWith(
      totalCashSales: _activeShift!.totalCashSales + amount,
      expectedCash: _activeShift!.expectedCash + amount,
    );
    await _updateCurrentShift(updated);
  }

  /// Mencatat penjualan non-tunai QRIS
  Future<void> recordQrisSale(int amount) async {
    if (_activeShift == null) return;
    final updated = _activeShift!.copyWith(
      totalQrisSales: _activeShift!.totalQrisSales + amount,
    );
    await _updateCurrentShift(updated);
  }

  /// Mencatat penjualan transaksi kasbon
  Future<void> recordDebtSale(int amount) async {
    if (_activeShift == null) return;
    final updated = _activeShift!.copyWith(
      totalDebtSales: _activeShift!.totalDebtSales + amount,
    );
    await _updateCurrentShift(updated);
  }

  /// Mencatat penerimaan uang tunai dari pelunasan kasbon pelanggan
  Future<void> recordDebtRepaidCash(int amount) async {
    if (_activeShift == null) return;
    final updated = _activeShift!.copyWith(
      totalDebtRepaidCash: _activeShift!.totalDebtRepaidCash + amount,
      expectedCash: _activeShift!.expectedCash + amount,
    );
    await _updateCurrentShift(updated);
  }

  /// Mencatat pengeluaran uang kas laci (Petty Cash: beli es batu, gas, galon)
  Future<void> recordPettyCashOut({
    required int amount,
    required String notes,
  }) async {
    if (_activeShift == null) return;

    // 1. Simpan catatan mutasi
    final movement = CashMovementModel(
      id: 'mov_${_uuid.v4().substring(0, 8)}',
      shiftId: _activeShift!.id,
      userId: _activeShift!.userId,
      cashierName: _activeShift!.cashierName,
      type: 'out',
      amount: amount,
      notes: notes,
      timestamp: DateTime.now(),
    );

    final allMovements = _storageService.getCashMovements();
    allMovements.add(movement);
    await _storageService.saveCashMovements(allMovements);
    _cashMovements.add(movement);

    // 2. Kurangi kas yang seharusnya ada di laci
    final updated = _activeShift!.copyWith(
      totalCashOut: _activeShift!.totalCashOut + amount,
      expectedCash: _activeShift!.expectedCash - amount,
    );
    await _updateCurrentShift(updated);
  }

  /// Menutup shift kasir dan melakukan rekonsiliasi fisik vs sistem
  Future<ShiftModel> closeShift({required int actualCash}) async {
    if (_activeShift == null) {
      throw Exception('Tidak ada shift aktif yang dapat ditutup');
    }

    final expected = ShiftModel.calculateExpectedCash(
      initialCash: _activeShift!.initialCash,
      totalCashSales: _activeShift!.totalCashSales,
      totalDebtRepaidCash: _activeShift!.totalDebtRepaidCash,
      totalCashOut: _activeShift!.totalCashOut,
    );

    final diff = actualCash - expected;

    final closedShift = _activeShift!.copyWith(
      endedAt: DateTime.now(),
      expectedCash: expected,
      actualCash: actualCash,
      difference: diff,
      status: 'closed',
    );

    await _updateCurrentShift(closedShift);
    await _storageService.setActiveShiftId(null);

    final finalResult = closedShift;
    _activeShift = null;
    _cashMovements = [];
    notifyListeners();
    return finalResult;
  }

  Future<void> _updateCurrentShift(ShiftModel updated) async {
    _activeShift = updated;
    final shifts = _storageService.getShifts();
    final index = shifts.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      shifts[index] = updated;
    } else {
      shifts.add(updated);
    }
    await _storageService.saveShifts(shifts);
    notifyListeners();
  }
}
