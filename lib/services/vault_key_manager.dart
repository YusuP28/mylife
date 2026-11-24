import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import 'vault_encryption_service.dart';
import 'vault_secret_store.dart';

/// Parameter turunan kunci yang disimpan di sidecar file.
///
/// Sengaja tidak menyimpan kunci maupun password. Yang disimpan hanya salt,
/// jumlah iterasi, dan ciphertext verifier untuk mendeteksi password salah.
class VaultKeyRecord {
  const VaultKeyRecord({
    required this.salt,
    required this.iterations,
    required this.check,
    this.wrappedKey,
    this.previous,
  });

  /// Record lama: kunci data = kunci turunan password.
  static const int version = 1;

  /// Record 4C-A: kunci data acak, dibungkus kunci turunan password.
  static const int wrappedVersion = 2;

  static const String kdfName = 'pbkdf2-hmac-sha256';
  static const String wrappedKdfName = 'pbkdf2-hmac-sha256+aes-256-gcm-wrap';

  final List<int> salt;
  final int iterations;

  /// `enc:v1:...` dari plaintext verifier, dibuat dengan kunci data.
  final String check;

  /// `enc:v1:...` dari base64 kunci data 32 byte, dibuat dengan kunci turunan
  /// password (KEK). Non-null berarti kunci data acak (4C-A).
  final String? wrappedKey;

  /// Parameter kunci lama yang masih boleh dipakai membuka data.
  ///
  /// Hanya terisi selama ganti password belum final: bila proses terputus
  /// setelah record baru ditulis tetapi sebelum semua baris dienkripsi ulang,
  /// password lama tetap bisa membuka data lama.
  final VaultKeyRecord? previous;

  bool get isWrapped => wrappedKey != null;

  VaultKeyRecord withoutPrevious() => VaultKeyRecord(
        salt: salt,
        iterations: iterations,
        check: check,
        wrappedKey: wrappedKey,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'version': isWrapped ? wrappedVersion : version,
        'kdf': isWrapped ? wrappedKdfName : kdfName,
        'iterations': iterations,
        'salt': base64Encode(salt),
        'check': check,
        if (wrappedKey != null) 'wrappedKey': wrappedKey,
        if (previous != null) 'previous': previous!.toJson(),
      };

