import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:mylife/services/vault_encryption_service.dart';
import 'package:mylife/services/vault_key_manager.dart';
import 'package:mylife/services/vault_secret_store.dart';

/// Fake [Directory] provider for testing.
class _FakeDirectoryProvider {
  _FakeDirectoryProvider(this.dir);

  final Directory dir;
  Future<Directory> call() async => dir;
}

/// Fake [VaultSecretStore] for testing.
class _FakeSecretStore implements VaultSecretStore {
  _FakeSecretStore();

  final Map<String, List<int>> _store = {};

  @override
  Future<void> write(String name, List<int> bytes) async {
    _store[name] = List<int>.from(bytes);
  }

  @override
  Future<List<int>?> read(String name) async => _store[name];

  @override
  Future<void> delete(String name) async => _store.remove(name);

  @override
  Future<bool> contains(String name) async => _store.containsKey(name);
}

void main() {
  late Directory tempDir;
  late _FakeSecretStore fakeSecretStore;

  setUpAll(() {
    // Register a fake path provider that returns our temp directory.
    PathProviderPlatform.instance = _FakePathProvider();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mylife_test_');
    fakeSecretStore = _FakeSecretStore();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VaultKeyManager', () {
    VaultKeyManager createManager() => VaultKeyManager(
          store: FileVaultKeyStore(
            directoryProvider: _FakeDirectoryProvider(tempDir),
          ),
          secretStore: fakeSecretStore,
          iterations: 1000, // Low iterations for fast tests
        );

    test('createPassword -> hasPassword -> unlock', () async {
      final manager = createManager();

      expect(await manager.hasPassword(), false);

      await manager.createPassword('test-password-123');
      expect(await manager.hasPassword(), true);

      final unlocked = await manager.unlock('test-password-123');
      expect(unlocked, true);
      expect(manager.isUnlocked, true);
      expect(manager.requireKey, isNotNull);
    });

    test('unlock with wrong password returns false', () async {
      final manager = createManager();
      await manager.createPassword('correct-password');

      final unlocked = await manager.unlock('wrong-password');
      expect(unlocked, false);
      expect(manager.isUnlocked, false);
    });

    test('lock clears session key', () async {
      final manager = createManager();
      await manager.createPassword('password');
      await manager.unlock('password');
      expect(manager.isUnlocked, true);

      manager.lock();
      expect(manager.isUnlocked, false);
      expect(() => manager.requireKey, throwsStateError);
    });

    test('changePassword re-encrypts with new key', () async {
      final manager = createManager();
      await manager.createPassword('old-password');
      await manager.unlock('old-password');
      final oldKey = manager.requireKey;

      final change = await manager.preparePasswordChange('new-password');
      await manager.stagePasswordChange(change);
      await manager.finalizePasswordChange(change);

      expect(manager.isUnlocked, true);
      expect(identical(manager.requireKey, oldKey), false);

      // Old password should no longer work
      final manager2 = createManager();
      final unlocked = await manager2.unlock('old-password');
      expect(unlocked, false);

      // New password should work
      final manager3 = createManager();
      final unlocked2 = await manager3.unlock('new-password');
      expect(unlocked2, true);
    });

    test('abortPasswordChange restores original record', () async {
      final manager = createManager();
      await manager.createPassword('original-password');
      await manager.unlock('original-password');
      final originalRecord = await manager.currentRecord();

      final change = await manager.preparePasswordChange('new-password');
      await manager.stagePasswordChange(change);

      await manager.abortPasswordChange(change);

      final restoredRecord = await manager.currentRecord();
      expect(restoredRecord!.salt, originalRecord.salt);
      expect(restoredRecord.iterations, originalRecord.iterations);
      expect(restoredRecord.check, originalRecord.check);
    });

    test('verifyPassword does not change session state', () async {
      final manager = createManager();
      await manager.createPassword('password');
      await manager.unlock('password');
      final keyBefore = manager.requireKey;

      final verified = await manager.verifyPassword('password');
      expect(verified, true);
      expect(identical(manager.requireKey, keyBefore), true);

      final verifiedWrong = await manager.verifyPassword('wrong');
      expect(verifiedWrong, false);
      expect(identical(manager.requireKey, keyBefore), true);
    });

    test('prepareDeviceKey creates wrapped record', () async {
      final manager = createManager();
      await manager.createPassword('password');
      await manager.unlock('password');

      final change = await manager.prepareDeviceKey('password');
      expect(change, isNotNull);
      expect(change!.record.isWrapped, true);
      expect(change.record.wrappedKey, isNotNull);
      expect(change.record.check, isNotNull);

      // Original key should still work for fallback
      final candidates = await manager.candidatesWithPassword('password');
      expect(candidates.length, greaterThanOrEqualTo(2));
    });

    test('rewrapPassword on v2 record does not change data key', () async {
      final manager = createManager();
      await manager.createPassword('old-password');
      await manager.unlock('old-password');

      // Enable quick unlock first (creates v2 record)
      final deviceChange = await manager.prepareDeviceKey('old-password');
      await manager.stageDeviceKey(deviceChange!);
      manager.commitDeviceKey(deviceChange);

      final dataKeyBefore = await manager.readDeviceKey();
      expect(dataKeyBefore, isNotNull);

      await manager.rewrapPassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      final dataKeyAfter = await manager.readDeviceKey();
      expect(dataKeyAfter, isNotNull);
      // Data key should be the same (only wrapping changed)
      final bytesBefore = await dataKeyBefore!.extractBytes();
      final bytesAfter = await dataKeyAfter!.extractBytes();
      expect(bytesAfter, bytesBefore);

      // Old password should not work, new password should
      final manager2 = createManager();
      expect(await manager2.unlock('old-password'), false);
      final manager3 = createManager();
      expect(await manager3.unlock('new-password'), true);
    });

    test('empty password throws ArgumentError', () async {
      final manager = createManager();
      expect(
        () => manager.createPassword(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => manager.unlock(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createPassword twice throws StateError', () async {
      final manager = createManager();
      await manager.createPassword('password');
      expect(
        () => manager.createPassword('another'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('VaultKeyRecord', () {
    test('toJson/fromJson roundtrip v1', () {
      const record = VaultKeyRecord(
        salt: [1, 2, 3, 4],
        iterations: 210000,
        check: 'enc:v1:abc',
      );

      final json = record.toJson();
      final restored = VaultKeyRecord.fromJson(json);

      expect(restored.salt, record.salt);
      expect(restored.iterations, record.iterations);
      expect(restored.check, record.check);
      expect(restored.wrappedKey, null);
      expect(restored.previous, null);
      expect(restored.isWrapped, false);
    });

    test('toJson/fromJson roundtrip v2 with wrappedKey', () {
      const record = VaultKeyRecord(
        salt: [5, 6, 7, 8],
        iterations: 210000,
        check: 'enc:v1:def',
        wrappedKey: 'enc:v1:wrapped',
      );

      final json = record.toJson();
      final restored = VaultKeyRecord.fromJson(json);

      expect(restored.salt, record.salt);
      expect(restored.iterations, record.iterations);
      expect(restored.check, record.check);
      expect(restored.wrappedKey, record.wrappedKey);
      expect(restored.isWrapped, true);
    });

    test('toJson/fromJson roundtrip with previous', () {
      const previous = VaultKeyRecord(
        salt: [1, 2],
        iterations: 1000,
        check: 'enc:v1:prev',
      );
      const record = VaultKeyRecord(
        salt: [3, 4],
        iterations: 210000,
        check: 'enc:v1:curr',
        previous: previous,
      );

      final json = record.toJson();
      final restored = VaultKeyRecord.fromJson(json);

      expect(restored.previous, isNotNull);
      expect(restored.previous!.salt, previous.salt);
      expect(restored.previous!.check, previous.check);
    });

    test('withoutPrevious removes previous', () {
      const previous = VaultKeyRecord(
        salt: [1, 2],
        iterations: 1000,
        check: 'enc:v1:prev',
      );
      const record = VaultKeyRecord(
        salt: [3, 4],
        iterations: 210000,
        check: 'enc:v1:curr',
        previous: previous,
      );

      final without = record.withoutPrevious();
      expect(without.previous, null);
      expect(without.salt, record.salt);
      expect(without.check, record.check);
    });

    test('fromJson throws on unknown version', () {
      expect(
        () => VaultKeyRecord.fromJson({'version': 999, 'kdf': 'x', 'iterations': 1, 'salt': 'YQ==', 'check': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on mismatched KDF', () {
      expect(
        () => VaultKeyRecord.fromJson({'version': 1, 'kdf': 'wrong', 'iterations': 1, 'salt': 'YQ==', 'check': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<Directory?> getApplicationDocumentsDirectory() async {
    // This won't be called because we use custom directoryProvider
    return Directory.systemTemp;
  }
}