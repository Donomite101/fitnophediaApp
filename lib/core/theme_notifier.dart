import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  bool _initialized = false;

  ThemeMode get mode => _mode;
  bool get initialized => _initialized;

  ThemeNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode') ?? 'system';
    _mode = saved == 'light' ? ThemeMode.light : (saved == 'dark' ? ThemeMode.dark : ThemeMode.system);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode newMode) async {
    if (newMode == _mode) return;
    _mode = newMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = newMode == ThemeMode.light ? 'light' : (newMode == ThemeMode.dark ? 'dark' : 'system');
    await prefs.setString('app_theme_mode', str);
  }
}
