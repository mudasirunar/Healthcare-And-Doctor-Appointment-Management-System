import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local user preferences store for ThemeMode and UI preferences.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const String _themeModeKey = 'app_theme_mode';
  SharedPreferences? _prefs;
  ThemeMode _cachedThemeMode = ThemeMode.system;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cachedThemeMode = _parseThemeMode(_prefs?.getString(_themeModeKey));
    } catch (_) {
      // Safe fallback when native plugin channel is not yet registered (e.g. hot reload or unit test)
    }
  }

  ThemeMode getThemeMode() {
    try {
      final raw = _prefs?.getString(_themeModeKey);
      if (raw != null) {
        _cachedThemeMode = _parseThemeMode(raw);
      }
    } catch (_) {}
    return _cachedThemeMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _cachedThemeMode = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_themeModeKey, value);
    } catch (_) {
      // Prevents unhandled PlatformException(channel-error) if hot-reloaded before native rebuild
    }
  }

  ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
