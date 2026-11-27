import 'vault_encryption_service.dart';

/// Enkripsi/dekripsi field sensitif Vault tepat di batas database.
///
/// Model (`VaultItem`), provider, dan UI tetap memakai plaintext di memori.
/// Dipisah dari `DatabaseService` supaya bisa diuji tanpa sqflite.
class VaultRowCodec {
  const VaultRowCodec(this.encryption);

  /// Kolom sensitif yang dienkripsi (password, notes, totp_uri berisi secret).
  static const List<String> sensitiveFields = <String>['password', 'notes', 'totp_uri'];

  final VaultEncryptionService encryption;

  bool get encryptsData => encryption.encryptsData;

  /// Mengenkripsi field sensitif yang masih plaintext. Idempoten.
  Future<Map<String, Object?>> encryptRow(Map<String, Object?> row) async {
    if (!encryptsData) return row;

    final result = Map<String, Object?>.of(row);
    for (final field in sensitiveFields) {
      final value = result[field];
      if (value is! String || value.isEmpty) continue;
      if (encryption.isEncrypted(value)) continue;
      result[field] = await encryption.encrypt(value);
    }
    return result;
  }

  /// Mendekripsi field sensitif. Nilai lama tanpa prefix lolos apa adanya.
  Future<Map<String, Object?>> decryptRow(Map<String, Object?> row) async {
    if (!encryptsData) return row;

    final result = Map<String, Object?>.of(row);
    for (final field in sensitiveFields) {
      final value = result[field];
      if (value is! String || value.isEmpty) continue;
      result[field] = await encryption.decrypt(value);
    }
    return result;
  }

  /// `true` bila baris lama masih menyimpan plaintext di field sensitif.
  bool rowNeedsMigration(Map<String, Object?> row) {
    if (!encryptsData) return false;

    for (final field in sensitiveFields) {
      final value = row[field];
      if (value is String && value.isNotEmpty && !encryption.isEncrypted(value)) {
        return true;
      }
    }
    return false;
  }
}
