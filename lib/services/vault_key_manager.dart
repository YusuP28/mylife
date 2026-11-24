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
    this.previous,
  });

  static const int version = 1;
  static const String kdfName = 'pbkdf2-hmac-sha256';

  final List<int> salt;
  final int iterations;

  /// `enc:v1:...` dari plaintext verifier, dibuat dengan kunci turunan.
  final String check;

  /// Parameter kunci lama yang masih boleh dipakai membuka data.
  ///
  /// Hanya terisi selama ganti password belum final: bila proses terputus
  /// setelah record baru ditulis tetapi sebelum semua baris dienkripsi ulang,
  /// password lama tetap bisa membuka data lama.
  final VaultKeyRecord? previous;

  VaultKeyRecord withoutPrevious() => VaultKeyRecord(
        salt: salt,
        iterations: iterations,
        check: check,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'kdf': kdfName,
        'iterations': iterations,
        'salt': base64Encode(salt),
        'check': check,
        if (previous != null) 'previous': previous!._paramsJson(),
      };

  Map<String, Object?> _paramsJson() => <String, Object?>{
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

    final previousJson = json['previous'];
    VaultKeyRecord? previous;
    if (previousJson != null) {
      if (previousJson is! Map) {
        throw const FormatException('Parameter kunci lama tidak valid');
      }
      previous = VaultKeyRecord._fromParams(
        Map<String, Object?>.from(previousJson),
      );
    }

    return VaultKeyRecord(
      salt: base64Decode(salt),
      iterations: iterations,
      check: check,
      previous: previous,
    );
  }

  factory VaultKeyRecord._fromParams(Map<String, Object?> json) {
    final salt = json['salt'];
    final iterations = json['iterations'];
    final check = json['check'];
    if (salt is! String || iterations is! int || check is! String) {
      throw const FormatException('Parameter kunci lama tidak lengkap');
    }
    if (iterations <= 0) {
      throw const FormatException('Jumlah iterasi kunci lama tidak valid');
    }

    return VaultKeyRecord(
      salt: base64Decode(salt),
      iterations: iterations,
      check: check,
    );
  }
}

/// Kunci baru yang sudah diturunkan tetapi belum dipasang ke penyimpanan.
///
/// Dipisah dari [VaultKeyManager] supaya pemanggil bisa menentukan urutan
/// aman: tulis record sementara → enkripsi ulang database → finalisasi.
class VaultKeyChange {
  const VaultKeyChange({
    required this.key,
    required this.record,
    required this.original,
  });

  final SecretKeyData key;

  /// Record baru: primary = kunci baru, `previous` = kunci lama.
  final VaultKeyRecord record;

  /// Snapshot record sebelum perubahan, untuk rollback.
  final VaultKeyRecord original;
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

  /// Record yang benar-benar cocok saat unlock. Dipakai sebagai cadangan
  /// `previous` ketika ganti password, termasuk setelah pemulihan dari rotasi
  /// yang terputus.
  VaultKeyRecord? _activeRecord;

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

    final record =
        VaultKeyRecord(salt: salt, iterations: iterations, check: check);
    await _store.write(record);
    _key = key;
    _activeRecord = record;
  }

  /// `true` bila password benar dan kunci masuk cache sesi.
  ///
  /// Bila record menyimpan kunci lama (`previous`) karena ganti password
  /// terputus, password lama juga diterima agar data tetap bisa dibuka.
  Future<bool> unlock(String password) async {
    _validatePassword(password);
    final record = await _store.read();
    if (record == null) {
      throw StateError('Vault belum punya password');
    }

    var matched = record;
    var key = await _tryKey(password, record);
    final previous = record.previous;
    if (key == null && previous != null) {
      key = await _tryKey(password, previous);
      matched = previous;
    }
    if (key == null) return false;

    lock();
    _key = key;
    _activeRecord = matched;
    return true;
  }

  /// `true` bila password cocok dengan kunci aktif atau kunci lama yang masih
  /// menunggu rotasi selesai. Tidak mengubah kunci sesi.
  Future<bool> verifyPassword(String password) async {
    _validatePassword(password);
    final record = await _store.read();
    if (record == null) return false;

    final primary = await _tryKey(password, record);
    if (primary != null) {
      primary.destroy();
      return true;
    }

    final previous = record.previous;
    if (previous == null) return false;

    final old = await _tryKey(password, previous);
    if (old == null) return false;
    old.destroy();
    return true;
  }

  /// Menyiapkan kunci baru (salt baru, iterasi sama) tanpa menyentuh data.
  Future<VaultKeyChange> preparePasswordChange(String newPassword) async {
    _validatePassword(newPassword);
    final current = await _store.read();
    if (current == null) {
      throw StateError('Vault belum punya password');
    }

    final salt = _randomBytes(saltLength);
    final key = await _deriveKey(newPassword, salt, iterations);
    final check = await AesGcmEncryption(key).encrypt(verifierPlaintext);

    // Cadangan harus record yang cocok dengan kunci sesi saat ini, bukan
    // selalu record primary (bisa berbeda setelah pemulihan rotasi terputus).
    final active = _activeRecord ?? current;

    return VaultKeyChange(
      key: key,
      record: VaultKeyRecord(
        salt: salt,
        iterations: iterations,
        check: check,
        previous: active.withoutPrevious(),
      ),
      original: current,
    );
  }

  /// Menulis record baru beserta kunci lama sebagai cadangan.
  ///
  /// Dipanggil sebelum re-enkripsi database supaya crash di tengah proses
  /// tidak mengunci data: password lama masih tercatat di `previous`.
  Future<void> stagePasswordChange(VaultKeyChange change) =>
      _store.write(change.record);

  /// Memasang kunci baru di sesi lalu menghapus cadangan kunci lama.
  ///
  /// Record sementara sudah memakai kunci baru, jadi kegagalan saat membersihkan
  /// `previous` tidak membuat data tidak terbaca; password lama hanya masih
  /// berlaku sampai pembersihan berhasil.
  Future<void> finalizePasswordChange(VaultKeyChange change) async {
    final old = _key;
    _key = change.key;
    _activeRecord = change.record.withoutPrevious();
    old?.destroy();

    try {
      await _store.write(change.record.withoutPrevious());
    } catch (_) {
      // Abaikan: lihat doc di atas.
    }
  }

  /// Mengembalikan record semula dan membuang kunci baru yang batal dipakai.
  Future<void> abortPasswordChange(VaultKeyChange change) async {
    await _store.write(change.original);
    change.key.destroy();
  }

  Future<SecretKeyData?> _tryKey(
    String password,
    VaultKeyRecord record,
  ) async {
    final key = await _deriveKey(password, record.salt, record.iterations);
    try {
      final plain = await AesGcmEncryption(key).decrypt(record.check);
      if (plain == verifierPlaintext) return key;
    } on SecretBoxAuthenticationError {
      // Password salah: jatuh ke pembersihan di bawah.
    }
    key.destroy();
    return null;
  }

  /// Menghapus kunci sesi dari memori.
  void lock() {
    _key?.destroy();
    _key = null;
    _activeRecord = null;
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
