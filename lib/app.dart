import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'views/screens/lock_screen.dart';
import 'views/screens/main_dashboard_screen.dart';

/// Widget Utama Aplikasi POS Resto Digital
class PosRestoApp extends StatelessWidget {
  const PosRestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'POS Resto Digital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Jika kasir belum login atau layar terkunci, tampilkan Kiosk Lock Screen
          if (!auth.isAuthenticated) {
            return const LockScreen();
          }
          // Jika kasir sudah login dengan PIN yang valid, tampilkan Dashboard Utama dengan Sidebar modern
          return const MainDashboardScreen();
        },
      ),
    );
  }
}

/// Alias kompatibilitas untuk penamaan lama
typedef PosWarkopApp = PosRestoApp;
