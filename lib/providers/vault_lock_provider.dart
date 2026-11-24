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
  }) : _keyManager = keyManager ?? VaultKeyManager(),
       _database = database ?? DatabaseService.instance {
    _idle = IdleLockWatcher(timeout: idleTimeout, onIdle: lock);
  }

  static const Duration defaultIdleTimeout = Duration(minutes: 5);

  final VaultKeyManager _keyManager;
  final DatabaseService _database;
  final Duration idleTimeout;

  IdleLockWatcher? _idle;

  bool _hasPassword = false;
  bool _hasQuickUnlock = false;
  bool _unlocked = false;
  bool _busy = false;
  bool _rotating = false;
  String? _error;
  int _migratedRows = 0;

  bool get hasPassword => _hasPassword;

  /// `true` bila ada kunci perangkat di Keystore (buka cepat aktif).
  bool get hasQuickUnlock => _hasQuickUnlock;
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
      _hasQuickUnlock = await _keyManager.hasDeviceKey();
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
      final candidates = await _keyManager.candidatesWithPassword(password);
      if (candidates.isEmpty) {
        _error = 'Password salah';
        return false;
      }
      _hasPassword = true;
      if (await _activateFirst(candidates)) return true;
      _error =
          'Password benar, tetapi data vault memakai kunci lain. '
          'Coba buka cepat.';
      return false;
    } catch (e) {
      _error = 'Gagal membuka vault: $e';
      return false;
    } finally {
      _finish();
    }
  }

  /// Membuka vault dengan kunci 32 byte dari Keystore (buka cepat, 4C-A).
  ///
  /// Kunci tetap diverifikasi ke data: bila migrasi 4C terputus, kunci perangkat
  /// bisa jadi belum cocok dan password harus dipakai.
  Future<bool> unlockWithDeviceKey() async {
    if (_busy) return false;
    _start();

    try {
      final key = await _keyManager.readDeviceKey();
      if (key == null) {
        _error = 'Buka cepat belum aktif';
        return false;
      }
      final record = await _keyManager.currentRecord();
      if (record == null) {
        key.destroy();
        _error = 'Vault belum punya password';
        return false;
      }
      _hasPassword = true;
      final ok = await _tryActivate(
        VaultKeyCandidate(key: key, record: record),
        requireCheck: true,
      );
      if (ok) return true;
      key.destroy();
      _error = 'Buka cepat gagal, masukkan password.';
      return false;
    } catch (e) {
      _error = 'Buka cepat gagal: $e';
      return false;
    } finally {
      _finish();
    }
  }

  /// Ganti password vault: verifikasi password lama, turunkan kunci baru
  /// (PBKDF2 + salt baru), enkripsi ulang semua item, lalu finalisasi record.
  ///
  /// Urutan sengaja: record sementara (dengan kunci lama sebagai cadangan)
  /// ditulis sebelum re-enkripsi, sehingga proses yang terputus tidak membuat
  /// data hanya bisa dibuka dengan kunci yang tidak tersimpan.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_busy) return false;
    if (!_unlocked) {
      _error = 'Buka vault sebelum mengganti password';
      notifyListeners();
      return false;
    }

    _start();
    _rotating = true;
    // Kunci lama harus tetap hidup sampai transaksi re-enkripsi selesai.
    _idle?.stop();
    VaultKeyChange? change;
    var finalized = false;

    try {
      if (!await _keyManager.verifyPassword(currentPassword)) {
        _error = 'Password lama salah';
        return false;
      }

      // Record v2 (4C-A): kunci data tidak berubah, cukup bungkus ulang dengan
      // kunci turunan password baru. Tidak perlu re-enkripsi database.
      if (await _keyManager.hasWrappedRecord()) {
        await _keyManager.rewrapPassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        return true;
      }

      change = await _keyManager.preparePasswordChange(newPassword);
      await _keyManager.stagePasswordChange(change);

      final to = AesGcmEncryption(change.key);
      await _database.reencryptVaultItems(
        from: AesGcmEncryption(_keyManager.requireKey),
        to: to,
      );

      await _keyManager.finalizePasswordChange(change);
      finalized = true;
      _database.vaultEncryption = to;
      return true;
    } catch (e) {
      if (change != null && !finalized) {
        try {
          await _keyManager.abortPasswordChange(change);
        } catch (_) {
          // Transaksi database sudah di-rollback; data lama tetap terbaca
          // dengan password lama meski pembersihan record gagal.
        }
      }
      _error = 'Gagal mengganti password: $e';
      return false;
    } finally {
      _rotating = false;
      if (_unlocked) _idle?.start();
      _finish();
    }
  }

  /// Mengaktifkan buka cepat: kunci data acak 32 byte disimpan di Keystore dan
  /// semua item dienkripsi ulang ke kunci itu. Password tetap jadi cadangan
  /// karena kunci acak juga dibungkus kunci turunan password.
  Future<bool> enableQuickUnlock(String password) async {
    if (_busy) return false;
    if (!_unlocked) {
      _error = 'Buka vault sebelum mengaktifkan buka cepat';
      notifyListeners();
      return false;
    }

    _start();
    _rotating = true;
    _idle?.stop();
    VaultDeviceKeyChange? change;
    var committed = false;

    try {
      // Sudah pernah migrasi 4C: kunci data masih ada di record v2, jadi cukup
      // kembalikan ke Keystore. Tidak perlu re-enkripsi.
      if (await _keyManager.hasWrappedRecord()) {
        if (!await _keyManager.restoreDeviceKey(password)) {
          _error = 'Password salah';
          return false;
        }
        _hasQuickUnlock = true;
        return true;
      }

      change = await _keyManager.prepareDeviceKey(password);
      if (change == null) {
        _error = 'Password salah';
        return false;
      }

      // Record v2 + kunci perangkat ditulis sebelum transaksi, jadi crash di
      // tengah re-enkripsi masih bisa dipulihkan dengan password.
      await _keyManager.stageDeviceKey(change);

      final to = AesGcmEncryption(change.key);
      await _database.reencryptVaultItems(
        from: AesGcmEncryption(_keyManager.requireKey),
        to: to,
      );

      _keyManager.commitDeviceKey(change);
      committed = true;
      _database.vaultEncryption = to;
      _hasQuickUnlock = true;
      return true;
    } catch (e) {
      if (change != null && !committed) {
        try {
          await _keyManager.abortDeviceKey(change);
        } catch (_) {
          // Data sudah di-rollback ke kunci lama; password tetap membuka.
        }
      }
      _hasQuickUnlock = await _keyManager.hasDeviceKey();
      _error = 'Gagal mengaktifkan buka cepat: $e';
      return false;
    } finally {
      _rotating = false;
      if (_unlocked) _idle?.start();
      _finish();
    }
  }

  /// Mematikan buka cepat: entri Keystore dihapus. Data tetap memakai kunci
  /// acak dan tetap bisa dibuka dengan password (record v2), jadi tidak perlu
  /// re-enkripsi.
  Future<bool> disableQuickUnlock() async {
    if (_busy) return false;
    if (!_unlocked) {
      _error = 'Buka vault sebelum mengubah buka cepat';
      notifyListeners();
      return false;
    }

    _start();
    try {
      await _keyManager.deleteDeviceKey();
      _hasQuickUnlock = false;
      return true;
    } catch (e) {
      _error = 'Gagal menonaktifkan buka cepat: $e';
      return false;
    } finally {
      _finish();
    }
  }

  /// Menutup vault: kunci dihapus dari memori, database menolak operasi.
  void lock() {
    // Rotasi password butuh kunci lama tetap hidup sampai transaksi selesai.
    if (_rotating) return;

    _idle?.stop();
    _keyManager.lock();
    _database.vaultEncryption = const LockedEncryption();
    _unlocked = false;
    _migratedRows = 0;
    notifyListeners();
  }

  /// Mencoba kandidat berurutan; kandidat yang gagal dihapus oleh [_tryActivate].
  Future<bool> _activateFirst(List<VaultKeyCandidate> candidates) async {
    VaultKeyCandidate? kept;

    for (var i = 0; i < candidates.length; i++) {
      if (!await _tryActivate(candidates[i])) continue;

      kept = candidates[i];
      // Migrasi 4C terputus: baris masih memakai kunci fallback. Pindahkan ke
      // kunci data di record supaya item baru tidak memakai kunci campur.
      if (i > 0 && candidates[i].record.isWrapped) {
        final target = candidates.first;
        try {
          await _finishInterruptedMigration(
            from: candidates[i],
            target: target,
          );
          kept = target;
        } catch (_) {
          // Re-enkripsi di-rollback; vault tetap terbuka dengan fallback.
          kept = candidates[i];
        }
      }
      break;
    }

    if (kept == null) {
      for (final candidate in candidates) {
        candidate.key.destroy();
      }
      return false;
    }

    for (final candidate in candidates) {
      if (!identical(candidate, kept)) {
        candidate.key.destroy();
      }
    }
    return true;
  }

  Future<void> _finishInterruptedMigration({
    required VaultKeyCandidate from,
    required VaultKeyCandidate target,
  }) async {
    final to = AesGcmEncryption(target.key);
    await _database.reencryptVaultItems(
      from: AesGcmEncryption(from.key),
      to: to,
    );
    _database.vaultEncryption = to;
    _keyManager.activate(target.key, target.record);
    try {
      await _keyManager.storeDeviceKey(target.key);
    } catch (_) {
      // Entri Keystore gagal ditulis; password tetap membuka vault.
    }
  }

  /// Memasang cipher lalu memastikan kunci benar-benar membuka data.
  ///
  /// Probe ini membuat migrasi 4C yang terputus tetap aman: record bisa sudah
  /// v2 sementara baris masih memakai kunci turunan password, atau sebaliknya.
  /// [requireCheck] dipakai kunci perangkat: kunci itu tidak pernah dipakai
  /// sebagai fallback migrasi, jadi wajib cocok dengan verifier record.
  Future<bool> _tryActivate(
    VaultKeyCandidate candidate, {
    bool requireCheck = false,
  }) async {
    final cipher = AesGcmEncryption(candidate.key);
    _database.vaultEncryption = cipher;
    try {
      final items = await _database.getVaultItems();
      // Vault kosong tidak membuktikan apa pun; wajib cocok dengan verifier.
      if ((items.isEmpty || requireCheck) &&
          !await _keyManager.matchesCheck(candidate.key, candidate.record)) {
        throw const FormatException('Kunci tidak cocok dengan record vault');
      }
      _migratedRows = await _database.migrateVaultItems();
    } catch (_) {
      _database.vaultEncryption = const LockedEncryption();
      return false;
    }
    _keyManager.activate(candidate.key, candidate.record);
    _unlocked = true;
    _idle?.start();
    return true;
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
