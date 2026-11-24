import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/services/vault_encryption_service.dart';
import 'package:mylife/services/vault_key_manager.dart';

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

VaultKeyManager _manager(_MemoryKeyStore store) =>
    VaultKeyManager(store: store, iterations: 1000);

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
}
