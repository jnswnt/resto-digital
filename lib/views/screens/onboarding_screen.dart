import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/onboarding_template_service.dart';
import '../../theme/app_theme.dart';

/// Enum tahapan navigasi layar awal (Arsitektur Gateway & Pemisahan Peran).
/// Memisahkan portal Owner dan penautan HP Karyawan secara terpisah dan rapi.
enum OnboardingView {
  /// Layar Utama: Pilihan Peran Pengguna Perangkat (👑 Owner vs 👨‍🍳 Karyawan)
  welcomeGateway,

  /// Layar Owner: Pilihan Login Google, Multi-Outlet, atau Pendaftaran Baru
  ownerHub,

  /// Layar Wizard: Setup Resto Baru 3-Langkah (Identitas, PIN, Template Menu)
  ownerNewTenant,

  /// Layar Karyawan Tahap 1: Pindai QR Kasir Utama atau Input Resto ID & Username
  staffPairingStage1,

  /// Layar Karyawan Tahap 2: Tampilan Profil Terdeteksi & Numpad Verifikasi PIN
  staffPairingStage2,
}

/// Layar Onboarding & Gateway Setup Resto Digital (Multi-Tenant SaaS).
/// 
/// Menggunakan arsitektur Gateway berbasis peran pengguna:
/// 1. Layar Selamat Datang (Pilihan Peran: Pemilik vs Karyawan).
/// 2. Jalur Pemilik (Owner): Login Google, pemilihan cabang terdaftar, atau setup kafe baru.
/// 3. Jalur Karyawan: Penautan HP Kasir/Dapur via Scan QR atau Resto ID + verifikasi PIN.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // State Navigasi View
  OnboardingView _currentView = OnboardingView.welcomeGateway;
  bool _isLoading = false;

  // Akun Google Pemilik (Owner)
  static const String _googleClientId =
      '59601017378-8esd6kvtamagkjjnm2q6qac94gblbooq.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _googleClientId,
    scopes: ['email', 'profile'],
  );

  String? _googleOwnerEmail;
  String? _googleOwnerName;

  // State Wizard Pendaftaran Resto Baru (3 Langkah)
  int _wizardStep = 0;
  final _storeNameController = TextEditingController();
  final _restoIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedBusinessType = 'cafe'; // 'cafe', 'resto', 'warung', 'other'

  final _ownerNameController = TextEditingController(text: 'Owner');
  final _ownerPinController = TextEditingController(text: '9999');
  final _confirmOwnerPinController = TextEditingController(text: '9999');
  final _cashierNameController = TextEditingController(text: 'Kasir 1');
  final _cashierPinController = TextEditingController(text: '1234');

  TemplateBusinessType _selectedTemplate = TemplateBusinessType.coffeeShop;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  // State Penautan Perangkat Karyawan (Staff Pairing)
  final _staffRestoIdController = TextEditingController(text: 'samelona');
  final _staffUsernameController = TextEditingController(text: 'lukman');
  String _staffPin = '';
  String? _staffErrorMessage;
  Map<String, dynamic>? _verifiedStaffData;

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_onStoreNameChanged);
  }

  @override
  void dispose() {
    _storeNameController.removeListener(_onStoreNameChanged);
    _storeNameController.dispose();
    _restoIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ownerNameController.dispose();
    _ownerPinController.dispose();
    _confirmOwnerPinController.dispose();
    _cashierNameController.dispose();
    _cashierPinController.dispose();
    _staffRestoIdController.dispose();
    _staffUsernameController.dispose();
    super.dispose();
  }

  /// Otomatis membuat slug Resto ID saat Nama Toko diketik
  void _onStoreNameChanged() {
    final raw = _storeNameController.text.trim().toLowerCase();
    final slug = raw
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _restoIdController.text = slug;
  }

  void _nextWizardStep() {
    if (_wizardStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
      setState(() => _wizardStep = 1);
    } else if (_wizardStep == 1) {
      if (!_step2Key.currentState!.validate()) return;
      setState(() => _wizardStep = 2);
    }
  }

  void _prevWizardStep() {
    if (_wizardStep > 0) {
      setState(() => _wizardStep -= 1);
    } else {
      setState(() => _currentView = OnboardingView.ownerHub);
    }
  }

  // ==========================================================================
  // LOGIKA AKUN GOOGLE & MULTI-OUTLET SAAS (OWNER)
  // ==========================================================================

  /// Melakukan otentikasi resmi dengan Akun Google (Google OAuth 2.0).
  /// Membuka popup resmi Google untuk memilih akun, mengambil email & nama profil,
  /// lalu memverifikasi data kepemilikan tenant ke Backend SaaS tanpa perlu mengisi form manual.
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // 1. Cek apakah sudah ada sesi Google yang aktif di browser ini (Fast Session Restore)
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      if (account == null) {
        try {
          account = await _googleSignIn.signInSilently().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
        } catch (_) {}
      }

      // 2. Jika belum ada sesi aktif, bersihkan status sesi lama & buka jendela login Google dengan timeout aman
      if (account == null) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}

        account = await _googleSignIn.signIn().timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            debugPrint('[GoogleSignIn] Jendela login Google ditutup atau waktu habis.');
            return null;
          },
        );
      }

      if (account == null) {
        // Pengguna membatalkan, menutup jendela popup Google, atau waktu habis
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Google dibatalkan atau waktu habis. Silakan coba klik lagi.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final email = account.email;
      final name = account.displayName?.isNotEmpty == true
          ? account.displayName!
          : 'Pemilik Resto';
      final picture = account.photoUrl;

      // 3. Hubungkan data akun Google ke Server Backend SaaS
      final cloudSync = CloudSyncService(serverUrl: CloudSyncService.defaultServerUrl);
      final authRes = await cloudSync.authenticateWithGoogle(
        email: email,
        name: name,
        picture: picture,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[GoogleSignIn] Server backend timeout');
          return null;
        },
      );

      if (!mounted) return;

      if (authRes != null && authRes['success'] == true) {
        final isNew = authRes['isNewUser'] == true;
        final rawTenants = authRes['tenants'] as List<dynamic>? ?? [];

        setState(() {
          _googleOwnerEmail = email;
          _googleOwnerName = name;
          _ownerNameController.text = name;
        });

        if (!isNew && rawTenants.isNotEmpty) {
          // Owner memiliki outlet terdaftar: Tampilkan modal pilihan cabang
          await _showOutletSelectionDialog(email, name, rawTenants);
        } else {
          // Owner baru: Arahkan ke Wizard Pendaftaran Resto Baru
          setState(() {
            _wizardStep = 0;
            _currentView = OnboardingView.ownerNewTenant;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Akun Google $email terhubung! Lengkapi nama resto Anda di bawah.'),
              backgroundColor: AppTheme.emeraldGreen,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cloudSync.lastError ?? 'Gagal memverifikasi akun Google ke server.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('[GoogleSignIn] Kendala otentikasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kendala login Google: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Modal pemilihan cabang / outlet yang dimiliki akun Google Owner
  Future<void> _showOutletSelectionDialog(
    String email,
    String name,
    List<dynamic> tenants,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppTheme.primaryAmber),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pilih Cabang / Resto Anda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ditemukan ${tenants.length} outlet terdaftar pada akun Google $email. Pilih salah satu untuk ditautkan langsung ke tablet ini:',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tenants.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final t = tenants[index] as Map<String, dynamic>;
                    final bName = t['businessName'] ?? t['restoId'];
                    final rId = t['restoId'] ?? '';
                    final daysLeft = t['daysLeft'] ?? 14;
                    final isExp = t['isExpired'] == true;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryAmber.withValues(alpha: 0.2),
                          child: const Icon(Icons.store_rounded, color: AppTheme.primaryAmber),
                        ),
                        title: Text(bName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          'ID: $rId • ${isExp ? "Masa trial habis" : "Trial aktif: $daysLeft hari"}',
                          style: TextStyle(fontSize: 12, color: isExp ? Colors.red : Colors.green.shade700),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () async {
                          Navigator.pop(dlgCtx);
                          await _linkExistingOwnerOutlet(rId, bName, email, t);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  setState(() {
                    _wizardStep = 0;
                    _currentView = OnboardingView.ownerNewTenant;
                  });
                },
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('+ Ingin Buka Cabang / Resto Baru Lainnya'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menautkan tablet secara langsung ke outlet yang sudah terdaftar di Cloud SaaS
  Future<void> _linkExistingOwnerOutlet(
    String targetRestoId,
    String businessName,
    String ownerEmail,
    Map<String, dynamic> tenantData,
  ) async {
    setState(() => _isLoading = true);
    try {
      final cloudSync = CloudSyncService(
        serverUrl: CloudSyncService.defaultServerUrl,
        restoId: targetRestoId,
      );

      final details = await cloudSync.fetchTenantDetails(targetRestoId);
      if (!mounted) return;
      final settingsProv = context.read<SettingsProvider>();
      final posProv = context.read<PosProvider>();
      final onlineOrderProv = context.read<OnlineOrderProvider>();
      final authProv = context.read<AuthProvider>();

      List<CategoryModel>? categories;
      List<ProductModel>? products;
      List<UserModel>? staffList;

      if (details != null && details['success'] == true) {
        final catalog = details['catalog'] as Map<String, dynamic>?;
        if (catalog != null) {
          final rawCats = catalog['categories'] as List<dynamic>? ?? [];
          final rawProds = catalog['products'] as List<dynamic>? ?? [];

          categories = rawCats.map<CategoryModel>((c) {
            if (c is Map<String, dynamic>) {
              return CategoryModel.fromMap(c);
            }
            final cName = c.toString();
            return CategoryModel(id: cName.toLowerCase(), name: cName, sortOrder: 0);
          }).toList();

          products = rawProds.map<ProductModel>((p) {
            if (p is Map<String, dynamic>) {
              return ProductModel.fromMap(p);
            }
            return ProductModel(
              id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
              name: 'Menu',
              categoryId: 'cat_default',
              buyPrice: 0,
              sellPrice: 0,
            );
          }).toList();
        }

        final rawStaff = details['staff'] as List<dynamic>? ?? [];
        if (rawStaff.isNotEmpty) {
          staffList = rawStaff.map<UserModel>((s) => UserModel.fromMap(s as Map<String, dynamic>)).toList();
        }
      }

      await settingsProv.linkOwnerTenant(
        restoId: targetRestoId,
        storeName: businessName,
        ownerEmail: ownerEmail,
        businessType: tenantData['businessType'] ?? 'cafe',
        address: tenantData['address'] ?? '',
        phoneWA: tenantData['phone'] ?? '',
        subscriptionStatus: tenantData['subscriptionStatus'] ?? 'trial',
        trialExpiresAt: tenantData['trialExpiresAt'],
        categories: categories,
        products: products,
        staff: staffList,
      );

      posProv.loadData();
      onlineOrderProv.syncWithSettings(settingsProv.settings);

      // Otomatis aktifkan user owner jika tersedia
      if (staffList != null && staffList.isNotEmpty) {
        final ownerUser = staffList.firstWhere(
          (u) => u.isOwner,
          orElse: () => staffList!.first,
        );
        authProv.setActiveUser(ownerUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Tablet berhasil ditautkan ke $businessName!'),
            backgroundColor: AppTheme.emeraldGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menautkan outlet: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menyelesaikan proses onboarding & registrasi SaaS untuk tenant baru
  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    final storeName = _storeNameController.text.trim();
    final restoId = _restoIdController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final ownerPin = _ownerPinController.text.trim();
    final cashierName = _cashierNameController.text.trim();
    final cashierPin = _cashierPinController.text.trim();

    final settingsProv = context.read<SettingsProvider>();
    final posProv = context.read<PosProvider>();
    final onlineOrderProv = context.read<OnlineOrderProvider>();
    final authProv = context.read<AuthProvider>();

    try {
      // 1. Kirim registrasi ke Backend SaaS Server (Masa Trial 14 Hari)
      final cloudSync = CloudSyncService(
        serverUrl: CloudSyncService.defaultServerUrl,
        restoId: restoId,
      );

      final regResult = await cloudSync.registerTenant(
        restoId: restoId,
        businessName: storeName,
        businessType: _selectedBusinessType,
        ownerName: ownerName,
        ownerEmail: _googleOwnerEmail,
        phone: phone,
        address: address,
        trialDays: 14,
      );

      if (regResult != null && regResult['success'] == true) {
        debugPrint('[Onboarding] Pendaftaran berhasil di SaaS cloud: $restoId');
      }

      // 2. Simpan seluruh konfigurasi akun & katalog template ke penyimpanan lokal
      await settingsProv.setupNewTenant(
        storeName: storeName,
        restoId: restoId,
        businessType: _selectedBusinessType,
        address: address.isNotEmpty ? address : 'Jl. Utama No. 01',
        phoneWA: phone.isNotEmpty ? phone : '081234567890',
        ownerName: ownerName.isNotEmpty ? ownerName : 'Owner',
        ownerPin: ownerPin.isNotEmpty ? ownerPin : '9999',
        cashierName: cashierName.isNotEmpty ? cashierName : 'Kasir 1',
        cashierPin: cashierPin.isNotEmpty ? cashierPin : '1234',
        templateType: _selectedTemplate,
        ownerEmail: _googleOwnerEmail,
      );

      // 3. Muat ulang katalog POS & konfigurasikan Cloud Listener
      posProv.loadData();
      final updatedSettings = settingsProv.settings;
      onlineOrderProv.syncWithSettings(updatedSettings);

      // 4. Sinkronkan katalog template baru ke Server SaaS
      final prods = posProv.products;
      if (prods.isNotEmpty) {
        final catMap = {for (var c in posProv.categories) c.id: c.name};
        await cloudSync.syncMenuToCloud(
          prods,
          categoryNames: catMap,
          restoName: storeName,
        );
      }

      // 5. Otomatis login sebagai Owner
      await authProv.loginWithPin(ownerPin.isNotEmpty ? ownerPin : '9999');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Selamat datang di $storeName! Masa aktif Trial 14 Hari telah aktif.'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan registrasi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // LOGIKA PENAUTAN PERANGKAT KARYAWAN (STAFF PAIRING)
  // ==========================================================================

  /// Verifikasi Tahap 1: Memeriksa Resto ID & Username Karyawan ke server
  Future<void> _verifyStaffStage1() async {
    final rid = _staffRestoIdController.text.trim().toLowerCase();
    final uname = _staffUsernameController.text.trim().toLowerCase();

    if (rid.isEmpty || uname.isEmpty) {
      setState(() => _staffErrorMessage = 'Resto ID dan Username wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _staffErrorMessage = null;
    });

    try {
      final cloudSync = CloudSyncService(
        serverUrl: CloudSyncService.defaultServerUrl,
        restoId: rid,
      );

      final verifyRes = await cloudSync.verifyStaffDevice(restoId: rid, username: uname);

      if (verifyRes != null && verifyRes['success'] == true) {
        setState(() {
          _verifiedStaffData = verifyRes;
          _staffPin = '';
          _currentView = OnboardingView.staffPairingStage2;
        });
      } else {
        setState(() {
          _staffErrorMessage = cloudSync.lastError ?? 'Karyawan tidak ditemukan di outlet ini.';
        });
      }
    } catch (e) {
      setState(() => _staffErrorMessage = 'Kendala koneksi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Verifikasi Tahap 2: Mengirim PIN untuk mengunci HP karyawan secara permanen
  Future<void> _pairStaffStage2() async {
    if (_staffPin.length < 4) {
      setState(() => _staffErrorMessage = 'Masukkan 4 digit PIN Anda');
      return;
    }

    final rid = _staffRestoIdController.text.trim().toLowerCase();
    final uname = _staffUsernameController.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _staffErrorMessage = null;
    });

    try {
      final cloudSync = CloudSyncService(
        serverUrl: CloudSyncService.defaultServerUrl,
        restoId: rid,
      );

      final staffSalt = _verifiedStaffData?['staff']?['salt'] ?? '';
      final pinHash = AuthService.hashPin(_staffPin, staffSalt);

      final pairResult = await cloudSync.pairStaffDevice(
        restoId: rid,
        username: uname,
        pinHash: pinHash,
      );

      if (pairResult != null && pairResult['success'] == true) {
        if (!mounted) return;
        final settingsProv = context.read<SettingsProvider>();
        final posProv = context.read<PosProvider>();
        final onlineOrderProv = context.read<OnlineOrderProvider>();
        final authProv = context.read<AuthProvider>();

        final staffMap = pairResult['staff'] as Map<String, dynamic>;
        final staffUser = UserModel(
          id: staffMap['id'] ?? 'user_$uname',
          name: staffMap['name'] ?? uname,
          username: staffMap['username'] ?? uname,
          role: staffMap['role'] ?? 'cashier',
          pinHash: pinHash,
          salt: staffSalt,
          isActive: true,
        );

        // Simpan konfigurasi penautan perangkat permanen
        await settingsProv.pairStaffDevice(
          restoId: rid,
          storeName: pairResult['restoName'] ?? 'Resto Digital',
          staffUser: staffUser,
        );

        posProv.loadData();
        onlineOrderProv.syncWithSettings(settingsProv.settings);

        // Otomatis login dengan PIN karyawan
        await authProv.loginWithPin(_staffPin);

        if (mounted) {
          final roleTitle = staffUser.isKitchen ? 'Koki Dapur (KDS)' : 'Kasir POS';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 HP Anda resmi tertaut ke ${pairResult["restoName"]} sebagai $roleTitle (${staffUser.name})!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.emeraldGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() {
          _staffErrorMessage = cloudSync.lastError ?? 'PIN keamanan salah.';
          _staffPin = '';
        });
      }
    } catch (e) {
      setState(() => _staffErrorMessage = 'Kendala penautan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dialog Pindai / Tempel QR Code Kasir
  Future<void> _showQrScanDialog() async {
    final qrInputCtrl = TextEditingController();
    final qrResult = await showDialog<String>(
      context: context,
      builder: (qCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryAmber),
            SizedBox(width: 10),
            Text('Pindai Kode QR Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arahkan kamera ke layar Kasir Utama atau tempel data teks QR di bawah:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qrInputCtrl,
              decoration: InputDecoration(
                hintText: '{"restoId":"samelona","username":"lukman"}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(qCtx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(qCtx, qrInputCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Gunakan Data QR'),
          ),
        ],
      ),
    );

    if (qrResult != null && qrResult.isNotEmpty) {
      try {
        final parsed = jsonDecode(qrResult);
        if (parsed['restoId'] != null) {
          _staffRestoIdController.text = parsed['restoId'];
        }
        if (parsed['username'] != null) {
          _staffUsernameController.text = parsed['username'];
        }
      } catch (_) {
        if (qrResult.contains('|')) {
          final parts = qrResult.split('|');
          _staffRestoIdController.text = parts[0];
          if (parts.length > 1) _staffUsernameController.text = parts[1];
        }
      }
      // Langsung jalankan verifikasi tahap 1
      _verifyStaffStage1();
    }
  }

  // ==========================================================================
  // WIDGET BUILDER UTAMA (ROUTING VIEW)
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
    final cardColor = isDark ? AppTheme.darkCardSurface : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final subTextColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Card(
                color: cardColor,
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _buildCurrentViewContent(textColor, subTextColor, isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentViewContent(Color textColor, Color subTextColor, bool isDark) {
    switch (_currentView) {
      case OnboardingView.welcomeGateway:
        return _buildWelcomeGateway(textColor, subTextColor, isDark);
      case OnboardingView.ownerHub:
        return _buildOwnerHub(textColor, subTextColor, isDark);
      case OnboardingView.ownerNewTenant:
        return _buildOwnerNewTenantWizard(textColor, subTextColor, isDark);
      case OnboardingView.staffPairingStage1:
        return _buildStaffPairingStage1(textColor, subTextColor, isDark);
      case OnboardingView.staffPairingStage2:
        return _buildStaffPairingStage2(textColor, subTextColor, isDark);
    }
  }

  // ==========================================================================
  // LAYAR 1: WELCOME GATEWAY (PILIHAN PERAN PERANGKAT)
  // ==========================================================================

  Widget _buildWelcomeGateway(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryAmber, AppTheme.warningOrange],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'RESTO DIGITAL POS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Selamat Datang! Silakan pilih peran perangkat ini untuk memulai:',
                style: TextStyle(fontSize: 13, color: subTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 2 Kartu Peran Utama
        Row(
          children: [
            // Kartu 1: Saya Pemilik Usaha
            Expanded(
              child: _buildRoleCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: AppTheme.primaryAmber,
                badgeText: 'Pemilik Usaha',
                badgeColor: AppTheme.primaryAmber,
                title: 'Saya Pemilik Resto',
                desc: 'Login akun Google untuk kelola cabang terdaftar, atau daftarkan resto baru dengan Trial 14 Hari.',
                actionLabel: 'Masuk Mode Owner →',
                isDark: isDark,
                onTap: () {
                  setState(() => _currentView = OnboardingView.ownerHub);
                },
              ),
            ),
            const SizedBox(width: 16),

            // Kartu 2: Saya Karyawan Toko
            Expanded(
              child: _buildRoleCard(
                icon: Icons.badge_rounded,
                iconColor: AppTheme.emeraldGreen,
                badgeText: 'Kasir / Koki Dapur',
                badgeColor: AppTheme.emeraldGreen,
                title: 'Saya Karyawan Toko',
                desc: 'Tautkan HP atau tablet ini langsung ke toko menggunakan Scan QR Kasir atau Resto ID & PIN pribadi.',
                actionLabel: 'Tautkan HP Ini →',
                isDark: isDark,
                onTap: () {
                  setState(() => _currentView = OnboardingView.staffPairingStage1);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Center(
          child: Text(
            'Sistem Kasir & Operasional Resto Modern • Zero Complex Setup',
            style: TextStyle(fontSize: 11, color: subTextColor),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String desc,
    required String actionLabel,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // LAYAR 2A: OWNER PORTAL (LOGIN GOOGLE / CABANG / DAFTAR BARU)
  // ==========================================================================

  Widget _buildOwnerHub(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol Kembali ke Welcome Gateway
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = false;
                _currentView = OnboardingView.welcomeGateway;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Kembali ke Pilihan Peran'),
          ),
        ),
        const SizedBox(height: 12),

        // Header Owner Hub
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryAmber, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portal Pemilik Usaha (Owner)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kelola cabang restoran terdaftar atau daftarkan outlet baru',
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Card Opsi Utama: Google Sign In
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardSurface : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masuk Cepat dengan Akun Google',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sistem akan otomatis mendeteksi seluruh outlet terdaftar milik Anda, atau mendaftarkan outlet baru secara instan.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Tombol Google
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 20),
                ),
                label: Text(
                  _isLoading ? 'Menghubungkan...' : 'Lanjutkan dengan Akun Google',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = false);
                    },
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'Batalkan & Buka Kunci Layar',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('atau tanpa akun Google', style: TextStyle(fontSize: 12, color: subTextColor)),
            ),
            Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 18),

        // Tombol Setup Resto Baru Manual
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _isLoading = false;
              _wizardStep = 0;
              _currentView = OnboardingView.ownerNewTenant;
            });
          },
          icon: const Icon(Icons.add_business_rounded, size: 18),
          label: const Text('Daftarkan Resto Baru Secara Manual'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // LAYAR 2A-WIZARD: SETUP RESTO BARU 3-LANGKAH (TRIAL 14 HARI)
  // ==========================================================================

  Widget _buildOwnerNewTenantWizard(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol Kembali ke Owner Hub
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _currentView = OnboardingView.ownerHub);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Kembali ke Portal Owner'),
          ),
        ),
        const SizedBox(height: 8),

        // Header Wizard
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryAmber, AppTheme.warningOrange]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Setup Resto / Kafe Baru',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Trial 14 Hari',
                          style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Aktifkan POS kasir dan link Web Pemesanan Meja dalam 3 langkah mudah',
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Indikator Stepper
        _buildStepIndicator(isDark),
        const SizedBox(height: 24),

        // Konten Step
        if (_wizardStep == 0) _buildWizardStep1(textColor, subTextColor, isDark),
        if (_wizardStep == 1) _buildWizardStep2(textColor, subTextColor, isDark),
        if (_wizardStep == 2) _buildWizardStep3(textColor, subTextColor, isDark),

        const SizedBox(height: 28),

        // Tombol Navigasi Stepper
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_wizardStep > 0)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _prevWizardStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Sebelumnya'),
              )
            else
              const SizedBox.shrink(),

            if (_wizardStep < 2)
              ElevatedButton.icon(
                onPressed: _nextWizardStep,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Lanjutkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitRegistration,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.rocket_launch_rounded, size: 16),
                label: Text(_isLoading ? 'Mendaftarkan...' : 'Daftar & Mulai Trial 14 Hari'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    final steps = ['Identitas Usaha', 'Akun & PIN', 'Katalog Menu'];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _wizardStep;
        final isCompleted = index < _wizardStep;
        final color = isCompleted
            ? AppTheme.emeraldGreen
            : (isActive ? AppTheme.primaryAmber : (isDark ? Colors.white24 : Colors.black26));

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: AppTheme.emeraldGreen)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? color : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index < steps.length - 1)
                Container(width: 16, height: 1, color: isDark ? Colors.white12 : Colors.black12),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWizardStep1(Color textColor, Color subTextColor, bool isDark) {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_googleOwnerEmail != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _googleOwnerName != null
                        ? 'Akun Google: $_googleOwnerName ($_googleOwnerEmail)'
                        : 'Akun Google Terhubung: $_googleOwnerEmail',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text('Pilih Jenis Usaha:', style: TextStyle(fontSize: 13, color: subTextColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip('cafe', '☕ Coffee Shop'),
              _buildTypeChip('resto', '🍽️ Restoran'),
              _buildTypeChip('warung', '🍜 Warung Makan'),
              _buildTypeChip('other', '🛍️ Usaha Lainnya'),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _storeNameController,
            decoration: InputDecoration(
              labelText: 'Nama Kafe / Restoran *',
              hintText: 'Contoh: Kopi Senja, Resto Samelona',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama kafe wajib diisi' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _restoIdController,
            decoration: InputDecoration(
              labelText: 'Resto ID (Slug Unik Link Web) *',
              hintText: 'kopi-senja',
              prefixIcon: const Icon(Icons.link_rounded),
              helperText: 'order.ipankhub.web.id/?resto=...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Resto ID wajib diisi';
              if (val.contains(' ')) return 'Gunakan tanda strip (-) tanpa spasi';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'No. WhatsApp Pemilik',
              hintText: '08123456789',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedBusinessType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedBusinessType = type),
      selectedColor: AppTheme.primaryAmber.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primaryAmber : null,
      ),
    );
  }

  Widget _buildWizardStep2(Color textColor, Color subTextColor, bool isDark) {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _ownerNameController,
            decoration: InputDecoration(
              labelText: 'Nama Pemilik (Owner) *',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama owner wajib diisi' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _ownerPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'PIN Owner (4-6 Digit) *',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'Akan digunakan untuk membuka menu Pengaturan & Laporan',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => (val == null || val.length < 4) ? 'PIN minimal 4 digit' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _cashierPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'PIN Kasir Pertama *',
              prefixIcon: const Icon(Icons.badge_outlined),
              helperText: 'Untuk login harian staf kasir di layar lock screen',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => (val == null || val.length < 4) ? 'PIN minimal 4 digit' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWizardStep3(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Template Menu Awal:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Dapat Anda ubah atau tambah menu baru kapan saja dari dashboard.',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 16),

        _buildTemplateCard(
          type: TemplateBusinessType.coffeeShop,
          title: '☕ Template Coffee Shop / Kafe',
          desc: 'Berisi Kopi Susu, Espresso, Latte, Matcha, Croissant, dan Camilan.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        _buildTemplateCard(
          type: TemplateBusinessType.restaurant,
          title: '🍽️ Template Restoran / Rumah Makan',
          desc: 'Berisi Nasi Goreng, Ayam Bakar, Mie Goreng, Es Teh, dan Jus Segar.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        _buildTemplateCard(
          type: TemplateBusinessType.blank,
          title: '✨ Bersih (Mulai dari Nol)',
          desc: 'Katalog kosong, Anda bebas menginput kategori dan menu dari awal.',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTemplateCard({
    required TemplateBusinessType type,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    final isSelected = _selectedTemplate == type;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryAmber.withValues(alpha: 0.1)
            : (isDark ? AppTheme.darkCardSurface : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.primaryAmber : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedTemplate = type),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppTheme.primaryAmber : null)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAmber) : null,
      ),
    );
  }

  // ==========================================================================
  // LAYAR 2B: PENAUTAN PERANGKAT KARYAWAN (STAGE 1 & STAGE 2)
  // ==========================================================================

  Widget _buildStaffPairingStage1(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol Kembali
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _currentView = OnboardingView.welcomeGateway);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Kembali ke Pilihan Peran'),
          ),
        ),
        const SizedBox(height: 12),

        // Header Karyawan
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.badge_rounded, color: AppTheme.emeraldGreen, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tautkan HP Karyawan (Kasir / Dapur)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hubungkan HP ini ke outlet toko tempat Anda bertugas',
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Metode 1: Scan QR Kasir
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardSurface : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, size: 36, color: AppTheme.emeraldGreen),
              const SizedBox(height: 8),
              const Text('Metode Cepat: Pindai Kode QR Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Minta kasir utama membuka menu Kelola Kasir, lalu scan kode QR akun staf Anda.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _showQrScanDialog,
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Pindai Kode QR Kasir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('atau masukkan data manual', style: TextStyle(fontSize: 12, color: subTextColor)),
            ),
            Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 18),

        // Metode 2: Input Resto ID & Username
        TextField(
          controller: _staffRestoIdController,
          decoration: InputDecoration(
            labelText: 'Resto ID Toko *',
            hintText: 'contoh: samelona',
            prefixIcon: const Icon(Icons.storefront_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _staffUsernameController,
          decoration: InputDecoration(
            labelText: 'Username Karyawan Anda *',
            hintText: 'contoh: lukman',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        if (_staffErrorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_staffErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],

        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyStaffStage1,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAmber,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isLoading ? 'Memverifikasi...' : 'Lanjutkan ke Verifikasi PIN →', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStaffPairingStage2(Color textColor, Color subTextColor, bool isDark) {
    final staff = _verifiedStaffData?['staff'] as Map<String, dynamic>?;
    final staffName = staff?['name'] ?? _staffUsernameController.text;
    final staffRole = staff?['role'] ?? 'cashier';
    final restoName = _verifiedStaffData?['restoName'] ?? _staffRestoIdController.text;
    final isKitchen = staffRole == 'kitchen';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol Kembali ke Stage 1
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _currentView = OnboardingView.staffPairingStage1);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Kembali ke Input ID'),
          ),
        ),
        const SizedBox(height: 8),

        // Banner Profil Karyawan Terdeteksi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withValues(alpha: 0.25),
                child: Icon(
                  isKitchen ? Icons.soup_kitchen_rounded : Icons.point_of_sale_rounded,
                  color: isKitchen ? Colors.orange.shade800 : AppTheme.emeraldGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staffName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '$restoName • ${isKitchen ? "Koki Dapur (KDS)" : "Kasir POS"}',
                      style: TextStyle(fontSize: 12, color: isKitchen ? Colors.orange.shade800 : AppTheme.emeraldGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: Column(
            children: [
              Text(
                'Masukkan PIN Keamanan ($staffName)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Masukkan 4 digit PIN yang dibuatkan Owner untuk mengunci HP ini',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PIN Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _staffPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppTheme.primaryAmber : Colors.transparent,
                border: Border.all(
                  color: isFilled ? AppTheme.primaryAmber : Colors.grey,
                  width: 2,
                ),
              ),
            );
          }),
        ),

        if (_staffErrorMessage != null) ...[
          const SizedBox(height: 12),
          Center(child: Text(_staffErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],

        const SizedBox(height: 20),

        // Numpad Interaktif
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              children: [
                _buildNumpadRow(['1', '2', '3']),
                const SizedBox(height: 8),
                _buildNumpadRow(['4', '5', '6']),
                const SizedBox(height: 8),
                _buildNumpadRow(['7', '8', '9']),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumpadKey('C', isAction: true, onTap: () {
                      if (_staffPin.isNotEmpty) {
                        setState(() => _staffPin = _staffPin.substring(0, _staffPin.length - 1));
                      }
                    }),
                    const SizedBox(width: 8),
                    _buildNumpadKey('0', onTap: () => _appendPin('0')),
                    const SizedBox(width: 8),
                    _buildNumpadKey('OK', isAction: true, isConfirm: true, onTap: _pairStaffStage2),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (_isLoading || _staffPin.length < 4) ? null : _pairStaffStage2,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emeraldGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isLoading ? 'Menautkan Perangkat...' : 'Kunci Perangkat ke Outlet Ini', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildNumpadKey(d, onTap: () => _appendPin(d)),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadKey(String label, {bool isAction = false, bool isConfirm = false, required VoidCallback onTap}) {
    return SizedBox(
      width: 70,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isConfirm
              ? AppTheme.emeraldGreen
              : (isAction ? Colors.grey.shade800 : Colors.grey.shade900),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isAction ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _appendPin(String digit) {
    if (_staffPin.length < 4) {
      setState(() {
        _staffPin += digit;
        _staffErrorMessage = null;
      });
      if (_staffPin.length == 4) {
        // Otomatis picu penautan setelah 4 digit dimasukkan
        _pairStaffStage2();
      }
    }
  }
}
