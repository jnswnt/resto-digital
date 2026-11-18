import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/settings_provider.dart';
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
