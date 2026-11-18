import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/online_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'owner_profile_dialog.dart';

/// Sidebar navigasi modern yang mengadopsi estetika referensi desain:
/// window dots, brand logo, search pill, item ber-badge angka, segmented theme switcher,
/// dan kartu profil kasir di bagian bawah.
class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int index) onItemSelected;
  final bool isDrawerMode;
  final VoidCallback? onCloseDrawer;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isDrawerMode = false,
    this.onCloseDrawer,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isCollapsed = false;
  bool get isCollapsed => widget.isDrawerMode ? false : _isCollapsed;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final auth = context.watch<AuthProvider>();
    final pos = context.watch<PosProvider>();
    final debt = context.watch<CustomerDebtProvider>();
    final online = context.watch<OnlineOrderProvider>();

    final openTabCount = pos.openOrders.length + online.pendingCount;
    final debtorCount = debt.debtors.length;

    final sidebarBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final searchBg = isDark ? AppTheme.darkSearchBg : AppTheme.lightSearchBg;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: widget.isDrawerMode ? double.infinity : (isCollapsed ? 82 : 260),
          margin: widget.isDrawerMode
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
              : const EdgeInsets.only(left: 14, top: 14, bottom: 14),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 10 : 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: sidebarBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Window Traffic Dots (macOS Style) + Tombol Close Drawer di Mobile
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildTrafficDot(const Color(0xFFFF5F56)), // Merah
                        const SizedBox(width: 7),
                        _buildTrafficDot(const Color(0xFFFFBD2E)), // Kuning
                        const SizedBox(width: 7),
                        _buildTrafficDot(const Color(0xFF27C93F)), // Hijau
                      ],
                    ),
                    if (widget.isDrawerMode && widget.onCloseDrawer != null)
                      InkWell(
                        onTap: widget.onCloseDrawer,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Brand Header (Logo + Resto Digital)
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resto Digital',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // 3. Search Pill
              if (!isCollapsed) ...[
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: textMuted, fontSize: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            pos.setSearchQuery(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 4. Section Label "Menu"
              if (!isCollapsed)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // 5. Menu Items
              if (auth.currentUser?.isKitchen == true) ...[
                // Khusus Koki Dapur: Tampilan Dapur KDS & Status Meja
                _buildNavItem(
                  index: 2,
                  icon: Icons.soup_kitchen_outlined,
                  activeIcon: Icons.soup_kitchen_rounded,
                  label: 'Dapur (KDS)',
                  badgeCount: pos.kitchenOrders.length,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 1,
                  icon: Icons.table_restaurant_outlined,
                  activeIcon: Icons.table_restaurant_rounded,
                  label: 'Pesanan Meja',
                  badgeCount: openTabCount,
                  isDark: isDark,
                ),
              ] else ...[
                // Menu Lengkap untuk Kasir POS & Owner
                _buildNavItem(
                  index: 0,
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  label: 'Kasir (POS)',
                  badgeCount: 0,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 1,
                  icon: Icons.table_restaurant_outlined,
                  activeIcon: Icons.table_restaurant_rounded,
                  label: 'Pesanan Meja',
                  badgeCount: openTabCount,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 2,
                  icon: Icons.soup_kitchen_outlined,
                  activeIcon: Icons.soup_kitchen_rounded,
                  label: 'Dapur (KDS)',
                  badgeCount: pos.kitchenOrders.length,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 3,
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  label: 'Buku Kasbon',
                  badgeCount: debtorCount,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 4,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Katalog Produk',
                  badgeCount: 0,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 5,
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: 'Shift Kasir',
                  badgeCount: 0,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 6,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Riwayat Transaksi',
                  badgeCount: 0,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 7,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Laporan & Analitik',
                  badgeCount: 0,
                  isDark: isDark,
                ),

                const SizedBox(height: 14),

                // 6. Section "Pengaturan"
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 8),
                    child: Text(
                      'Sistem',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                _buildNavItem(
                  index: 8,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Pengaturan',
                  badgeCount: 0,
                  isDark: isDark,
                ),
              ],

              const Spacer(),

              // 7. Segmented Theme Switcher (Light / Dark) Sesuai Gambar Referensi
              if (!isCollapsed) ...[
                _buildSegmentedThemeSwitch(theme, isDark),
                const SizedBox(height: 14),
              ] else ...[
                IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? AppTheme.primaryAmber : Colors.orange,
                  ),
                  tooltip: 'Ganti Tema',
                  onPressed: () => theme.toggleTheme(),
                ),
                const SizedBox(height: 8),
              ],

              // 8. Profile Card di Bagian Kaki Sidebar
              _buildUserProfileCard(auth, isDark, textColor, textMuted),
            ],
          ),
        ),

        // 9. Floating Collapse Button (< / >) di Tepi Kanan Sidebar (Hanya desktop/tablet)
        if (!widget.isDrawerMode)
          Positioned(
            top: 76,
            right: -8,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isCollapsed = !_isCollapsed;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrafficDot(Color color) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int badgeCount,
    required bool isDark,
  }) {
    final isSelected = widget.selectedIndex == index;

    final activeBg = isDark ? const Color(0xFF2C2F3D) : const Color(0xFFEFF2F7);
    final activeText = isDark ? Colors.white : Colors.black;
    final inactiveText = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return InkWell(
      onTap: () => widget.onItemSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 0 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: isSelected ? (isDark ? AppTheme.primaryAmber : AppTheme.primaryCoffee) : inactiveText,
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeText : inactiveText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626), // Merah menyala seperti referensi
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Segmented Pill Switcher (Light / Dark)
  Widget _buildSegmentedThemeSwitch(ThemeProvider theme, bool isDark) {
    final containerBg = isDark ? const Color(0xFF282A36) : const Color(0xFFE5E7EB);
    final activePillBg = isDark ? const Color(0xFF383A48) : Colors.white;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Tombol Light
          Expanded(
            child: InkWell(
              onTap: () => theme.setDarkMode(false),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !isDark ? activePillBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14,
                      color: !isDark ? Colors.black : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Light',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !isDark ? FontWeight.bold : FontWeight.w500,
                        color: !isDark ? Colors.black : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tombol Dark
          Expanded(
            child: InkWell(
              onTap: () => theme.setDarkMode(true),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isDark ? activePillBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nightlight_outlined,
                      size: 14,
                      color: isDark ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dark',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isDark ? FontWeight.bold : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black54,
                      ),
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

  // Profile Card di Kaki Sidebar
  Widget _buildUserProfileCard(
    AuthProvider auth,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    final user = auth.currentUser;
    final userName = user?.name ?? 'Kasir Bertugas';
    final roleLabel = user?.isOwner == true
        ? 'Pemilik Resto'
        : (user?.isKitchen == true ? 'Koki Dapur' : 'Kasir Aktif');

    final isOwner = user?.isOwner == true;

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          // Avatar Kasir / Owner
          InkWell(
            onTap: isOwner ? () => OwnerProfileDialog.show(context) : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'K',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: isOwner ? () => OwnerProfileDialog.show(context) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_rounded, size: 12, color: AppTheme.primaryAmber),
                          ],
                        ],
                      ),
                      Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.lock_clock_outlined, size: 18, color: textMuted),
              tooltip: 'Kunci Layar (Ganti Kasir)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => auth.lockScreen(),
            ),
          ],
        ],
      ),
    );
  }
}