  factory VaultKeyRecord.fromJson(Map<String, Object?> json) {
    final storedVersion = json['version'];
    final kdf = json['kdf'];
    final wrappedKey = json['wrappedKey'];

    if (storedVersion == version) {
      if (kdf != kdfName) {
        throw FormatException('KDF kunci vault tidak dikenal: $kdf');
      }
    } else if (storedVersion == wrappedVersion) {
      if (kdf != wrappedKdfName) {
        throw FormatException('KDF kunci vault tidak dikenal: $kdf');
      }
      if (wrappedKey is! String) {
        throw const FormatException('Kunci bungkus vault tidak ada');
      }
    } else {
      throw FormatException('Versi kunci vault tidak dikenal: $storedVersion');
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
      final map = Map<String, Object?>.from(previousJson);
      // Sidecar lama menyimpan `previous` tanpa version/kdf.
      map.putIfAbsent('version', () => VaultKeyRecord.version);
      map.putIfAbsent('kdf', () => VaultKeyRecord.kdfName);
      previous = VaultKeyRecord.fromJson(map);
    }

    return VaultKeyRecord(
      salt: base64Decode(salt),
      iterations: iterations,
      check: check,
      wrappedKey: wrappedKey is String ? wrappedKey : null,
      previous: previous,
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

/// Kunci yang cocok dengan record, belum tentu cocok dengan isi database.
///
/// Dipakai saat unlock: provider mencoba tiap kandidat ke data sampai ada yang
/// berhasil, sehingga migrasi 4C yang terputus tetap bisa dibuka.
class VaultKeyCandidate {
  const VaultKeyCandidate({required this.key, required this.record});

  final SecretKeyData key;

  /// Record asal kunci ini. `previous` bila kunci lama.
  final VaultKeyRecord record;
}

/// Perubahan kunci data ke kunci acak (4C-A) yang belum dipasang.
class VaultDeviceKeyChange {
  const VaultDeviceKeyChange({
    required this.key,
    required this.record,
    required this.original,
  });

  /// Kunci data acak 32 byte.
  final SecretKeyData key;

  /// Record v2: `wrappedKey` berisi [key] yang dibungkus kunci turunan password.
  final VaultKeyRecord record;

  /// Record sebelum perubahan, untuk rollback.
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
    VaultSecretStore? secretStore,
    this.iterations = defaultIterations,
  })  : _store = store ?? FileVaultKeyStore(),
        _secretStore = secretStore ?? SecureVaultSecretStore();

  /// OWASP menyarankan >= 210.000 iterasi untuk PBKDF2-HMAC-SHA256.
  /// Naikkan bila perangkat masih nyaman; turunkan hanya untuk test.
  static const int defaultIterations = 210000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  /// Plaintext tetap untuk memverifikasi password saat unlock.
  static const String verifierPlaintext = 'mylife-vault-key-check';

  final VaultKeyStore _store;
  final VaultSecretStore _secretStore;
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
  /// Hanya memakai kandidat pertama yang cocok dengan record. Provider memakai
  /// [candidatesWithPassword] + probe data supaya migrasi 4C yang terputus tetap
  /// bisa dibuka.
  Future<bool> unlock(String password) async {
    final candidates = await candidatesWithPassword(password);
    if (candidates.isEmpty) return false;

    final chosen = candidates.first;
    for (final other in candidates.skip(1)) {
      other.key.destroy();
    }

    lock();
    _key = chosen.key;
    _activeRecord = chosen.record;
    return true;
  }

  /// Kandidat kunci untuk password ini, urut prioritas.
  ///
  /// - Record v2: kunci data hasil unwrap, lalu kunci turunan password sebagai
  ///   fallback bila migrasi 4C terputus sebelum database ditulis ulang.
  /// - Record v1: kunci turunan password, lalu `previous` bila ada.
  ///
  /// Kosong berarti password salah.
  Future<List<VaultKeyCandidate>> candidatesWithPassword(
    String password,
  ) async {
    _validatePassword(password);
    final record = await _store.read();
    if (record == null) {
      throw StateError('Vault belum punya password');
    }

    final kek = await _deriveKey(password, record.salt, record.iterations);
    final candidates = <VaultKeyCandidate>[];

    final wrapped = record.wrappedKey;
    if (wrapped != null) {
      final dataKey = await _tryUnwrap(wrapped, kek);
      if (dataKey != null) {
        candidates.add(VaultKeyCandidate(key: dataKey, record: record));
        // Fallback migrasi: baris mungkin masih memakai kunci turunan password.
        candidates.add(VaultKeyCandidate(key: kek, record: record));
      } else {
        kek.destroy();
      }
    } else if (await _matches(kek, record.check)) {
      candidates.add(VaultKeyCandidate(key: kek, record: record));
    } else {
      kek.destroy();
    }

    final previous = record.previous;
    if (previous != null) {
      final old = await _deriveKey(password, previous.salt, previous.iterations);
      if (await _matches(old, previous.check)) {
        candidates.add(VaultKeyCandidate(key: old, record: previous));
      } else {
        old.destroy();
      }
    }

    return candidates;
  }

  /// `true` bila password cocok dengan kunci aktif atau kunci lama yang masih
  /// menunggu rotasi selesai. Tidak mengubah kunci sesi.
  Future<bool> verifyPassword(String password) async {
    final candidates = await candidatesWithPassword(password);
    if (candidates.isEmpty) return false;
    for (final candidate in candidates) {
      candidate.key.destroy();
    }
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

  /// Record yang sedang tersimpan di sidecar.
  Future<VaultKeyRecord?> currentRecord() => _store.read();

  /// `true` bila vault memakai kunci data acak (record v2).
  Future<bool> hasWrappedRecord() async {
    final record = await _store.read();
    return record?.isWrapped ?? false;
  }

  /// Memasang kunci yang sudah lolos probe data dari provider.
  void activate(SecretKeyData key, VaultKeyRecord record) {
    if (!identical(_key, key)) _key?.destroy();
    _key = key;
    _activeRecord = record;
  }

  /// Verifikasi kunci terhadap verifier di record (bukan terhadap data).
  Future<bool> matchesCheck(SecretKey key, VaultKeyRecord record) =>
      _matches(key, record.check);

  Future<bool> hasDeviceKey() async {
    try {
      return await _secretStore.contains(vaultDeviceKeyName);
    } catch (_) {
      return false;
    }
  }

  Future<SecretKeyData?> readDeviceKey() async {
    final bytes = await _secretStore.read(vaultDeviceKeyName);
    if (bytes == null) return null;
    if (bytes.length != keyLength) {
      throw const FormatException('Panjang kunci perangkat tidak valid');
    }
    return SecretKeyData(bytes);
  }

  /// Menulis kunci yang sudah ada ke Keystore.
  Future<void> storeDeviceKey(SecretKeyData key) async {
    await _secretStore.write(
      vaultDeviceKeyName,
      await key.extractBytes(),
    );
  }

  /// Mengembalikan kunci data dari record v2 ke Keystore setelah buka cepat
  /// dimatikan. Tidak mengubah record maupun database.
  ///
  /// `false` bila password salah. Record v1 (belum pernah migrasi) juga `false`.
  Future<bool> restoreDeviceKey(String password) async {
    _validatePassword(password);
    final record = await _store.read();
    if (record == null) {
      throw StateError('Vault belum punya password');
    }
    final wrapped = record.wrappedKey;
    if (wrapped == null) return false;

    final kek = await _deriveKey(password, record.salt, record.iterations);
    final dataKey = await _tryUnwrap(wrapped, kek);
    kek.destroy();
    if (dataKey == null) return false;

    try {
      await storeDeviceKey(dataKey);
    } finally {
      dataKey.destroy();
    }
    return true;
  }

  /// Menyiapkan kunci data acak + record v2. `null` bila password salah.
  ///
  /// Kunci data dibungkus kunci turunan password, jadi password tetap bisa
  /// membuka vault walau entri Keystore hilang.
  Future<VaultDeviceKeyChange?> prepareDeviceKey(String password) async {
    _validatePassword(password);
    final current = await _store.read();
    if (current == null) {
      throw StateError('Vault belum punya password');
    }

    final kek = await _deriveKey(password, current.salt, current.iterations);
    final wrapped = current.wrappedKey;
    var valid = false;
    if (wrapped != null) {
      final existing = await _tryUnwrap(wrapped, kek);
      if (existing != null) {
        existing.destroy();
        valid = true;
      }
    } else {
      valid = await _matches(kek, current.check);
    }
    if (!valid) {
      kek.destroy();
      return null;
    }

    final dataKey = SecretKeyData(_randomBytes(keyLength));
    final check = await AesGcmEncryption(dataKey).encrypt(verifierPlaintext);
    final wrappedKey = await AesGcmEncryption(kek).encrypt(
      base64Encode(await dataKey.extractBytes()),
    );
    kek.destroy();

    return VaultDeviceKeyChange(
      key: dataKey,
      record: VaultKeyRecord(
        salt: current.salt,
        iterations: current.iterations,
        check: check,
        wrappedKey: wrappedKey,
      ),
      original: current,
    );
  }

  /// Menulis record v2 dan kunci perangkat sebelum database dienkripsi ulang.
  Future<void> stageDeviceKey(VaultDeviceKeyChange change) async {
    await _store.write(change.record);
    await _secretStore.write(
      vaultDeviceKeyName,
      await change.key.extractBytes(),
    );
  }

  /// Memasang kunci data baru di sesi.
  ///
  /// Record sudah ditulis saat stage, jadi tidak ada tulis sidecar lagi setelah
  /// transaksi database commit.
  void commitDeviceKey(VaultDeviceKeyChange change) {
    final old = _key;
    _key = change.key;
    _activeRecord = change.record;
    old?.destroy();
  }

  /// Membatalkan migrasi 4C: record asal dipulihkan, kunci perangkat dihapus.
  Future<void> abortDeviceKey(VaultDeviceKeyChange change) async {
    await _secretStore.delete(vaultDeviceKeyName);
    await _store.write(change.original);
    change.key.destroy();
  }

  /// Menghapus kunci perangkat. Record v2 tetap, jadi password masih membuka.
  Future<void> deleteDeviceKey() => _secretStore.delete(vaultDeviceKeyName);

  /// Ganti password pada record v2: kunci data tetap, hanya bungkusnya yang
  /// diturunkan ulang. Tidak ada re-enkripsi database.
  Future<void> rewrapPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _validatePassword(currentPassword);
    _validatePassword(newPassword);

    final record = await _store.read();
    if (record == null) {
      throw StateError('Vault belum punya password');
    }
    final wrapped = record.wrappedKey;
    if (wrapped == null) {
      throw StateError('Vault tidak memakai kunci data acak');
    }

    final oldKek = await _deriveKey(
      currentPassword,
      record.salt,
      record.iterations,
    );
    final dataKey = await _unwrap(wrapped, oldKek);
    oldKek.destroy();

    final salt = _randomBytes(saltLength);
    final newKek = await _deriveKey(newPassword, salt, iterations);
    final wrappedKey = await AesGcmEncryption(newKek).encrypt(
      base64Encode(await dataKey.extractBytes()),
    );
    newKek.destroy();
    dataKey.destroy();

    final next = VaultKeyRecord(
      salt: salt,
      iterations: iterations,
      check: record.check,
      wrappedKey: wrappedKey,
    );
    await _store.write(next);
    _activeRecord = next;
  }

  Future<SecretKeyData> _unwrap(String storedValue, SecretKey kek) async {
    final plain = await AesGcmEncryption(kek).decrypt(storedValue);
    final bytes = base64Decode(plain);
    if (bytes.length != keyLength) {
      throw const FormatException('Panjang kunci data vault tidak valid');
    }
    return SecretKeyData(bytes);
  }

  Future<SecretKeyData?> _tryUnwrap(String storedValue, SecretKey kek) async {
    try {
      return await _unwrap(storedValue, kek);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  Future<bool> _matches(SecretKey key, String check) async {
    try {
      return await AesGcmEncryption(key).decrypt(check) == verifierPlaintext;
    } on SecretBoxAuthenticationError {
      return false;
    }
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
