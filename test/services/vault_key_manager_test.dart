import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/services/vault_encryption_service.dart';
import 'package:mylife/services/vault_key_manager.dart';
import 'package:mylife/services/vault_secret_store.dart';

class _MemoryKeyStore implements VaultKeyStore {
  VaultKeyRecord? record;
  int writes = 0;

  @override
  Future<VaultKeyRecord?> read() async => record;

  @override
  Future<void> write(VaultKeyRecord record) async {
    this.record = record;
    writes++;
  }

  @override
  Future<void> delete() async => record = null;
}

class _MemorySecretStore implements VaultSecretStore {
  final Map<String, List<int>> values = {};

  @override
  Future<List<int>?> read(String name) async {
    final value = values[name];
    return value == null ? null : List<int>.of(value);
  }

  @override
  Future<bool> contains(String name) async => values.containsKey(name);

  @override
  Future<void> write(String name, List<int> bytes) async {
    values[name] = List<int>.of(bytes);
  }

  @override
  Future<void> delete(String name) async => values.remove(name);
}

VaultKeyManager _manager(
  _MemoryKeyStore store, [
  _MemorySecretStore? secrets,
]) =>
    VaultKeyManager(
      store: store,
      secretStore: secrets ?? _MemorySecretStore(),
      iterations: 1000,
    );

