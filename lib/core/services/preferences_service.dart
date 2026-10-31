import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local user preferences store for ThemeMode, Notification Read State, and Alert Toggles.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const String _themeModeKey = 'app_theme_mode';
  static const String _readNotificationIdsKey = 'admin_read_notification_ids';
  static const String _alertedNotificationIdsKey = 'admin_alerted_notification_ids';
  static const String _doctorVerifyAlertsKey = 'admin_pref_doctor_verify_alerts';
  static const String _appointmentAlertsKey = 'admin_pref_appointment_alerts';

  SharedPreferences? _prefs;
  ThemeMode _cachedThemeMode = ThemeMode.system;
  final Set<String> _cachedReadIds = <String>{};
  final Set<String> _cachedAlertedIds = <String>{};
  bool _cachedDoctorVerifyAlerts = true;
  bool _cachedAppointmentAlerts = true;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cachedThemeMode = _parseThemeMode(_prefs?.getString(_themeModeKey));
      final storedRead = _prefs?.getStringList(_readNotificationIdsKey);
      if (storedRead != null) {
        _cachedReadIds.addAll(storedRead);
      }
      final storedAlerted = _prefs?.getStringList(_alertedNotificationIdsKey);
      if (storedAlerted != null) {
        _cachedAlertedIds.addAll(storedAlerted);
      }
      _cachedDoctorVerifyAlerts = _prefs?.getBool(_doctorVerifyAlertsKey) ?? true;
      _cachedAppointmentAlerts = _prefs?.getBool(_appointmentAlertsKey) ?? true;
    } catch (_) {
      // Safe fallback when native plugin channel is not yet registered
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
    } catch (_) {}
  }

  Set<String> getReadNotificationIds() {
    try {
      final stored = _prefs?.getStringList(_readNotificationIdsKey);
      if (stored != null) {
        _cachedReadIds.addAll(stored);
      }
    } catch (_) {}
    return Set<String>.unmodifiable(_cachedReadIds);
  }

  Future<void> markNotificationRead(String id) async {
    _cachedReadIds.add(id);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setStringList(_readNotificationIdsKey, _cachedReadIds.toList());
    } catch (_) {}
  }

  Future<void> markNotificationsRead(Iterable<String> ids) async {
    _cachedReadIds.addAll(ids);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setStringList(_readNotificationIdsKey, _cachedReadIds.toList());
    } catch (_) {}
  }

  Set<String> getAlertedNotificationIds() {
    return Set<String>.unmodifiable(_cachedAlertedIds);
  }

  Future<void> markNotificationAlerted(String id) async {
    _cachedAlertedIds.add(id);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setStringList(_alertedNotificationIdsKey, _cachedAlertedIds.toList());
    } catch (_) {}
  }

  bool getDoctorVerificationAlertsEnabled() => _cachedDoctorVerifyAlerts;

  Future<void> setDoctorVerificationAlertsEnabled(bool enabled) async {
    _cachedDoctorVerifyAlerts = enabled;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(_doctorVerifyAlertsKey, enabled);
    } catch (_) {}
  }

  bool getAppointmentAlertsEnabled() => _cachedAppointmentAlerts;

  Future<void> setAppointmentAlertsEnabled(bool enabled) async {
    _cachedAppointmentAlerts = enabled;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(_appointmentAlertsKey, enabled);
    } catch (_) {}
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
