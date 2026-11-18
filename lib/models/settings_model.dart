/// Model data Pengaturan Toko & Konfigurasi Sistem POS Resto.
/// Mendukung profil restoran, operasional meja, QRIS, keamanan owner,
/// serta konfigurasi printer thermal (58mm/80mm) dan format struk belanja.
class SettingsModel {
  final String storeName;
  final String address;
  final String phoneWA;
  final bool tableFeatureEnabled; // Toggle pemilihan meja (on/off)
  final String receiptFooter;
  final String qrisPayload; // Raw string QRIS statis resto
  final String ownerPinHash; // Hash PIN akses halaman pengaturan owner
  final String ownerSalt;

  // --- Konfigurasi Printer Thermal & Format Struk ---
  final String printerType; // 'browser', 'bluetooth', 'usb', 'network'
  final String paperSize; // '58mm' (32 char) atau '80mm' (48 char)
  final String printerName; // Nama perangkat / alias printer
  final String printerIpAddress; // Alamat IP printer untuk tipe network
  final int printerPort; // Port network printer (default 9100)
  final bool autoPrintReceipt; // Cetak otomatis struk kasir saat checkout selesai
  final bool autoPrintKitchen; // Cetak otomatis tiket KOT dapur saat pesanan dibuat
  final bool autoCut; // Kirim perintah potong kertas (paper cut)
  final int numberOfCopies; // Jumlah cetakan struk kasir (1 atau 2 rangkap)
  final String receiptHeader; // Slogan atau pesan pembuka pada header struk
  final bool showCustomerInfo; // Tampilkan nama pelanggan & nomor meja di struk
  final bool showCashierName; // Tampilkan nama kasir bertugas di struk
  final bool showOrderNotes; // Tampilkan catatan khusus per menu di struk
  final bool showQrFooter; // Tampilkan barcode / QR code di bagian bawah struk

  // --- Konfigurasi Cloud Firebase & Multi-Tenant (Isolasi Cabang Resto) ---
  final String restoId; // ID Unik Restoran / Tenant Slug (contoh: 'default', 'warkop_berkah')
  final String firebaseProjectId; // Project ID Firebase Firestore
  final String firebaseApiKey; // Web API Key Firebase Identity & Firestore
  final String webOrderBaseUrl; // Domain URL Web Self-Ordering Meja
  final bool isCloudSyncEnabled; // Saklar aktivasi sinkronisasi cloud / mode offline-only

