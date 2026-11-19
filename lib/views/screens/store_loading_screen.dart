import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Transisi Loading Interaktif Resto (Store Initialization Screen).
/// 
/// Mengimplementasikan arsitektur Lazy-Loading / On-Demand Data Hydration:
/// Memuat seluruh database transaksional (menu produk, denah meja, pesanan, shift)
/// hanya setelah kasir/owner berhasil memverifikasi PIN di Kiosk Lock Screen.
/// 
/// Dilengkapi dengan:
/// - Sapaan personal sesuai peran (Kasir, Koki Dapur KDS, Owner).
/// - Progress bar persentase (0% -> 100%) dengan animasi dinamis.
/// - Checklist status transparan dan informatif.
/// - Ketahanan mode offline (Offline-first resilience).
class StoreLoadingScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onCompleted;

  const StoreLoadingScreen({
    super.key,
    required this.user,
    required this.onCompleted,
  });

  @override
  State<StoreLoadingScreen> createState() => _StoreLoadingScreenState();
}

class _StoreLoadingScreenState extends State<StoreLoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  String _currentStepMessage = 'Memulai persiapan sistem resto...';
  final List<String> _completedSteps = [];
  bool _isFinished = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Jalankan pemuatan database bertahap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHydration();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Memuat seluruh data operasional toko secara bertahap
  Future<void> _startHydration() async {
    final authProv = context.read<AuthProvider>();
    final posProv = context.read<PosProvider>();
    final shiftProv = context.read<ShiftProvider>();
    final debtProv = context.read<CustomerDebtProvider>();
    final analyticsProv = context.read<AnalyticsProvider>();
    final settingsProv = context.read<SettingsProvider>();
    final onlineOrderProv = context.read<OnlineOrderProvider>();

    try {
      // Panggil loader bertahap dari DatabaseHelper/StorageService
      await authProv.storageService.loadStoreDataInteractive(
        onProgress: (p, msg) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _currentStepMessage = msg;
            if (!_completedSteps.contains(msg) && p > 0.15 && p < 1.0) {
              _completedSteps.add(msg);
            }
          });
        },
      );

      // Segarkan seluruh data di in-memory Provider
      posProv.loadData();
      shiftProv.loadActiveShift();
      debtProv.loadCustomers();
      analyticsProv.calculateSummary();

      // Aktifkan sinkronisasi pesanan online jika cloud aktif
      if (settingsProv.settings.isCloudSyncEnabled) {
        onlineOrderProv.startListening();
      }

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _currentStepMessage = 'Sistem POS Siap Digunakan!';
        _isFinished = true;
      });

      // Beri sedikit jeda transisi visual halus (300ms)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      widget.onCompleted();
    } catch (e) {
      debugPrint('[StoreLoading] Kendala hidrasi database: $e');
      if (mounted) {
        // Fallback aman: Tetap lanjutkan ke dashboard agar operasional tidak terputus
        widget.onCompleted();
      }
    }
  }

  IconData _getRoleIcon() {
    if (widget.user.isKitchen) return Icons.soup_kitchen_rounded;
    if (widget.user.isOwner) return Icons.workspace_premium_rounded;
    return Icons.point_of_sale_rounded;
  }

  Color _getRoleColor() {
    if (widget.user.isKitchen) return Colors.amber.shade600;
    if (widget.user.isOwner) return Colors.purpleAccent;
    return AppTheme.primaryAmber;
  }

  String _getRoleGreeting() {
    if (widget.user.isKitchen) {
      return 'Semangat Bekerja, ${widget.user.name}!';
    }
    if (widget.user.isOwner) {
      return 'Selamat Datang, ${widget.user.name}!';
    }
    return 'Selamat Bertugas, ${widget.user.name}!';
  }

  String _getRoleSubtitle() {
    if (widget.user.isKitchen) {
      return 'Menyiapkan antrean pesanan dapur & stasiun memasak (KDS)...';
    }
    if (widget.user.isOwner) {
      return 'Menyiapkan ringkasan omset penjualan & kontrol outlet...';
    }
    return 'Menyiapkan meja kasir, denah meja & katalog menu...';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final roleColor = _getRoleColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Stack(
        children: [
          // Background Glow Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roleColor.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Nama Restoran
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            settings.storeName.isNotEmpty ? settings.storeName : 'Mini Resto POS',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Icon Berdenyut Halus
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.35),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getRoleIcon(),
                          size: 42,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sapaan Personal
                    Text(
                      _getRoleGreeting(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getRoleSubtitle(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Kotak Progres Modern
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        children: [
                          // Baris Persentase & Status Aktif
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: _isFinished
                                        ? const Icon(Icons.check_circle_rounded,
                                            size: 16, color: AppTheme.emeraldGreen)
                                        : CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(roleColor),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentStepMessage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _isFinished ? AppTheme.emeraldGreen : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(_progress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Progress Bar Halus
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isFinished ? AppTheme.emeraldGreen : roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Indikator Offline-First Resilience
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppTheme.emeraldGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Penyimpanan Lokal Aktif • Transaksi Berfungsi Cepat',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
