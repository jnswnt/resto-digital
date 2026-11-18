/// Model data Pelanggan Resto untuk sistem pencatatan Kasbon (Utang).
/// Menyimpan saldo utang berjalan dan batas maksimal kasbon (limit).
class CustomerModel {
  final String id;
  final String name;
  final String phoneWA;
  final int totalDebt;
  final int debtLimit;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phoneWA,
    this.totalDebt = 0,
    this.debtLimit = 100000,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Sisa limit kasbon yang masih tersedia untuk pelanggan ini
  int get remainingLimit => (debtLimit - totalDebt) > 0 ? (debtLimit - totalDebt) : 0;

  /// Memeriksa apakah pelanggan sudah melampaui limit
  bool get isOverLimit => totalDebt >= debtLimit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneWA': phoneWA,
      'totalDebt': totalDebt,
      'debtLimit': debtLimit,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneWA: map['phoneWA'] ?? '',
      totalDebt: (map['totalDebt'] as num?)?.toInt() ?? 0,
      debtLimit: (map['debtLimit'] as num?)?.toInt() ?? 100000,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()))
          : DateTime.now(),
    );
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phoneWA,
    int? totalDebt,
    int? debtLimit,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneWA: phoneWA ?? this.phoneWA,
      totalDebt: totalDebt ?? this.totalDebt,
      debtLimit: debtLimit ?? this.debtLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