  SettingsModel({
    this.storeName = 'Resto Digital',
    this.address = 'Jl. Kuliner No. 12, Nusantara',
    this.phoneWA = '6281234567890',
    this.tableFeatureEnabled = true,
    this.receiptFooter = 'Terima kasih atas kunjungannya di Resto Digital!',
    this.qrisPayload =
        '00020101021126540013ID.LINKAJA.WWW01189360091100213038590210000000000051440014ID.CO.QRIS.WWW0215ID10200213038590303UMI5204581253033605802ID5913RESTO DIGITAL6007JAKARTA61051234062070703A0163047A94',
    this.ownerPinHash = '',
    this.ownerSalt = '',
    // Nilai default untuk konfigurasi printer & format struk
    this.printerType = 'browser',
    this.paperSize = '58mm',
    this.printerName = 'Thermal POS-58',
    this.printerIpAddress = '192.168.1.200',
    this.printerPort = 9100,
    this.autoPrintReceipt = false,
    this.autoPrintKitchen = false,
    this.autoCut = true,
    this.numberOfCopies = 1,
    this.receiptHeader = 'Selamat Menikmati Hidangan Kami',
    this.showCustomerInfo = true,
    this.showCashierName = true,
    this.showOrderNotes = true,
    this.showQrFooter = true,
    // Nilai default untuk integrasi cloud & tenant
    this.restoId = 'default',
    this.firebaseProjectId = 'restodigital-pos',
    this.firebaseApiKey = 'AIzaSyBL9UgLYEtq32Upsp38Xa_C_Vt2Fgzwy6w',
    this.webOrderBaseUrl = 'https://restodigital-pos.web.app',
    this.isCloudSyncEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'address': address,
      'phoneWA': phoneWA,
      'tableFeatureEnabled': tableFeatureEnabled,
      'receiptFooter': receiptFooter,
      'qrisPayload': qrisPayload,
      'ownerPinHash': ownerPinHash,
      'ownerSalt': ownerSalt,
      'printerType': printerType,
      'paperSize': paperSize,
      'printerName': printerName,
      'printerIpAddress': printerIpAddress,
      'printerPort': printerPort,
      'autoPrintReceipt': autoPrintReceipt,
      'autoPrintKitchen': autoPrintKitchen,
      'autoCut': autoCut,
      'numberOfCopies': numberOfCopies,
      'receiptHeader': receiptHeader,
      'showCustomerInfo': showCustomerInfo,
      'showCashierName': showCashierName,
      'showOrderNotes': showOrderNotes,
      'showQrFooter': showQrFooter,
      'restoId': restoId,
      'firebaseProjectId': firebaseProjectId,
      'firebaseApiKey': firebaseApiKey,
      'webOrderBaseUrl': webOrderBaseUrl,
      'isCloudSyncEnabled': isCloudSyncEnabled,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      storeName: map['storeName'] ?? 'Resto Digital',
      address: map['address'] ?? 'Jl. Kuliner No. 12, Nusantara',
      phoneWA: map['phoneWA'] ?? '6281234567890',
      tableFeatureEnabled: map['tableFeatureEnabled'] ?? true,
      receiptFooter: map['receiptFooter'] ??
          'Terima kasih atas kunjungannya di Resto Digital!',
      qrisPayload: map['qrisPayload'] ??
          '00020101021126540013ID.LINKAJA.WWW01189360091100213038590210000000000051440014ID.CO.QRIS.WWW0215ID10200213038590303UMI5204581253033605802ID5913RESTO DIGITAL6007JAKARTA61051234062070703A0163047A94',
      ownerPinHash: map['ownerPinHash'] ?? '',
      ownerSalt: map['ownerSalt'] ?? '',
      printerType: map['printerType'] ?? 'browser',
      paperSize: map['paperSize'] ?? '58mm',
      printerName: map['printerName'] ?? 'Thermal POS-58',
      printerIpAddress: map['printerIpAddress'] ?? '192.168.1.200',
      printerPort: map['printerPort'] ?? 9100,
      autoPrintReceipt: map['autoPrintReceipt'] ?? false,
      autoPrintKitchen: map['autoPrintKitchen'] ?? false,
      autoCut: map['autoCut'] ?? true,
      numberOfCopies: map['numberOfCopies'] ?? 1,
      receiptHeader: map['receiptHeader'] ?? 'Selamat Menikmati Hidangan Kami',
      showCustomerInfo: map['showCustomerInfo'] ?? true,
      showCashierName: map['showCashierName'] ?? true,
      showOrderNotes: map['showOrderNotes'] ?? true,
      showQrFooter: map['showQrFooter'] ?? true,
      restoId: map['restoId'] ?? 'default',
      firebaseProjectId: map['firebaseProjectId'] ?? 'restodigital-pos',
      firebaseApiKey: map['firebaseApiKey'] ?? 'AIzaSyBL9UgLYEtq32Upsp38Xa_C_Vt2Fgzwy6w',
      webOrderBaseUrl: map['webOrderBaseUrl'] ?? 'https://restodigital-pos.web.app',
      isCloudSyncEnabled: map['isCloudSyncEnabled'] ?? true,
    );
  }

  SettingsModel copyWith({
    String? storeName,
    String? address,
    String? phoneWA,
    bool? tableFeatureEnabled,
    String? receiptFooter,
    String? qrisPayload,
    String? ownerPinHash,
    String? ownerSalt,
    String? printerType,
    String? paperSize,
    String? printerName,
    String? printerIpAddress,
    int? printerPort,
    bool? autoPrintReceipt,
    bool? autoPrintKitchen,
    bool? autoCut,
    int? numberOfCopies,
    String? receiptHeader,
    bool? showCustomerInfo,
    bool? showCashierName,
    bool? showOrderNotes,
    bool? showQrFooter,
    String? restoId,
    String? firebaseProjectId,
    String? firebaseApiKey,
    String? webOrderBaseUrl,
    bool? isCloudSyncEnabled,
  }) {
    return SettingsModel(
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      phoneWA: phoneWA ?? this.phoneWA,
      tableFeatureEnabled: tableFeatureEnabled ?? this.tableFeatureEnabled,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      qrisPayload: qrisPayload ?? this.qrisPayload,
      ownerPinHash: ownerPinHash ?? this.ownerPinHash,
      ownerSalt: ownerSalt ?? this.ownerSalt,
      printerType: printerType ?? this.printerType,
      paperSize: paperSize ?? this.paperSize,
      printerName: printerName ?? this.printerName,
      printerIpAddress: printerIpAddress ?? this.printerIpAddress,
      printerPort: printerPort ?? this.printerPort,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
      autoCut: autoCut ?? this.autoCut,
      numberOfCopies: numberOfCopies ?? this.numberOfCopies,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showCashierName: showCashierName ?? this.showCashierName,
      showOrderNotes: showOrderNotes ?? this.showOrderNotes,
      showQrFooter: showQrFooter ?? this.showQrFooter,
      restoId: restoId ?? this.restoId,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      firebaseApiKey: firebaseApiKey ?? this.firebaseApiKey,
      webOrderBaseUrl: webOrderBaseUrl ?? this.webOrderBaseUrl,
      isCloudSyncEnabled: isCloudSyncEnabled ?? this.isCloudSyncEnabled,
    );
  }
}
