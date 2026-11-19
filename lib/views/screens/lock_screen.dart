import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Kiosk Lock & Login Screen Modern.
/// Mendukung login fleksibel berbasis pemilihan profil staf kasir, input manual Username,
/// dan otentikasi PIN salted-hash touchscreen dengan tampilan glassmorphism elegan.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _keyboardFocus = FocusNode();

  String _enteredPin = '';
  bool _showPinText = false;
  bool _isSubmitting = false;
  UserModel? _selectedUser;

  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Jam digital real-time
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    _usernameCtrl.addListener(_onUsernameChanged);

    // Otomatis pilih akun aktif pertama kali saat dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProv = context.read<SettingsProvider>();
      final users = settingsProv.users.where((u) => u.isActive).toList();
      if (users.isNotEmpty && mounted) {
        // Prioritaskan akun kasir pertama atau owner
        final defaultUser = users.firstWhere((u) => u.isCashier, orElse: () => users.first);
        _selectUser(defaultUser);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _usernameCtrl.removeListener(_onUsernameChanged);
    _usernameCtrl.dispose();
    _usernameFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final text = _usernameCtrl.text.trim().toLowerCase();
    if (_selectedUser != null) {
      final cur = _selectedUser!;
      final match = cur.username.toLowerCase() == text || cur.name.toLowerCase() == text;
      if (!match) {
        // Jika pengguna mengetik nama lain, cari apakah cocok dengan user di database
        final settingsProv = context.read<SettingsProvider>();
        final users = settingsProv.users.where((u) => u.isActive).toList();
        final found = users.where((u) => u.username.toLowerCase() == text || u.name.toLowerCase() == text);
        setState(() {
          _selectedUser = found.isNotEmpty ? found.first : null;
        });
      }
    } else if (text.isNotEmpty) {
      final settingsProv = context.read<SettingsProvider>();
      final users = settingsProv.users.where((u) => u.isActive).toList();
      final found = users.where((u) => u.username.toLowerCase() == text || u.name.toLowerCase() == text);
      if (found.isNotEmpty) {
        setState(() {
          _selectedUser = found.first;
        });
      }
    }
  }

  void _selectUser(UserModel user) {
    setState(() {
      _selectedUser = user;
      _usernameCtrl.text = user.username.isNotEmpty ? user.username : user.name;
      _enteredPin = '';
    });
    // Pindahkan fokus keyboard fisik ke PIN
    _keyboardFocus.requestFocus();
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUser = null;
      _usernameCtrl.clear();
      _enteredPin = '';
    });
  }

  void _onKeyPress(String val) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += val;
      });

      if (_enteredPin.length == 4 || _enteredPin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
    });
  }

  Future<void> _verifyPin() async {
    if (_isSubmitting) return;
    final pin = _enteredPin;
    final username = _usernameCtrl.text.trim();

    if (pin.length < 4) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan minimal 4 digit PIN.'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithPin(pin, username: username.isNotEmpty ? username : null);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      // Getar visual singkat sebelum menghapus input PIN
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
          });
        }
      });
    }
  }

  /// Menangani input keyboard fisik laptop/desktop
  KeyEventResult _handlePhysicalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onBackspace();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _verifyPin();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.escape) {
        _onClear();
        return KeyEventResult.handled;
      } else if (key.keyLabel.length == 1 && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
        _onKeyPress(key.keyLabel);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final auth = context.watch<AuthProvider>();
    final users = context.watch<SettingsProvider>().users.where((u) => u.isActive).toList();

    final timeFormat = DateFormat('HH:mm:ss');
    String formattedDate;
    try {
      formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime);
    } catch (_) {
      formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);
    }

    final isWide = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      body: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handlePhysicalKeyEvent,
        child: Stack(
          children: [
            // Ambient Orbs (Efek Pencahayaan Halus di Sudut Layar)
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryAmber.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 880 : 480,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161824).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: isWide
                        ? _buildSplitLayout(settings, auth, users, timeFormat, formattedDate)
                        : _buildCompactLayout(settings, auth, users, timeFormat, formattedDate),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LAYOUT SPLIT (TABLET LANDSCAPE & DESKTOP >= 820px)
  // ==========================================================================
  Widget _buildSplitLayout(
    SettingsModel settings,
    AuthProvider auth,
    List<UserModel> users,
    DateFormat timeFormat,
    String formattedDate,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sisi Kiri: Info Toko, Input Username, & Quick User Chips
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStoreHeader(settings, timeFormat, formattedDate),
                const SizedBox(height: 24),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 20),

                // Kolom Input Username Kasir
                _buildUsernameField(),
                const SizedBox(height: 18),

                // Daftar Akun Pengguna Terdaftar (Quick Selectors)
                Text(
                  'AKUN STAF TERDAFTAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _buildUserChipList(users),

                const SizedBox(height: 28),
                _buildFooterLinks(),
              ],
            ),
          ),

          const SizedBox(width: 32),
          Container(
            width: 1,
            height: 480,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 32),

          // Sisi Kanan: Status Akun Terpilih, Indikator PIN, & Numpad
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSelectedUserBadge(),
                const SizedBox(height: 16),
                _buildPinDotsIndicator(),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    auth.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildNumpadGrid(),
                const SizedBox(height: 18),
                _buildSubmitButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LAYOUT COMPACT (SMARTPHONE / TABLET PORTRAIT < 820px)
  // ==========================================================================
  Widget _buildCompactLayout(
    SettingsModel settings,
    AuthProvider auth,
    List<UserModel> users,
    DateFormat timeFormat,
    String formattedDate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStoreHeader(settings, timeFormat, formattedDate),
          const SizedBox(height: 20),
          _buildUsernameField(),
          const SizedBox(height: 14),

          // Horizontal Quick Chips
          _buildUserChipList(users, isHorizontal: true),
          const SizedBox(height: 20),

          _buildSelectedUserBadge(),
          const SizedBox(height: 14),
          _buildPinDotsIndicator(),

          if (auth.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              auth.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 20),

          _buildNumpadGrid(),
          const SizedBox(height: 16),
          _buildSubmitButton(),
          const SizedBox(height: 16),
          _buildFooterLinks(),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET-WIDGET KOMPONEN
  // ==========================================================================

  Widget _buildStoreHeader(
    SettingsModel settings,
    DateFormat timeFormat,
    String formattedDate,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.storeName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${settings.restoId.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${timeFormat.format(_currentTime)} • $formattedDate',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kolom input Username kasir interaktif
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'USERNAME KASIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 0.8,
              ),
            ),
            if (_usernameCtrl.text.isNotEmpty)
              InkWell(
                onTap: _clearSelectedUser,
                child: const Text(
                  'Bersihkan',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedUser != null
                  ? AppTheme.primaryAmber.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Ketik username kasir (misal: owner, kasir1)...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                _selectedUser != null ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                color: _selectedUser != null ? AppTheme.primaryAmber : Colors.white54,
                size: 20,
              ),
              suffixIcon: _usernameCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                      onPressed: _clearSelectedUser,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) {
              _keyboardFocus.requestFocus();
            },
          ),
        ),
      ],
    );
  }

  /// Daftar chip staf aktif untuk memilih kasir bertugas secara instan
  Widget _buildUserChipList(List<UserModel> users, {bool isHorizontal = false}) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Belum ada akun kasir terdaftar. Masukkan PIN Master Owner untuk melanjutkan.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      );
    }

    if (isHorizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: users.map((u) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildUserCardItem(u),
          )).toList(),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final u = users[index];
          return _buildUserCardItem(u);
        },
      ),
    );
  }

  Widget _buildUserCardItem(UserModel u) {
    final isSelected = _selectedUser?.id == u.id;
    final roleColor = u.isOwner
        ? AppTheme.primaryAmber
        : (u.isKitchen ? const Color(0xFF10B981) : const Color(0xFF3B82F6));
    final roleName = u.isOwner ? 'Owner' : (u.isKitchen ? 'Koki Dapur' : 'Kasir');

    return InkWell(
      onTap: () => _selectUser(u),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? roleColor.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? roleColor : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: roleColor.withValues(alpha: 0.25),
              child: Text(
                u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    u.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${u.username.isNotEmpty ? u.username : "kasir"} • $roleName',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: roleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 16, color: roleColor),
            ],
          ],
        ),
      ),
    );
  }

  /// Badge status kasir terpilih di atas indikator PIN
  Widget _buildSelectedUserBadge() {
    final user = _selectedUser;
    final userName = user?.name ?? (_usernameCtrl.text.isNotEmpty ? _usernameCtrl.text : 'Kasir Bertugas');
    final roleName = user?.isOwner == true ? 'Pemilik Usaha (Owner)' : (user?.isKitchen == true ? 'Koki Dapur' : 'Kasir Toko');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryAmber.withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 14, color: AppTheme.primaryAmber),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Masuk Sebagai: $userName ($roleName)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Indikator titik PIN glowing 4 digit (mendukung hingga 6 digit)
  Widget _buildPinDotsIndicator() {
    final dotCount = _enteredPin.length > 4 ? 6 : 4;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dotCount, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: isFilled ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryAmber.withValues(alpha: 0.55),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : [],
                  ),
                  child: (_showPinText && isFilled)
                      ? Center(
                          child: Text(
                            _enteredPin[index],
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : null,
                );
              }),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                _showPinText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: Colors.white54,
              ),
              tooltip: _showPinText ? 'Sembunyikan Angka PIN' : 'Lihat Angka PIN',
              onPressed: () => setState(() => _showPinText = !_showPinText),
            ),
          ],
        ),
      ],
    );
  }

  /// Numpad touchscreen bergaya modern squircle
  Widget _buildNumpadGrid() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 10),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 10),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: Icons.clear_rounded,
                label: 'C',
                tooltip: 'Bersihkan PIN',
                onPressed: _onClear,
              ),
              _buildNumberButton('0'),
              _buildActionButton(
                icon: Icons.backspace_rounded,
                label: '',
                tooltip: 'Hapus Satu Digit',
                onPressed: _onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(number),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 72,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 72,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: label.isNotEmpty
                ? Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  )
                : Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  /// Tombol utama "Buka Kasir POS"
  Widget _buildSubmitButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _verifyPin,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.storefront_rounded, size: 20),
          label: Text(
            _isSubmitting ? 'Memverifikasi...' : 'Buka Kasir POS',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAmber,
            foregroundColor: Colors.black,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  /// Tautan utilitas di bagian bawah: Lepas Tautan / Ganti Outlet
  Widget _buildFooterLinks() {
    return Center(
      child: TextButton.icon(
        onPressed: _showUnlinkDialog,
        icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.white54),
        label: const Text(
          'Lepas Tautan / Ganti Outlet Resto',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Modal konfirmasi pemutusan tautan tablet dari outlet saat ini
  Future<void> _showUnlinkDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: AppTheme.dangerRed),
            SizedBox(width: 10),
            Text('Lepas Tautan Tablet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda ingin memutuskan perangkat ini dari restoran saat ini?\n\n'
          'Aplikasi akan kembali ke tampilan onboarding untuk mendaftarkan restoran baru atau menghubungkan ke cabang lain.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Lepas Tautan'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await GoogleSignIn().signOut().catchError((_) => null);
      if (!mounted) return;
      final authProv = context.read<AuthProvider>();
      final settingsProv = context.read<SettingsProvider>();
      authProv.logout();
      await settingsProv.resetToOnboarding();
    }
  }
}
