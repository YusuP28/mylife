import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

/// Provider untuk mode tema aplikasi.
///
/// Pilihan: terang, gelap, sistem (default). Preferensi disimpan secara lokal
/// lewat [PreferencesService] sehingga tetap ada setelah restart.
class ThemeProvider extends ChangeNotifier {
  static const String _key = PreferencesService.kThemeMode;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  List<ThemeChoice> get choices => const <ThemeChoice>[
        ThemeChoice.system,
        ThemeChoice.light,
        ThemeChoice.dark,
      ];

  factory ThemeProvider() {
    return ThemeProvider._();
  }

  ThemeProvider._();

  /// Memuat preferensi tersimpan saat aplikasi dimulai.
  Future<void> load() async {
    final raw = await PreferencesService().getString(_key);
    _mode = _parse(raw);
    notifyListeners();
  }

  void select(ThemeChoice choice) {
    _mode = choice.toMode;
    PreferencesService().setString(_key, choice.name);
    notifyListeners();
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      case null:
      default:
        return ThemeMode.system;
    }
  }
}

enum ThemeChoice {
  system('Sistem'),
  light('Terang'),
  dark('Gelap');

  const ThemeChoice(this.label);

  final String label;
  String get name => runtimeType.toString().split('.').last;

  ThemeMode get toMode {
    switch (this) {
      case ThemeChoice.light:
        return ThemeMode.light;
      case ThemeChoice.dark:
        return ThemeMode.dark;
      case ThemeChoice.system:
      default:
        return ThemeMode.system;
    }
  }
}