void main() {
  group('VaultKeyManager.createPassword', () {
    test('menyimpan salt, iterasi, dan verifier terenkripsi', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);

      await manager.createPassword('rahasia-utama');

      final record = store.record!;
      expect(record.salt.length, VaultKeyManager.saltLength);
      expect(record.iterations, 1000);
      expect(record.check, startsWith(vaultEncryptionPrefix));
      expect(record.check, isNot(contains(VaultKeyManager.verifierPlaintext)));
      expect(await manager.hasPassword(), isTrue);
      expect(manager.isUnlocked, isTrue);
    });

    test('kunci sesi 256 bit', () async {
      final manager = _manager(_MemoryKeyStore());

      await manager.createPassword('rahasia-utama');

      final bytes = await manager.requireKey.extractBytes();
      expect(bytes.length, VaultKeyManager.keyLength);
    });

    test('password kosong dan password ganda ditolak', () async {
      final manager = _manager(_MemoryKeyStore());

      await expectLater(manager.createPassword(''), throwsArgumentError);
      await manager.createPassword('pertama');
      await expectLater(
        manager.createPassword('kedua'),
        throwsA(isA<StateError>()),
      );
    });

    test('salt berbeda antar vault', () async {
      final first = _MemoryKeyStore();
      final second = _MemoryKeyStore();

      await _manager(first).createPassword('sama');
      await _manager(second).createPassword('sama');

      expect(first.record!.salt, isNot(second.record!.salt));
    });
  });

  group('VaultKeyManager.unlock', () {
    test('password benar membuka kunci yang sama', () async {
      final store = _MemoryKeyStore();
      final creator = _manager(store);
      await creator.createPassword('rahasia-utama');
      final original = await creator.requireKey.extractBytes();
      creator.lock();

      final manager = _manager(store);
      expect(manager.isUnlocked, isFalse);
      expect(await manager.unlock('rahasia-utama'), isTrue);
      expect(await manager.requireKey.extractBytes(), original);
    });

    test('password salah tidak membuka kunci', () async {
      final store = _MemoryKeyStore();
      await _manager(store).createPassword('benar');

      final manager = _manager(store);
      expect(await manager.unlock('salah'), isFalse);
      expect(manager.isUnlocked, isFalse);
      expect(() => manager.requireKey, throwsA(isA<StateError>()));
    });

    test('tanpa record kunci, unlock gagal jelas', () async {
      final manager = _manager(_MemoryKeyStore());

      await expectLater(manager.unlock('apa saja'), throwsA(isA<StateError>()));
    });

    test('lock menghapus kunci dari memori', () async {
      final manager = _manager(_MemoryKeyStore());
      await manager.createPassword('rahasia-utama');

      manager.lock();

      expect(manager.isUnlocked, isFalse);
      expect(() => manager.requireKey, throwsA(isA<StateError>()));
    });
  });

  group('VaultKeyManager.changePassword', () {
    test('finalisasi memakai salt baru dan membuang kunci lama', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);
      await manager.createPassword('password-lama');
      final oldSalt = store.record!.salt;
      final oldKey = await manager.requireKey.extractBytes();

      final change = await manager.preparePasswordChange('password-baru');
      await manager.stagePasswordChange(change);
      await manager.finalizePasswordChange(change);

      expect(store.record!.salt, isNot(equals(oldSalt)));
      expect(store.record!.previous, isNull);
      expect(await manager.requireKey.extractBytes(), isNot(equals(oldKey)));

      manager.lock();
      expect(await manager.unlock('password-lama'), isFalse);
      expect(await manager.unlock('password-baru'), isTrue);
    });

    test('sebelum finalisasi password lama masih membuka data lama', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);
      await manager.createPassword('password-lama');

      final change = await manager.preparePasswordChange('password-baru');
      await manager.stagePasswordChange(change);
      manager.lock();

      final reopened = _manager(store);
      expect(await reopened.unlock('password-lama'), isTrue);
      expect(await reopened.unlock('password-baru'), isTrue);
    });

    test('abort mengembalikan record semula', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);
      await manager.createPassword('password-lama');
      final original = store.record!;

      final change = await manager.preparePasswordChange('password-baru');
      await manager.stagePasswordChange(change);
      await manager.abortPasswordChange(change);

      expect(store.record!.salt, equals(original.salt));
      expect(store.record!.check, original.check);
      expect(store.record!.previous, isNull);
      expect(await manager.verifyPassword('password-lama'), isTrue);
    });

    test('tanpa password tersimpan, persiapan gagal', () async {
      final manager = _manager(_MemoryKeyStore());

      await expectLater(
        manager.preparePasswordChange('password-baru'),
        throwsA(isA<StateError>()),
      );
    });

    test('verifyPassword tidak mengubah kunci sesi', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);
      await manager.createPassword('password-lama');
      final keyBefore = await manager.requireKey.extractBytes();

      expect(await manager.verifyPassword('salah'), isFalse);
      expect(await manager.verifyPassword('password-lama'), isTrue);
      expect(await manager.requireKey.extractBytes(), equals(keyBefore));
    });
  });

  group('VaultKeyManager 4C-A kunci perangkat', () {
    test('record v2 membungkus kunci acak dan password tetap membuka',
        () async {
      final store = _MemoryKeyStore();
      final secrets = _MemorySecretStore();
      final manager = _manager(store, secrets);
      await manager.createPassword('password-lama');

      final change = await manager.prepareDeviceKey('password-lama');
      expect(change, isNotNull);
      expect(change!.record.isWrapped, isTrue);
      expect(change.record.wrappedKey, startsWith(vaultEncryptionPrefix));
      expect(await change.key.extractBytes(), hasLength(VaultKeyManager.keyLength));
      final dataKey = await change.key.extractBytes();

      await manager.stageDeviceKey(change);
      manager.commitDeviceKey(change);

      expect(store.record!.isWrapped, isTrue);
      expect(await manager.hasDeviceKey(), isTrue);
      final storedDevice = await manager.readDeviceKey();
      expect(await storedDevice!.extractBytes(), dataKey);
      storedDevice.destroy();

      manager.lock();
      final reopened = _manager(store, secrets);
      expect(await reopened.hasWrappedRecord(), isTrue);
      expect(await reopened.unlock('password-lama'), isTrue);
      expect(await reopened.requireKey.extractBytes(), dataKey);
    });

    test('prepareDeviceKey dengan password salah mengembalikan null', () async {
      final store = _MemoryKeyStore();
      final manager = _manager(store);
      await manager.createPassword('benar');

      expect(await manager.prepareDeviceKey('salah'), isNull);
      expect(store.record!.isWrapped, isFalse);
      expect(await manager.hasDeviceKey(), isFalse);
    });

    test('rewrapPassword mengganti password tanpa mengganti kunci data',
        () async {
      final store = _MemoryKeyStore();
      final secrets = _MemorySecretStore();
      final manager = _manager(store, secrets);
      await manager.createPassword('lama');

      final change = await manager.prepareDeviceKey('lama');
      await manager.stageDeviceKey(change!);
      manager.commitDeviceKey(change);
      final dataKey = await change.key.extractBytes();

      await manager.rewrapPassword(
        currentPassword: 'lama',
        newPassword: 'baru',
      );
      manager.lock();

      expect(await _manager(store, secrets).unlock('lama'), isFalse);
      final reopened = _manager(store, secrets);
      expect(await reopened.unlock('baru'), isTrue);
      expect(await reopened.requireKey.extractBytes(), dataKey);
    });

    test('abortDeviceKey memulihkan record v1 dan menghapus kunci', () async {
      final store = _MemoryKeyStore();
      final secrets = _MemorySecretStore();
      final manager = _manager(store, secrets);
      await manager.createPassword('lama');

      final change = await manager.prepareDeviceKey('lama');
      await manager.stageDeviceKey(change!);
      expect(store.record!.isWrapped, isTrue);

      await manager.abortDeviceKey(change);

      expect(store.record!.isWrapped, isFalse);
      expect(await manager.hasDeviceKey(), isFalse);
      expect(await manager.verifyPassword('lama'), isTrue);
    });

    test('restoreDeviceKey menulis ulang kunci tanpa ubah record', () async {
      final store = _MemoryKeyStore();
      final secrets = _MemorySecretStore();
      final manager = _manager(store, secrets);
      await manager.createPassword('lama');

      final change = await manager.prepareDeviceKey('lama');
      await manager.stageDeviceKey(change!);
      manager.commitDeviceKey(change);
      final dataKey = await change.key.extractBytes();
      final record = store.record!;

      await manager.deleteDeviceKey();
      expect(await manager.hasDeviceKey(), isFalse);
      expect(await manager.restoreDeviceKey('salah'), isFalse);
      expect(await manager.hasDeviceKey(), isFalse);

      expect(await manager.restoreDeviceKey('lama'), isTrue);
      expect(store.record, same(record));
      final restored = await manager.readDeviceKey();
      expect(await restored!.extractBytes(), dataKey);
      restored.destroy();
    });

    test('record v2 bolak-balik JSON', () {
      const record = VaultKeyRecord(
        salt: <int>[1, 2, 3],
        iterations: 1000,
        check: 'enc:v1:abc',
        wrappedKey: 'enc:v1:def',
      );

      final decoded = VaultKeyRecord.fromJson(record.toJson());

      expect(decoded.isWrapped, isTrue);
      expect(decoded.wrappedKey, 'enc:v1:def');
      expect(decoded.salt, record.salt);
      expect(decoded.iterations, 1000);
    });

    test('previous lama tanpa version/kdf tetap terbaca', () {
      final decoded = VaultKeyRecord.fromJson(<String, Object?>{
        'version': 1,
        'kdf': 'pbkdf2-hmac-sha256',
        'iterations': 1000,
        'salt': base64Encode(<int>[1, 2, 3]),
        'check': 'enc:v1:abc',
        'previous': <String, Object?>{
          'iterations': 2000,
          'salt': base64Encode(<int>[4, 5, 6]),
          'check': 'enc:v1:old',
        },
      });

      expect(decoded.previous!.iterations, 2000);
      expect(decoded.previous!.check, 'enc:v1:old');
    });
  });
}
