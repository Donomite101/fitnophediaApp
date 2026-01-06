import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===============================
/// 🎨 COMPLETE THEME PROVIDER SYSTEM
/// ===============================

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Initialize theme from stored preference
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';

    switch (themeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  /// Set specific theme mode and save to SharedPreferences
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (themeMode) {
      case ThemeMode.light:
        await prefs.setString('themeMode', 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString('themeMode', 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString('themeMode', 'system');
        break;
    }
  }

  /// ✅ Toggle between Light and Dark themes manually
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// Detect if currently in dark mode (includes system preference)
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}
