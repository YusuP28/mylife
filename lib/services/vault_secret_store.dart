import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nama entri kunci perangkat di secure storage.
const String vaultDeviceKeyName = 'mylife.vault.device_key';

/// Penyimpanan kunci perangkat (Android Keystore lewat flutter_secure_storage).
///
/// Interface dipisah supaya test tidak perlu plugin platform.
abstract class VaultSecretStore {
  Future<List<int>?> read(String name);

  /// Cek keberadaan tanpa mendekripsi; aman dipanggil saat startup.
  Future<bool> contains(String name);

  Future<void> write(String name, List<int> bytes);

  Future<void> delete(String name);
}

/// Implementasi nyata: kunci 32 byte dibungkus Android Keystore oleh plugin.
///
/// Opsi default (bukan `AndroidOptions.biometric`) dipakai supaya aman di
/// minSdk 23: kunci tetap terikat perangkat, tetapi belum ada verifikasi
/// pengguna saat dibaca. Gating biometrik menyusul di 4C-B (`local_auth`).
class SecureVaultSecretStore implements VaultSecretStore {
  SecureVaultSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<List<int>?> read(String name) async {
    final raw = await _storage.read(key: name);
    if (raw == null) return null;
    return base64Decode(raw);
  }

  @override
  Future<bool> contains(String name) => _storage.containsKey(key: name);

  @override
  Future<void> write(String name, List<int> bytes) =>
      _storage.write(key: name, value: base64Encode(bytes));

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
