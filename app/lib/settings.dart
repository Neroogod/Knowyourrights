// App-wide user settings: appearance, accessibility, and privacy.
//
// Mirrors the web Settings surface. Appearance and accessibility are
// device-local (they describe this screen, not the account); the incognito and
// notification preferences are the user's choices about privacy and are also
// persisted locally so they survive a restart. A single ChangeNotifier lets the
// root app rebuild when any of them changes.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one settings instance the app listens to.
final AppSettings appSettings = AppSettings();

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _incognito = false;
  bool _legalChangeAlerts = false;
  String _language = 'en';

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get incognito => _incognito;
  bool get legalChangeAlerts => _legalChangeAlerts;
  String get language => _language;

  static const List<({String code, String name, bool ready})> languages = [
    (code: 'en', name: 'English', ready: true),
    (code: 'pcm', name: 'Nigerian Pidgin', ready: false),
    (code: 'ha', name: 'Hausa', ready: false),
    (code: 'yo', name: 'Yoruba', ready: false),
    (code: 'ig', name: 'Igbo', ready: false),
  ];

  /// Load persisted settings at startup. Safe to call once before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('kyr_theme_mode');
    _themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _textScale = prefs.getDouble('kyr_text_scale') ?? 1.0;
    _highContrast = prefs.getBool('kyr_high_contrast') ?? false;
    _incognito = prefs.getBool('kyr_incognito') ?? false;
    _legalChangeAlerts = prefs.getBool('kyr_legal_alerts') ?? false;
    _language = prefs.getString('kyr_language') ?? 'en';
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    final prefs = await SharedPreferences.getInstance();
    write(prefs);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _save((p) => p.setString('kyr_theme_mode', mode.name));
  }

  void setTextScale(double scale) {
    _textScale = scale;
    _save((p) => p.setDouble('kyr_text_scale', scale));
  }

  void setHighContrast(bool on) {
    _highContrast = on;
    _save((p) => p.setBool('kyr_high_contrast', on));
  }

  void setIncognito(bool on) {
    _incognito = on;
    _save((p) => p.setBool('kyr_incognito', on));
  }

  void setLegalChangeAlerts(bool on) {
    _legalChangeAlerts = on;
    _save((p) => p.setBool('kyr_legal_alerts', on));
  }

  void setLanguage(String code) {
    _language = code;
    _save((p) => p.setString('kyr_language', code));
  }
}
