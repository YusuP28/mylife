import 'package:flutter/foundation.dart';

import '../services/database_service.dart';
import '../services/idle_lock_watcher.dart';
import '../services/vault_encryption_service.dart';
import '../services/vault_key_manager.dart';

/// Status buka/kunci Vault dan penghubung ke lapisan database.
///
/// Alur: `refreshStatus` saat start → `createPassword`/`unlock` → cipher
/// `AesGcmEncryption` dipasang ke `DatabaseService` → migrasi baris lama →
/// `lock` saat app ke background atau idle.
///
/// Timer idle hidup di sini supaya `MaterialApp.builder` bisa mengirim
/// aktivitas dari rute mana pun, termasuk editor yang dibuka di atas
/// `HomeShell`.
class VaultLockProvider extends ChangeNotifier {
  VaultLockProvider({
    VaultKeyManager? keyManager,
    DatabaseService? database,
    this.idleTimeout = defaultIdleTimeout,
  })  : _keyManager = keyManager ?? VaultKeyManager(),
        _database = database ?? DatabaseService.instance {
    _idle = IdleLockWatcher(timeout: idleTimeout, onIdle: lock);
  }

  static const Duration defaultIdleTimeout = Duration(minutes: 5);

  final VaultKeyManager _keyManager;
  final DatabaseService _database;
  final Duration idleTimeout;

  IdleLockWatcher? _idle;

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

  /// Dipanggil dari `MaterialApp.builder` pada setiap pointer event.
  void noteActivity() => _idle?.noteActivity();

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
    _idle?.stop();
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
    _idle?.start();
  }

  @override
  void dispose() {
    _idle?.dispose();
    _idle = null;
    super.dispose();
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
