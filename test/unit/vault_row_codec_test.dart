import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mylife/services/vault_encryption_service.dart';
import 'package:mylife/services/vault_row_codec.dart';
import 'package:mylife/models/vault_item.dart';

void main() {
  group('VaultRowCodec', () {
    const testItem = VaultItem(
      id: 1,
      title: 'Test Entry',
      username: 'user@example.com',
      password: 'secret-password-123',
      url: 'https://example.com',
      notes: 'Important notes here',
      createdAt: 1700000000000,
      updatedAt: 1700000000000,
    );

    test('NoOpEncryption: encryptRow/decryptRow are identity', () async {
      const codec = VaultRowCodec(NoOpEncryption());

      final encrypted = await codec.encryptRow(testItem.toMap());
      expect(encrypted['title'], testItem.title);
      expect(encrypted['username'], testItem.username);
      expect(encrypted['password'], testItem.password);
      expect(encrypted['url'], testItem.url);
      expect(encrypted['notes'], testItem.notes);
      expect(encrypted['created_at'], testItem.createdAt);
      expect(encrypted['updated_at'], testItem.updatedAt);

      final decrypted = await codec.decryptRow(encrypted);
      expect(decrypted['title'], testItem.title);
      expect(decrypted['password'], testItem.password);
      expect(decrypted['notes'], testItem.notes);
    });

    test('NoOpEncryption: rowNeedsMigration returns false', () {
      const codec = VaultRowCodec(NoOpEncryption());
      final row = testItem.toMap();
      expect(codec.rowNeedsMigration(row), false);
    });

    test('NoOpEncryption: encryptsData is false', () {
      const codec = VaultRowCodec(NoOpEncryption());
      expect(codec.encryptsData, false);
    });

    test('AesGcmEncryption: encrypts password and notes only', () async {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));

      final encrypted = await codec.encryptRow(testItem.toMap());

      // Non-sensitive fields unchanged
      expect(encrypted['title'], testItem.title);
      expect(encrypted['username'], testItem.username);
      expect(encrypted['url'], testItem.url);
      expect(encrypted['created_at'], testItem.createdAt);
      expect(encrypted['updated_at'], testItem.updatedAt);

      // Sensitive fields encrypted with prefix
      expect(encrypted['password'], startsWith('enc:v1:'));
      expect(encrypted['notes'], startsWith('enc:v1:'));
      expect(encrypted['password'], isNot(equals(testItem.password)));
      expect(encrypted['notes'], isNot(equals(testItem.notes)));
    });

    test('AesGcmEncryption: decryptRow restores original values', () async {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));

      final encrypted = await codec.encryptRow(testItem.toMap());
      final decrypted = await codec.decryptRow(encrypted);

      expect(decrypted['title'], testItem.title);
      expect(decrypted['username'], testItem.username);
      expect(decrypted['password'], testItem.password);
      expect(decrypted['url'], testItem.url);
      expect(decrypted['notes'], testItem.notes);
      expect(decrypted['created_at'], testItem.createdAt);
      expect(decrypted['updated_at'], testItem.updatedAt);
    });

    test('AesGcmEncryption: rowNeedsMigration detects plaintext', () async {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));

      // Plaintext row (no encryption prefix)
      final plainRow = testItem.toMap();
      expect(codec.rowNeedsMigration(plainRow), true);

      // Encrypted row
      final encrypted = await codec.encryptRow(testItem.toMap());
      expect(codec.rowNeedsMigration(encrypted), false);
    });

    test('AesGcmEncryption: encryptsData is true', () {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));
      expect(codec.encryptsData, true);
    });

    test('AesGcmEncryption: empty password/notes not encrypted', () async {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));

      const item = VaultItem(
        id: 2,
        title: 'Empty Fields',
        username: '',
        password: '',
        url: '',
        notes: '',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      final encrypted = await codec.encryptRow(item.toMap());
      expect(encrypted['password'], '');
      expect(encrypted['notes'], '');
      expect(encrypted['password'], isNot(startsWith('enc:v1:')));
      expect(encrypted['notes'], isNot(startsWith('enc:v1:')));
    });

    test('AesGcmEncryption: idempotent - encrypting twice throws', () async {
      final key = SecretKeyData(List<int>.generate(32, (i) => i));
      const codec = VaultRowCodec(AesGcmEncryption(key));

      final encrypted = await codec.encryptRow(testItem.toMap());
      // Manually create a row with already encrypted password
      final doubleEncrypted = Map<String, Object?>.from(encrypted)
        ..['password'] = encrypted['password'];

      // Should throw because password already has encryption prefix
      expect(
        () => codec.encryptRow(doubleEncrypted),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('LockedEncryption: encrypt/decrypt throw StateError', () async {
      const codec = VaultRowCodec(LockedEncryption());

      expect(
        () => codec.encryptRow(testItem.toMap()),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.decryptRow(testItem.toMap()),
        throwsA(isA<StateError>()),
      );
    });

    test('LockedEncryption: rowNeedsMigration returns true for plaintext', () {
      const codec = VaultRowCodec(LockedEncryption());
      expect(codec.rowNeedsMigration(testItem.toMap()), true);
    });

    test('LockedEncryption: encryptsData is true', () {
      const codec = VaultRowCodec(LockedEncryption());
      expect(codec.encryptsData, true);
    });

    test('fromMap/toMap roundtrip preserves all fields', () {
      final map = testItem.toMap();
      final restored = VaultItem.fromMap(map);

      expect(restored.id, testItem.id);
      expect(restored.title, testItem.title);
      expect(restored.username, testItem.username);
      expect(restored.password, testItem.password);
      expect(restored.url, testItem.url);
      expect(restored.notes, testItem.notes);
      expect(restored.createdAt, testItem.createdAt);
      expect(restored.updatedAt, testItem.updatedAt);
    });
  });
}