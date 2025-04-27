import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themePrefKey = 'themeMode';
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    loadThemeMode(); // Load saved theme on initialization
  }
  // Load theme preference from SharedPreferences
  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Get saved index, default to system
    final int themeIndex = prefs.getInt(_themePrefKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  // Set and save theme preference
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners(); // Notify UI immediately

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, mode.index); // Save the index
  }
}
