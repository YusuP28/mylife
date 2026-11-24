import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import 'vault_encryption_service.dart';

/// Parameter turunan kunci yang disimpan di sidecar file.
///
/// Sengaja tidak menyimpan kunci maupun password. Yang disimpan hanya salt,
/// jumlah iterasi, dan ciphertext verifier untuk mendeteksi password salah.
class VaultKeyRecord {
  const VaultKeyRecord({
    required this.salt,
    required this.iterations,
    required this.check,
  });

  static const int version = 1;
  static const String kdfName = 'pbkdf2-hmac-sha256';

  final List<int> salt;
  final int iterations;

  /// `enc:v1:...` dari plaintext verifier, dibuat dengan kunci turunan.
  final String check;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'kdf': kdfName,
        'iterations': iterations,
        'salt': base64Encode(salt),
        'check': check,
      };

  factory VaultKeyRecord.fromJson(Map<String, Object?> json) {
    final storedVersion = json['version'];
    if (storedVersion != version) {
      throw FormatException('Versi kunci vault tidak dikenal: $storedVersion');
    }
    if (json['kdf'] != kdfName) {
      throw FormatException('KDF kunci vault tidak dikenal: ${json['kdf']}');
    }

    final salt = json['salt'];
    final iterations = json['iterations'];
    final check = json['check'];
    if (salt is! String || iterations is! int || check is! String) {
      throw const FormatException('File kunci vault tidak lengkap');
    }
    if (iterations <= 0) {
      throw const FormatException('Jumlah iterasi kunci vault tidak valid');
    }

    return VaultKeyRecord(
      salt: base64Decode(salt),
      iterations: iterations,
      check: check,
    );
  }
}

/// Tempat penyimpanan parameter kunci. Dipisah agar bisa diganti/di-test.
abstract class VaultKeyStore {
  Future<VaultKeyRecord?> read();

  Future<void> write(VaultKeyRecord record);

  Future<void> delete();
}

/// Sidecar JSON di direktori dokumen aplikasi (sebelah `mylife.db`).
///
/// Tidak mengubah skema database: salt disimpan di file terpisah.
class FileVaultKeyStore implements VaultKeyStore {
  FileVaultKeyStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const String fileName = 'vault_key.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async =>
      File('${(await _directoryProvider()).path}/$fileName');

  @override
  Future<VaultKeyRecord?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;

    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('File kunci vault rusak');
    }
    return VaultKeyRecord.fromJson(raw);
  }

  @override
  Future<void> write(VaultKeyRecord record) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(record.toJson()), flush: true);
    // Rename atomik supaya crash saat menulis tidak merusak salt.
    await temp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

/// Manajemen kunci Vault: PBKDF2-HMAC-SHA256 + cache kunci di memori.
///
/// Kunci hanya hidup selama sesi. [lock] menghapus byte kunci dari memori.
/// Belum terhubung ke UI atau `DatabaseService` (itu Tahap 4B-3/4B-4).
class VaultKeyManager {
  VaultKeyManager({
    VaultKeyStore? store,
    this.iterations = defaultIterations,
  }) : _store = store ?? FileVaultKeyStore();

  /// OWASP menyarankan >= 210.000 iterasi untuk PBKDF2-HMAC-SHA256.
  /// Naikkan bila perangkat masih nyaman; turunkan hanya untuk test.
  static const int defaultIterations = 210000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  /// Plaintext tetap untuk memverifikasi password saat unlock.
  static const String verifierPlaintext = 'mylife-vault-key-check';

  final VaultKeyStore _store;
  final int iterations;

  SecretKeyData? _key;

  bool get isUnlocked => _key != null;

  SecretKey get requireKey {
    final key = _key;
    if (key == null) {
      throw StateError('Vault terkunci: buka dengan password terlebih dahulu');
    }
    return key;
  }

  Future<bool> hasPassword() async => await _store.read() != null;

  /// Membuat password vault baru. Gagal bila sudah ada.
  Future<void> createPassword(String password) async {
    _validatePassword(password);
    if (await hasPassword()) {
      throw StateError('Password vault sudah ada; gunakan unlock');
    }

    final salt = _randomBytes(saltLength);
    final key = await _deriveKey(password, salt, iterations);
    final check = await AesGcmEncryption(key).encrypt(verifierPlaintext);

    await _store.write(
      VaultKeyRecord(salt: salt, iterations: iterations, check: check),
    );
    _key = key;
  }

  /// `true` bila password benar dan kunci masuk cache sesi.
  Future<bool> unlock(String password) async {
    _validatePassword(password);
    final record = await _store.read();
    if (record == null) {
      throw StateError('Vault belum punya password');
    }

    final key = await _deriveKey(password, record.salt, record.iterations);
    try {
      final plain = await AesGcmEncryption(key).decrypt(record.check);
      if (plain != verifierPlaintext) {
        key.destroy();
        return false;
      }
    } on SecretBoxAuthenticationError {
      key.destroy();
      return false;
    }

    lock();
    _key = key;
    return true;
  }

  /// Menghapus kunci sesi dari memori.
  void lock() {
    _key?.destroy();
    _key = null;
  }

  Future<SecretKeyData> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    final kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
    final derived = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    if (derived is SecretKeyData) return derived;
    return SecretKeyData(await derived.extractBytes());
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static void _validatePassword(String password) {
    if (password.isEmpty) {
      throw ArgumentError.value(
        password,
        'password',
        'Password vault tidak boleh kosong',
      );
    }
  }
}
