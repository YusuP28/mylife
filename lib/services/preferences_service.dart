import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Layanan preferensi sederhana berbasis file JSON lokal.
/// Menyimpan key-value pair string; serialisasi otomatis ke/dari disk.
class PreferencesService {
  static const String _filename = 'preferences.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<Map<String, String>> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return <String, String>{};
      final raw = await f.readAsString();
      return Map<String, String>.from(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _save(Map<String, String> prefs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(prefs));
  }

  Future<String?> getString(String key) async {
    final prefs = await _load();
    return prefs[key];
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _load();
    prefs[key] = value;
    await _save(prefs);
  }

  Future<void> removeString(String key) async {
    final prefs = await _load();
    prefs.remove(key);
    await _save(prefs);
  }

  static const String kThemeMode = 'theme_mode';
}
