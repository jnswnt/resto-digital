import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider untuk mengelola tema aplikasi (Light Mode vs Dark Mode).
/// Pilihan tema disimpan secara persisten di SharedPreferences.
class ThemeProvider with ChangeNotifier {
  static const _keyIsDark = 'pos_warkop_is_dark_theme';
  final SharedPreferences _prefs;
  bool _isDarkMode;

  ThemeProvider(this._prefs)
      : _isDarkMode = _prefs.getBool(_keyIsDark) ?? true; // Default Dark mode modern

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Mengubah tema Light / Dark
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    await _prefs.setBool(_keyIsDark, isDark);
    notifyListeners();
  }

  /// Toggle tema
  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }
}
