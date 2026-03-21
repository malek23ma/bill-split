import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _apiKeyStorageKey = 'groq_api_key';

  ThemeMode _themeMode = ThemeMode.system;
  String _apiKey = '';
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  String get apiKey => _apiKey;
  bool get loaded => _loaded;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeStr = prefs.getString('theme_mode') ?? 'system';
    _themeMode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // Migrate API key from SharedPreferences to secure storage (one-time)
    final legacyKey = prefs.getString('groq_api_key');
    if (legacyKey != null && legacyKey.isNotEmpty) {
      await _secureStorage.write(key: _apiKeyStorageKey, value: legacyKey);
      await prefs.remove('groq_api_key');
    }

    _apiKey = await _secureStorage.read(key: _apiKeyStorageKey) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _secureStorage.write(key: _apiKeyStorageKey, value: _apiKey);
    notifyListeners();
  }
}
