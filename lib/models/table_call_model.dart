/// Model Panggilan Bantuan Pelayan dari Meja Tamu (Call Waiter)
class TableCallModel {
  final String callId;
  final String tableNo; // Contoh: "01", "03"
  final String requestType; // Contoh: "Sendok / Garpu / Piring", "Refill Air / Es Batu", dll
  final String notes; // Catatan tambahan opsional dari tamu
  final String status; // 'pending' (menunggu staf), 'resolved' (sudah dilayani)
  final DateTime createdAt;

  TableCallModel({
    required this.callId,
    required this.tableNo,
    required this.requestType,
    this.notes = '',
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status == 'pending';

  /// Alias catatan tambahan dari tamu
  String get note => notes;

  TableCallModel copyWith({
    String? callId,
    String? tableNo,
    String? requestType,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return TableCallModel(
      callId: callId ?? this.callId,
      tableNo: tableNo ?? this.tableNo,
      requestType: requestType ?? this.requestType,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'tableNo': tableNo,
      'requestType': requestType,
      'notes': notes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TableCallModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return TableCallModel(
      callId: map['callId'] ?? docId ?? '',
      tableNo: (map['tableNo'] ?? '').toString(),
      requestType: map['requestType'] ?? 'Bantuan Pelayan',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Parsing dokumen dari Firebase Firestore REST API response format:
  /// `fields: { callId: { stringValue: ... }, ... }`
  factory TableCallModel.fromFirestoreRest(String docName, Map<String, dynamic> fields) {
    final docId = docName.split('/').last;

    String getString(String key, [String def = '']) {
      return fields[key]?['stringValue'] ?? def;
    }

    return TableCallModel(
      callId: getString('callId', docId),
      tableNo: getString('tableNo', '01'),
      requestType: getString('requestType', 'Bantuan Pelayan'),
      notes: getString('notes', ''),
      status: getString('status', 'pending'),
      createdAt: DateTime.tryParse(getString('createdAt')) ?? DateTime.now(),
    );
  }
}
