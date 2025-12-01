import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider(this._storageService) {
    _load();
  }

  final StorageService _storageService;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void _load() {
    final saved = _storageService.getString('theme_mode');
    _themeMode = _parseTheme(saved);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storageService.setString('theme_mode', mode.name);
    notifyListeners();
  }

  ThemeMode _parseTheme(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
