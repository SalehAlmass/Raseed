import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode_index';
  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeService(this._prefs) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  int get themeModeIndex {
    switch (_themeMode) {
      case ThemeMode.light:
        return 0;
      case ThemeMode.dark:
        return 1;
      case ThemeMode.system:
        return 2;
    }
  }

  Future<void> _loadTheme() async {
    final index = _prefs.getInt(_themeKey) ?? 2;
    _themeMode = ThemeMode.values[index % 3];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setThemeModeByIndex(int index) async {
    final mode = ThemeMode.values[index % 3];
    await setThemeMode(mode);
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}
