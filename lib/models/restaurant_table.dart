import 'dart:convert';

/// Model Konfigurasi Meja Restoran (Restaurant Table)
/// Merepresentasikan meja fisik di restoran yang dapat ditempati tamu.
class RestaurantTable {
  final String id;
  final String tableNumber; // Contoh: "Meja 01", "Meja 02", "VIP 1", "Lesehan A"
  final String section;     // Contoh: "Reguler", "VIP", "Outdoor", "Lesehan"
  final int capacity;       // Kapasitas kursi (misal 2, 4, 6)
  final bool isActive;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.section = 'Reguler',
    this.capacity = 4,
    this.isActive = true,
  });

  /// Normalisasi teks meja untuk pencocokan toleran huruf besar/kecil dan spasi
  static String normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Ekstraksi angka meja jika ada (contoh: "Meja 04" -> "4", "4" -> "4")
  static String extractDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (digits.isEmpty) return '';
    return int.tryParse(digits)?.toString() ?? digits;
  }

  /// Ekstraksi kata/awalan huruf meja (contoh: "VIP 1" -> "vip", "Meja 01" -> "meja")
  static String extractLetters(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').trim();
  }

  /// Memeriksa apakah dua string meja merepresentasikan meja yang sama
  /// Mencegah false match antara area/tipe meja yang berbeda (misal: "VIP 1" vs "Meja 01")
  static bool isMatch(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA == normB) return true;

    final digA = extractDigits(normA);
    final digB = extractDigits(normB);
    if (digA.isNotEmpty && digA == digB) {
      final letA = extractLetters(normA);
      final letB = extractLetters(normB);

      // Jika awalan hurufnya persis sama (misal "Meja 1" vs "Meja 01" atau "VIP 1" vs "VIP 01")
      if (letA == letB) return true;

      // Toleransi jika satu hanya menulis angka polos ("1" / "01") dan yang lain meja umum ("meja" / "table")
      final isGenericA = letA.isEmpty || letA == 'meja' || letA == 'table';
      final isGenericB = letB.isEmpty || letB == 'meja' || letB == 'table';
      if (isGenericA && isGenericB) return true;

      // Jika salah satu memiliki kategori khusus (seperti "vip", "lesehan", "outdoor"),
      // jangan dicocokkan dengan meja reguler atau kategori lain!
      return false;
    }
    return false;
  }

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? section,
    int? capacity,
    bool? isActive,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      section: section ?? this.section,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'section': section,
      'capacity': capacity,
      'isActive': isActive,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id']?.toString() ?? '',
      tableNumber: map['tableNumber']?.toString() ?? '',
      section: map['section']?.toString() ?? 'Reguler',
      capacity: map['capacity'] is int ? map['capacity'] as int : int.tryParse(map['capacity']?.toString() ?? '4') ?? 4,
      isActive: map['isActive'] == true || map['isActive'] == 1 || map['isActive'] == 'true',
    );
  }

  String toJson() => json.encode(toMap());

  factory RestaurantTable.fromJson(String source) =>
      RestaurantTable.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Daftar Meja Bawaan Standar (Meja 01 s.d Meja 12)
  static List<RestaurantTable> getDefaultTables() {
    return List.generate(12, (index) {
      final numStr = (index + 1).toString().padLeft(2, '0');
      return RestaurantTable(
        id: 'T$numStr',
        tableNumber: 'Meja $numStr',
        section: index < 8 ? 'Reguler' : 'Outdoor',
        capacity: (index % 3 == 0) ? 6 : 4,
        isActive: true,
      );
    });
  }
}

/// Status Operasional Meja di Kasir
enum TableStatus {
  available,      // 🟢 Kosong / Bersih / Siap Pakai
  occupied,       // 🔴 Terisi / Tamu Sedang Bersantap
  pendingWebOrder,// 🟡 Order Web Baru Masuk (Butuh Konfirmasi Kasir)
  callingWaiter,  // 🔔 Tamu Memanggil Bantuan Pelayan
}
