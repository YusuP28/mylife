import 'package:flutter/foundation.dart';

import '../services/database_service.dart';
import '../services/vault_encryption_service.dart';
import '../services/vault_key_manager.dart';

/// Status buka/kunci Vault dan penghubung ke lapisan database.
///
/// Alur: `refreshStatus` saat start → `createPassword`/`unlock` → cipher
/// `AesGcmEncryption` dipasang ke `DatabaseService` → migrasi baris lama →
/// `lock` saat app ke background.
class VaultLockProvider extends ChangeNotifier {
  VaultLockProvider({VaultKeyManager? keyManager, DatabaseService? database})
      : _keyManager = keyManager ?? VaultKeyManager(),
        _database = database ?? DatabaseService.instance;

  final VaultKeyManager _keyManager;
  final DatabaseService _database;

  bool _hasPassword = false;
  bool _unlocked = false;
  bool _busy = false;
  String? _error;
  int _migratedRows = 0;

  bool get hasPassword => _hasPassword;
  bool get isUnlocked => _unlocked;
  bool get busy => _busy;
  String? get error => _error;

  /// Jumlah baris lama yang dienkripsi pada unlock terakhir.
  int get migratedRows => _migratedRows;

  Future<void> refreshStatus() async {
    try {
      _hasPassword = await _keyManager.hasPassword();
    } catch (e) {
      _error = 'Gagal membaca kunci vault: $e';
    }
    notifyListeners();
  }

  Future<bool> createPassword(String password) async {
    if (_busy) return false;
    _start();

    try {
      await _keyManager.createPassword(password);
      // Password tersimpan sebelum migrasi: kalau migrasi gagal, pengguna
      // harus membuka (bukan membuat ulang) agar salt tidak tertimpa.
      _hasPassword = true;
      await _activateCipher();
      return true;
    } catch (e) {
      _error = 'Gagal membuat password: $e';
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> unlock(String password) async {
    if (_busy) return false;
    _start();

    try {
      if (!await _keyManager.unlock(password)) {
        _error = 'Password salah';
        return false;
      }
      _hasPassword = true;
      await _activateCipher();
      return true;
    } catch (e) {
      _error = 'Gagal membuka vault: $e';
      return false;
    } finally {
      _finish();
    }
  }

  /// Menutup vault: kunci dihapus dari memori, database menolak operasi.
  void lock() {
    _keyManager.lock();
    _database.vaultEncryption = const LockedEncryption();
    _unlocked = false;
    _migratedRows = 0;
    notifyListeners();
  }

  Future<void> _activateCipher() async {
    _database.vaultEncryption = AesGcmEncryption(_keyManager.requireKey);
    try {
      _migratedRows = await _database.migrateVaultItems();
    } catch (_) {
      // Migrasi gagal = transaksi di-rollback. Jangan biarkan vault setengah
      // terbuka dengan kunci yang tidak bisa dipakai.
      _database.vaultEncryption = const LockedEncryption();
      _keyManager.lock();
      rethrow;
    }
    _unlocked = true;
  }

  void _start() {
    _busy = true;
    _error = null;
    notifyListeners();
  }

  void _finish() {
    _busy = false;
    notifyListeners();
  }
}
