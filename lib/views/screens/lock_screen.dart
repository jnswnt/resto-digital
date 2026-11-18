import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Layar Kiosk Numpad (Lock Screen) bergaya modern glassmorphism.
/// Menampilkan input PIN kasir yang estetik, responsif, dan ramah layar sentuh tablet.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
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
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithPin(_enteredPin);
    if (!success) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final auth = context.watch<AuthProvider>();
    final timeFormat = DateFormat('HH:mm:ss');
    String formattedDate;
    try {
      formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime);
    } catch (_) {
      formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Stack(
        children: [
          // Background Glow Orbs (Efek Ambient Modern)
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryAmber.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191A23).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo & Header
                      Container(
                        width: 54,
                        height: 54,
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
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        settings.storeName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${timeFormat.format(_currentTime)} • $formattedDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Indikator Titik PIN Glowing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: isFilled ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: isFilled
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryAmber.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),

                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Grid Numpad Layar Sentuh
                      _buildNumpad(),

                      const SizedBox(height: 22),

                      // Demo Hint Chips
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildQuickPinChip('1234 (Budi)'),
                            _buildQuickPinChip('5678 (Siti)'),
                            _buildQuickPinChip('9999 (Owner)'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tombol Onboarding Tenant Baru
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Setup / Pendaftaran Kafe Baru'),
                              content: const Text(
                                'Buka wizard pendaftaran untuk kafe/resto baru?\n\n'
                                'Anda dapat mengisi nama usaha, PIN owner/kasir baru, memilih template menu, dan mengaktifkan masa Trial 14 Hari.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryAmber,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Buka Onboarding'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            await context.read<SettingsProvider>().resetToOnboarding();
                          }
                        },
                        icon: const Icon(Icons.rocket_launch_outlined, size: 16, color: AppTheme.primaryAmber),
                        label: const Text(
                          'Pendaftaran Kafe Baru (Trial 14 Hari)',
                          style: TextStyle(color: AppTheme.primaryAmber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPinChip(String label) {
    final pin = label.split(' ')[0];
    return InkWell(
      onTap: () {
        setState(() => _enteredPin = pin);
        _verifyPin();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '🔑 $label',
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.clear_rounded,
              label: 'C',
              onPressed: _onClear,
            ),
            _buildNumberButton('0'),
            _buildActionButton(
              icon: Icons.backspace_rounded,
              label: '',
              onPressed: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(number),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 24,
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
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: label.isNotEmpty
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                )
              : Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}
