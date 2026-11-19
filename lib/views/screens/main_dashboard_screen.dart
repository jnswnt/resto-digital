import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'pos_screen.dart';
import 'open_tabs_screen.dart';
import 'debts_screen.dart';
import 'products_screen.dart';
import 'shift_screen.dart';
import 'transaction_history_screen.dart';
import 'sales_analytics_screen.dart';
import 'settings_screen.dart';
import 'kitchen_display_screen.dart';

/// Layar Dashboard Utama yang menyatukan AppSidebar di sisi kiri
/// dan Konten Layar (POS, Open Tab, Kasbon, Katalog Produk, Shift, Pengaturan) di sisi kanan.
/// Mendukung mode Tablet/Desktop (Sidebar Permanen) dan mode Mobile (Drawer + Bottom Nav Bar).
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int _previousIndex = 0;

  /// Flag konfigurasi BottomNavigationBar mobile.
  /// Di-set false sementara sesuai permintaan pengguna (tidak dihapus, mudah diaktifkan kembali).
  /// ubah menjadi true jika ingin mengaktifkan NavigationBar.
  static const bool _enableMobileBottomNav = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      // Jika yang login adalah Koki Dapur, otomatis buka tampilan Dapur (KDS)
      if (auth.currentUser?.isKitchen == true) {
        setState(() => _currentIndex = 2);
      }
    });
  }

  void _onNavigationSelected(int index) {
    final auth = context.read<AuthProvider>();

    // KEBIJAKAN AUTO-LOCK ON LEAVE:
    // Jika kasir (bukan Owner) meninggalkan halaman yang diproteksi Owner (index 7 & 8)
    // dan kembali ke halaman biasa kasir, otomatis kunci kembali akses Owner
    if (auth.currentUser?.isOwner != true) {
      if ((_currentIndex == 7 || _currentIndex == 8) && index != _currentIndex) {
        auth.lockOwnerMode();
      }
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final pos = context.watch<PosProvider>();
    final debt = context.watch<CustomerDebtProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: isDark
                  ? AppTheme.darkSidebar
                  : AppTheme.lightSidebar,
              elevation: 16,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: AppSidebar(
                  selectedIndex: _currentIndex,
                  isDrawerMode: true,
                  onCloseDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
                  onItemSelected: (idx) {
                    _onNavigationSelected(idx);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
              ),
            ),
      // Fitur BottomNavigationBar mobile sementara di-hidden sesuai permintaan (tidak dihapus)
      bottomNavigationBar: (isDesktop || !_enableMobileBottomNav)
          ? null
          : _buildMobileBottomNav(isDark, pos, debt),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar Kiri (Hanya tampil permanen pada layar tablet/desktop)
            if (isDesktop)
              AppSidebar(
                selectedIndex: _currentIndex,
                onItemSelected: _onNavigationSelected,
              ),

            // Konten Utama di Sisi Kanan
            Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: isDesktop ? 8 : 4,
                  right: isDesktop ? 14 : 4,
                  top: isDesktop ? 14 : 4,
                  bottom: isDesktop ? 14 : 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191A23) : Colors.white,
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF282B38)
                        : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      // 0: Kasir POS
                      PosScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 1: Pesanan Meja / Open Tab
                      OpenTabsScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                        onSelectTabForEdit: (order) {
                          pos.loadOpenTabForEdit(order);
                          setState(
                            () => _currentIndex = 0,
                          ); // Alihkan kembali ke Kasir POS
                        },
                      ),
                      // 2: Dapur Resto (KDS)
                      KitchenDisplayScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 3: Buku Kasbon
                      DebtsScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 4: Katalog Produk (Mandiri)
                      ProductsScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 5: Shift Kasir
                      ShiftScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 6: Riwayat Transaksi (Halaman Mandiri)
                      TransactionHistoryScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                      ),
                      // 7: Laporan & Analitik Owner
                      SalesAnalyticsScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                        onCancel: () {
                          final target = (_previousIndex != 7 && _previousIndex != 8) ? _previousIndex : 0;
                          _onNavigationSelected(target);
                        },
                      ),
                      // 8: Pengaturan Owner
                      SettingsScreen(
                        embedded: true,
                        onOpenMenuDrawer: isDesktop ? null : _openDrawer,
                        onCancel: () {
                          final target = (_previousIndex != 7 && _previousIndex != 8) ? _previousIndex : 0;
                          _onNavigationSelected(target);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Komponen BottomNavigationBar modern untuk perangkat smartphone/mobile.
  /// Disimpan rapi agar dapat langsung diaktifkan kembali jika dibutuhkan.
  Widget _buildMobileBottomNav(
    bool isDark,
    PosProvider pos,
    CustomerDebtProvider debt,
  ) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onNavigationSelected,
      backgroundColor: isDark ? const Color(0xFF14151D) : Colors.white,
      elevation: 8,
      indicatorColor: AppTheme.primaryAmber.withValues(
        alpha: isDark ? 0.25 : 0.35,
      ),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(
            Icons.storefront_rounded,
            color: AppTheme.primaryAmber,
          ),
          label: 'Kasir',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: pos.openOrders.isNotEmpty,
            label: Text('${pos.openOrders.length}'),
            child: const Icon(Icons.table_restaurant_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: pos.openOrders.isNotEmpty,
            label: Text('${pos.openOrders.length}'),
            child: const Icon(
              Icons.table_restaurant_rounded,
              color: AppTheme.primaryAmber,
            ),
          ),
          label: 'Meja',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: debt.debtors.isNotEmpty,
            label: Text('${debt.debtors.length}'),
            child: const Icon(Icons.menu_book_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: debt.debtors.isNotEmpty,
            label: Text('${debt.debtors.length}'),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppTheme.primaryAmber,
            ),
          ),
          label: 'Kasbon',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(
            Icons.inventory_2_rounded,
            color: AppTheme.primaryAmber,
          ),
          label: 'Katalog',
        ),
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(
            Icons.account_balance_wallet_rounded,
            color: AppTheme.primaryAmber,
          ),
          label: 'Shift',
        ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(
            Icons.settings_rounded,
            color: AppTheme.primaryAmber,
          ),
          label: 'Sistem',
        ),
      ],
    );
  }
}

