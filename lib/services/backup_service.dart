import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Service untuk backup dan restore database secara offline.
/// Tidak mengubah skema database (`_dbVersion` tetap 3).
class BackupService {
  static const String _filename = 'mylife_backup.json';
  static const String _version = '1.0';

  final Database database;

  BackupService(this.database);

  Future<File> _getBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// Buat backup seluruh tabel ke file JSON lokal.
  Future<String> backup() async {
    try {
      // Ambil semua data dari setiap tabel dengan urutan kolom yang sesuai
      // schema database_service.dart.
      final notesRows = await database.query('notes');
      final txRows = await database.query('transactions');
      final vaultRows = await database.query('vault_items');

      final Map<String, Object?> data = <String, Object?>{
        'version': _version,
        'timestamp': DateTime.now().toIso8601String(),
        'schema_version': 3,
        'tables': <String, Object?>{
          'notes': List<Object?>.from(notesRows.map((r) => r as Object?)),
          'transactions': List<Object?>.from(txRows.map((r) => r as Object?)),
          'vault_items': List<Object?>.from(vaultRows.map((r) => r as Object?)),
        },
      };

      final file = await _getBackupFile();
      await file.writeAsString(jsonEncode(data));

      return file.path;
    } catch (e) {
      throw Exception('Gagal membuat backup: $e');
    }
  }

  /// Restore database dari file backup JSON.
  /// Memvalidasi struktur sebelum mengosongkan dan mengisi ulang tabel.
  Future<void> restore(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('File backup tidak ditemukan di ${file.path}');
    }

    final raw = await file.readAsString();

    late final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw Exception('File backup rusak: ${e.message}');
    }

    if (decoded is! Map<String, Object?>) {
      throw Exception('Format backup tidak valid (harus JSON object)');
    }

    final Map<String, Object?> data = decoded as Map<String, Object?>;

    // Validasi versi
    final String? version = data['version'] as String?;
    if (version == null || version != _version) {
      throw Exception(
        'Versi backup tidak didukung. Diharapkan $_version, ditemukan: $version',
      );
    }

    // Validasi schema_version
    final int? schemaVer = data['schema_version'] as int?;
    if (schemaVer == null) {
      throw Exception('Field schema_version hilang pada file backup');
    }
    if (schemaVer != 3) {
      throw Exception(
        'Backup dibuat untuk schema v$schemaVer, aplikasi ini mendukung v3',
      );
    }

    // Validasi struktur tabel
    final dynamic rawTables = data['tables'];
    if (rawTables is! Map<String, Object?>) {
      throw Exception('Field "tables" harus berupa objek JSON');
    }
    final Map<String, Object?> tables = rawTables as Map<String, Object?>;

    for (final tableName in <String>['notes', 'transactions', 'vault_items']) {
      if (!tables.containsKey(tableName)) {
        throw Exception('Tabel "$tableName" tidak ditemukan di file backup');
      }
      if (tables[tableName] is! List) {
        throw Exception('Isian tabel "$tableName" harus berupa array JSON');
      }
    }

    // Ekstrak baris tabel sebagai list of map
    final List<Map<String, Object?>> noteRows = (tables['notes'] as List)
        .map((v) => v as Map<String, Object?>)
        .toList();
    final List<Map<String, Object?>> txRows = (tables['transactions'] as List)
        .map((v) => v as Map<String, Object?>)
        .toList();
    final List<Map<String, Object?>> vaultRows = (tables['vault_items'] as List)
        .map((v) => v as Map<String, Object?>)
        .toList();

    // Lakukan restore dalam satu transaksi agar atomic
    try {
      await database.transaction((txn) async {
        await txn.delete('notes');
        await txn.delete('transactions');
        await txn.delete('vault_items');

        for (final row in noteRows) {
          await txn.insert('notes', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in txRows) {
          await txn.insert('transactions', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in vaultRows) {
          await txn.insert('vault_items', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      throw Exception('Gagal melakukan restore: $e');
    }
  }

  /// Hapus file backup jika ada.
  Future<void> deleteBackup() async {
    final file = await _getBackupFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Return the internal backup file path.
  Future<File> getFile() async => _getBackupFile();

  /// Cek apakah ada file backup.
  Future<bool> hasBackup() async {
    return (await _getBackupFile()).exists();
  }

  /// Mendapatkan metadata waktu backup terakhir, atau null bila tidak ada.
  Future<DateTime?> getLastBackupTime() async {
    final file = await _getBackupFile();
    if (!await file.exists()) return null;
    return file.lastModified();
  }
}
