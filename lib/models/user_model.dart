/// Model data Pengguna (Kasir, Staf Dapur/Koki, & Owner) untuk sistem POS Resto.
/// Mendukung autentikasi berbasis PIN dengan Salted Hash.
class UserModel {
  final String id;
  final String name;
  final String username; // Username penautan perangkat (contoh: 'lukman')
  final String role; // 'cashier', 'kitchen' / 'staff', atau 'owner'
  final String pinHash;
  final String salt;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    String? username,
    required this.role,
    required this.pinHash,
    required this.salt,
    this.isActive = true,
    DateTime? createdAt,
  })  : username = username != null && username.isNotEmpty
            ? username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
            : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        createdAt = createdAt ?? DateTime.now();

  bool get isOwner => role == 'owner';
  bool get isCashier => role == 'cashier';
  bool get isKitchen => role == 'kitchen' || role == 'staff';
  bool get isStaff => isCashier || isKitchen;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role,
      'pinHash': pinHash,
      'salt': salt,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final nameVal = map['name'] ?? '';
    return UserModel(
      id: map['id'] ?? '',
      name: nameVal,
      username: map['username'] ??
          nameVal.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
      role: map['role'] ?? 'cashier',
      pinHash: map['pinHash'] ?? '',
      salt: map['salt'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? role,
    String? pinHash,
    String? salt,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      salt: salt ?? this.salt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
