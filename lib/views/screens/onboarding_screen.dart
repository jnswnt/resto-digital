import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Layar Onboarding & Registrasi Tenant Baru (Alur SaaS Mandiri / Self-Service).
/// 
/// Muncul otomatis saat aplikasi pertama kali dibuka oleh kafe/resto baru,
/// atau saat di-reset untuk mendaftarkan outlet baru.
/// Menyediakan pendaftaran identitas resto, akun owner/kasir, pemilihan template menu,
/// dan aktivasi otomatis masa aktif Trial 14 Hari.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Akun Google Pemilik (Owner)
  String? _googleOwnerEmail;
  String? _googleOwnerName;

  // Controllers Step 1: Identitas Kafe
  final _storeNameController = TextEditingController();
  final _restoIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedBusinessType = 'cafe'; // 'cafe', 'resto', 'warung', 'other'

  // Controllers Step 2: Akun & Keamanan
  final _ownerNameController = TextEditingController(text: 'Owner');
  final _ownerPinController = TextEditingController(text: '9999');
  final _confirmOwnerPinController = TextEditingController(text: '9999');
  final _cashierNameController = TextEditingController(text: 'Kasir 1');
  final _cashierPinController = TextEditingController(text: '1234');

  // Controllers Step 3: Template Menu
  TemplateBusinessType _selectedTemplate = TemplateBusinessType.coffeeShop;

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

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

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_step2Key.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  /// Menyelesaikan proses onboarding & registrasi SaaS
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
      } else {
        debugPrint('[Onboarding] Pendaftaran lokal aktif (mode offline fallback/cloud pending)');
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

      // 4. Sinkronkan katalog template baru ke Server SaaS agar web pemesanan meja langsung terisi
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
          content: Text(
            '🎉 Selamat datang di $storeName! Masa aktif Trial 14 Hari telah aktif.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.emeraldGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan registrasi: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
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
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Brand & Logo
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryAmber, AppTheme.warningOrange],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Setup Resto / Kafe Baru',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emeraldGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Trial 14 Hari',
                                        style: TextStyle(
                                          color: AppTheme.emeraldGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lengkapi data awal kafe Anda untuk mengaktifkan sistem POS & Web QR Meja',
                                  style: TextStyle(fontSize: 13, color: subTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Stepper Header
                      _buildStepIndicator(isDark),
                      const SizedBox(height: 28),

                      // Step Content
                      if (_currentStep == 0) _buildStep1(textColor, subTextColor, isDark),
                      if (_currentStep == 1) _buildStep2(textColor, subTextColor, isDark),
                      if (_currentStep == 2) _buildStep3(textColor, subTextColor, isDark),

                      const SizedBox(height: 32),

                      // Navigation Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep > 0)
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _prevStep,
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Kembali'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          if (_currentStep < 2)
                            ElevatedButton.icon(
                              onPressed: _nextStep,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text('Lanjutkan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAmber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitRegistration,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.rocket_launch_rounded, size: 18),
                              label: Text(_isLoading ? 'Mendaftarkan...' : 'Daftar & Mulai Trial 14 Hari'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAmber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                        ],
                      ),

                      if (_currentStep == 0) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _showConnectExistingDialog,
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text(
                              'Sudah punya outlet? Tautkan HP Karyawan (Kasir / Dapur) di sini',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Membuka dialog otentikasi Akun Google untuk Pemilik Resto (Owner).
  /// Memeriksa outlet terdaftar di SaaS Cloud atau mengaktifkan akun baru.
  Future<void> _handleGoogleSignIn() async {
    final emailCtrl = TextEditingController(text: _googleOwnerEmail ?? '');
    final nameCtrl = TextEditingController(text: _googleOwnerName ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Text('Masuk dengan Akun Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gunakan akun Google Anda untuk mengelola beberapa cabang outlet atau mendaftarkan resto baru.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Google *',
                  hintText: 'contoh: owner@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap / Pemilik *',
                  hintText: 'contoh: Budi Santoso',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final em = emailCtrl.text.trim();
              final nm = nameCtrl.text.trim();
              if (em.isNotEmpty) {
                Navigator.pop(ctx, {'email': em, 'name': nm.isNotEmpty ? nm : 'Pemilik Resto'});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    final email = result['email']!;
    final name = result['name']!;

    setState(() => _isLoading = true);

    try {
      final cloudSync = CloudSyncService(
        serverUrl: CloudSyncService.defaultServerUrl,
      );

      final authRes = await cloudSync.authenticateWithGoogle(
        email: email,
        name: name,
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
          // Owner telah memiliki cabang/outlet terdaftar: Buka modal pilihan outlet
          await _showOutletSelectionDialog(email, name, rawTenants);
        } else {
          // Pendaftaran baru dengan akun Google
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kendala otentikasi Google: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Modal pemilihan cabang / outlet yang dimiliki oleh akun Google Owner
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          backgroundColor: AppTheme.primaryAmber.withOpacity(0.2),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silakan lengkapi formulir di bawah untuk mendaftarkan cabang baru.')),
                  );
                },
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('+ Buat Cabang / Resto Baru'),
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

  /// Dialog 2 Tahap untuk menautkan perangkat karyawan (Kasir/Dapur) ke outlet terdaftar
  Future<void> _showConnectExistingDialog() async {
    final restoIdCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    int pairingStage = 1; // 1: Input Resto ID & Username, 2: Input PIN Keamanan
    bool isProcessing = false;
    String? errorMsg;
    Map<String, dynamic>? verifiedStaffData;

    await showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isKitchen = verifiedStaffData?['staff']?['role'] == 'kitchen';
          final staffName = verifiedStaffData?['staff']?['name'] ?? '';
          final restoName = verifiedStaffData?['restoName'] ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  pairingStage == 1 ? Icons.phonelink_setup_rounded : Icons.shield_outlined,
                  color: AppTheme.primaryAmber,
                ),
                const SizedBox(width: 10),
                Text(
                  pairingStage == 1 ? 'Tautkan Perangkat Karyawan' : 'Verifikasi PIN Keamanan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pairingStage == 1) ...[
                      const Text(
                        'Masukkan Resto ID toko dan Username Anda untuk menautkan HP ini ke sistem outlet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: restoIdCtrl,
                        decoration: InputDecoration(
                          labelText: 'Resto ID *',
                          hintText: 'contoh: samelona',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username Karyawan *',
                          hintText: 'contoh: lukman',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          // Dialog input payload QR scan dari tablet kasir
                          final qrInputCtrl = TextEditingController();
                          final qrResult = await showDialog<String>(
                            context: context,
                            builder: (qCtx) => AlertDialog(
                              title: const Text('Pindai / Tempel Kode QR Kasir', style: TextStyle(fontSize: 15)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Arahkan kamera ke QR tablet kasir atau tempel teks kode QR:', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: qrInputCtrl,
                                    decoration: const InputDecoration(
                                      hintText: '{"restoId":"samelona","username":"lukman"}',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(qCtx), child: const Text('Batal')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(qCtx, qrInputCtrl.text.trim()),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAmber, foregroundColor: Colors.black),
                                  child: const Text('Gunakan'),
                                ),
                              ],
                            ),
                          );

                          if (qrResult != null && qrResult.isNotEmpty) {
                            try {
                              final parsed = jsonDecode(qrResult);
                              if (parsed['restoId'] != null) {
                                restoIdCtrl.text = parsed['restoId'];
                              }
                              if (parsed['username'] != null) {
                                usernameCtrl.text = parsed['username'];
                              }
                            } catch (_) {
                              // Plain string parsing fallback
                              if (qrResult.contains('|')) {
                                final parts = qrResult.split('|');
                                restoIdCtrl.text = parts[0];
                                if (parts.length > 1) usernameCtrl.text = parts[1];
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Pindai Kode QR dari Tablet Kasir', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ] else ...[
                      // Stage 2: Profil Karyawan Terverifikasi & Input PIN
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: (isKitchen ? Colors.orange : AppTheme.emeraldGreen).withOpacity(0.2),
                              child: Icon(
                                isKitchen ? Icons.soup_kitchen_rounded : Icons.person_rounded,
                                color: isKitchen ? Colors.orange.shade800 : AppTheme.emeraldGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staffName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$restoName • ${isKitchen ? "Koki Dapur (KDS)" : "Kasir POS"}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Masukkan PIN rahasia Anda ($staffName) untuk mengonfirmasi kepemilikan perangkat ini:',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'PIN Keamanan (4–6 Digit) *',
                          hintText: '••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (pairingStage == 2)
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => setDlgState(() {
                            pairingStage = 1;
                            errorMsg = null;
                          }),
                  child: const Text('Ganti Akun'),
                )
              else
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final rid = restoIdCtrl.text.trim().toLowerCase();
                        final uname = usernameCtrl.text.trim().toLowerCase();

                        if (pairingStage == 1) {
                          if (rid.isEmpty || uname.isEmpty) {
                            setDlgState(() => errorMsg = 'Resto ID dan Username wajib diisi');
                            return;
                          }

                          setDlgState(() {
                            isProcessing = true;
                            errorMsg = null;
                          });

                          final cloudSync = CloudSyncService(
                            serverUrl: CloudSyncService.defaultServerUrl,
                            restoId: rid,
                          );

                          final verifyResult = await cloudSync.verifyStaffDevice(
                            restoId: rid,
                            username: uname,
                          );

                          if (verifyResult != null && verifyResult['success'] == true) {
                            setDlgState(() {
                              isProcessing = false;
                              verifiedStaffData = verifyResult;
                              pairingStage = 2; // Berpindah ke Stage 2 (Verifikasi PIN)
                            });
                          } else {
                            setDlgState(() {
                              isProcessing = false;
                              errorMsg = cloudSync.lastError ?? 'Karyawan tidak ditemukan di outlet ini.';
                            });
                          }
                        } else {
                          // Stage 2: Validasi PIN & Simpan Pairing
                          final pin = pinCtrl.text.trim();
                          if (pin.length < 4) {
                            setDlgState(() => errorMsg = 'PIN minimal 4 digit angka');
                            return;
                          }

                          setDlgState(() {
                            isProcessing = true;
                            errorMsg = null;
                          });

                          final cloudSync = CloudSyncService(
                            serverUrl: CloudSyncService.defaultServerUrl,
                            restoId: rid,
                          );

                          final staffSalt = verifiedStaffData?['staff']?['salt'] ?? '';
                          final pinHash = AuthService.hashPin(pin, staffSalt);

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
                              name: staffMap['name'] ?? staffName,
                              username: staffMap['username'] ?? uname,
                              role: staffMap['role'] ?? 'cashier',
                              pinHash: pinHash,
                              salt: staffSalt,
                              isActive: true,
                            );

                            // Simpan konfigurasi penautan perangkat permanen
                            await settingsProv.pairStaffDevice(
                              restoId: rid,
                              storeName: pairResult['restoName'] ?? restoName,
                              staffUser: staffUser,
                            );

                            posProv.loadData();
                            onlineOrderProv.syncWithSettings(settingsProv.settings);

                            // Otomatis login dengan PIN karyawan
                            await authProv.loginWithPin(pin);

                            if (ctx.mounted) Navigator.pop(ctx);

                            if (context.mounted) {
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
                            setDlgState(() {
                              isProcessing = false;
                              errorMsg = cloudSync.lastError ?? 'PIN keamanan salah.';
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isProcessing
                      ? 'Memproses...'
                      : (pairingStage == 1 ? 'Lanjutkan' : 'Verifikasi & Tautkan HP'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Indikator Tahapan (Step Indicator)
  Widget _buildStepIndicator(bool isDark) {
    final steps = ['Identitas Usaha', 'Akun & PIN', 'Katalog Menu'];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        final color = isCompleted
            ? AppTheme.emeraldGreen
            : (isActive ? AppTheme.primaryAmber : (isDark ? Colors.white24 : Colors.black26));

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(isActive || isCompleted ? 0.2 : 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: AppTheme.emeraldGreen)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? color : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 20,
                    height: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Step 1: Identitas Usaha & Slug Resto ID
  Widget _buildStep1(Color textColor, Color subTextColor, bool isDark) {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Langkah 1: Identitas Kafe / Restoran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 16),

          // Tombol Login / Lanjutkan dengan Akun Google untuk Owner
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _googleOwnerEmail != null
                    ? AppTheme.emeraldGreen
                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                width: _googleOwnerEmail != null ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(14),
              color: _googleOwnerEmail != null
                  ? AppTheme.emeraldGreen.withOpacity(0.08)
                  : (isDark ? AppTheme.darkCardSurface : Colors.grey.shade50),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isLoading ? null : _handleGoogleSignIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _googleOwnerEmail != null
                              ? 'Terhubung dengan Google: $_googleOwnerEmail'
                              : 'Lanjutkan dengan Akun Google (Owner)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _googleOwnerEmail != null ? AppTheme.emeraldGreen : textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_googleOwnerEmail != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded, color: AppTheme.emeraldGreen, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _googleOwnerEmail != null
                      ? 'lengkapi detail resto di bawah'
                      : 'atau lengkapi formulir manual',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ),
              Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 20),

          // Pilihan Jenis Usaha
          Text('Pilih Jenis Usaha:', style: TextStyle(fontSize: 13, color: subTextColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip('cafe', '☕ Coffee Shop / Kafe'),
              _buildTypeChip('resto', '🍽️ Restoran / Rumah Makan'),
              _buildTypeChip('warung', '🍜 Warung Makan / Kedai'),
              _buildTypeChip('other', '🛍️ Usaha Lainnya'),
            ],
          ),
          const SizedBox(height: 16),

          // Nama Kafe
          TextFormField(
            controller: _storeNameController,
            decoration: InputDecoration(
              labelText: 'Nama Kafe / Restoran *',
              hintText: 'Contoh: Kopi Senja, Dapoer Sedap',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Nama kafe/restoran wajib diisi';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Resto ID (Slug unik)
          TextFormField(
            controller: _restoIdController,
            decoration: InputDecoration(
              labelText: 'Resto ID (Slug Unik Link Web) *',
              hintText: 'kopi-senja',
              prefixIcon: const Icon(Icons.link_rounded),
              helperText: 'Akan digunakan untuk alamat Web QR Meja tamu: order.ipankhub.web.id/?resto=...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Resto ID wajib diisi';
              if (val.contains(' ')) return 'Resto ID tidak boleh menggunakan spasi (gunakan tanda strip -)';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // No WhatsApp Pemilik
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Nomor WhatsApp Pemilik / Resto *',
              hintText: 'Contoh: 081234567890',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Nomor WhatsApp wajib diisi';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Alamat
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Alamat Usaha (Opsional)',
              hintText: 'Contoh: Jl. Diponegoro No. 15, Bandung',
              prefixIcon: const Icon(Icons.location_on_outlined),
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
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedBusinessType = type;
            if (type == 'cafe') {
              _selectedTemplate = TemplateBusinessType.coffeeShop;
            } else if (type == 'resto') {
              _selectedTemplate = TemplateBusinessType.restaurant;
            }
          });
        }
      },
    );
  }

  /// Step 2: Akun Pemilik & Kasir Pertama
  Widget _buildStep2(Color textColor, Color subTextColor, bool isDark) {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Langkah 2: Akun Pemilik & Kasir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Atur akun untuk akses owner (laporan keuangan) dan kasir (operasional transaksi).',
            style: TextStyle(fontSize: 13, color: subTextColor),
          ),
          const SizedBox(height: 20),

          // Section Owner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSidebar : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: AppTheme.primaryAmber, size: 20),
                    SizedBox(width: 8),
                    Text('Akun Pemilik (Owner)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pemilik *',
                    hintText: 'Contoh: Bambang',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nama pemilik wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerPinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  decoration: InputDecoration(
                    labelText: 'PIN Pemilik (4-6 Digit Angka) *',
                    hintText: '9999',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: 'Digunakan untuk melihat omzet, laporan kas, & menu pengaturan rahasia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 4) return 'PIN Pemilik minimal 4 digit angka';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Kasir Pertama
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSidebar : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.point_of_sale_rounded, color: AppTheme.accentCyan, size: 20),
                    SizedBox(width: 8),
                    Text('Akun Kasir Pertama', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cashierNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kasir Pertama *',
                    hintText: 'Contoh: Kasir 1 / Rina',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nama kasir wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cashierPinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  decoration: InputDecoration(
                    labelText: 'PIN Kasir (4-6 Digit Angka) *',
                    hintText: '1234',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    helperText: 'PIN kasir untuk masuk shift dan melayani transaksi harian',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 4) return 'PIN Kasir minimal 4 digit angka';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3: Template Menu Awal & Konfirmasi Trial 14 Hari
  Widget _buildStep3(Color textColor, Color subTextColor, bool isDark) {
    final restoId = _restoIdController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Langkah 3: Pilihan Menu Awal & Aktivasi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih katalog awal yang ingin dipasang saat aplikasi pertama kali siap pakai:',
          style: TextStyle(fontSize: 13, color: subTextColor),
        ),
        const SizedBox(height: 16),

        // Template Options
        _buildTemplateCard(
          type: TemplateBusinessType.coffeeShop,
          title: '☕ Template Coffee Shop / Kafe',
          desc: 'Kopi Susu Gula Aren, Espresso, Latte, Matcha, Croissant, Roti Toast, French Fries, dll.',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTemplateCard(
          type: TemplateBusinessType.restaurant,
          title: '🍽️ Template Restoran / Rumah Makan',
          desc: 'Nasi Goreng Spesial, Ayam Bakar Madu, Mie Goreng Seafood, Soto Ayam, Es Teh, Jus Alpukat.',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTemplateCard(
          type: TemplateBusinessType.blank,
          title: '✨ Mulai Bersih dari Nol (Database Kosong)',
          desc: 'Katalog kosong tanpa menu contoh. Anda bisa input menu kafe Anda sendiri satu per satu.',
          isDark: isDark,
        ),

        const SizedBox(height: 24),

        // Banner Trial 14 Hari & Link Web
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1B3828), const Color(0xFF132B1E)]
                  : [const Color(0xFFE8F8F0), const Color(0xFFD4F2E3)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_rounded, color: AppTheme.emeraldGreen, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Paket Uji Coba Gratis 14 Hari Aktif',
                    style: TextStyle(
                      color: AppTheme.emeraldGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '• Nikmati seluruh fitur kasir, manajemen shift, dan laporan omzet tanpa batasan.\n'
                '• Tamu di meja dapat langsung memesan via web mandiri di:\n'
                '  https://order.ipankhub.web.id/?resto=${restoId.isNotEmpty ? restoId : 'resto-anda'}&table=01',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
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
    final borderColor = isSelected ? AppTheme.primaryAmber : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder);

    return InkWell(
      onTap: () => setState(() => _selectedTemplate = type),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAmber.withOpacity(isDark ? 0.15 : 0.08)
              : (isDark ? AppTheme.darkSidebar : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Radio<TemplateBusinessType>(
              value: type,
              groupValue: _selectedTemplate,
              onChanged: (val) {
                if (val != null) setState(() => _selectedTemplate = val);
              },
              activeColor: AppTheme.primaryAmber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppTheme.primaryAmber : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
