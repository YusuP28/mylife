import 'package:flutter_test/flutter_test.dart';

import 'package:mylife/models/vault_item.dart';

void main() {
  group('VaultItem TOTP', () {
    const testTotpUri = 'otpauth://totp/Google:user@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=Google';

    test('parseTotpUri extracts secret, issuer, accountName', () {
      final parsed = VaultItem.parseTotpUri(testTotpUri);
      expect(parsed, isNotNull);
      expect(parsed!.secret, 'JBSWY3DPEHPK3PXP');
      expect(parsed.issuer, 'Google');
      expect(parsed.accountName, 'user@gmail.com');
    });

    test('parseTotpUri handles URI without issuer param', () {
      const uri = 'otpauth://totp/Example:test@example.com?secret=ABCDEFGHIJKLMNOP';
      final parsed = VaultItem.parseTotpUri(uri);
      expect(parsed, isNotNull);
      expect(parsed!.secret, 'ABCDEFGHIJKLMNOP');
      expect(parsed.issuer, 'Example');
      expect(parsed.accountName, 'test@example.com');
    });

    test('parseTotpUri handles URI with only account name', () {
      const uri = 'otpauth://totp/test@example.com?secret=ABCDEFGHIJKLMNOP';
      final parsed = VaultItem.parseTotpUri(uri);
      expect(parsed, isNotNull);
      expect(parsed!.secret, 'ABCDEFGHIJKLMNOP');
      expect(parsed.issuer, '');
      expect(parsed.accountName, 'test@example.com');
    });

    test('parseTotpUri returns null for invalid URI', () {
      expect(VaultItem.parseTotpUri('invalid'), null);
      expect(VaultItem.parseTotpUri('https://example.com'), null);
      expect(VaultItem.parseTotpUri('otpauth://hotp/...'), null); // HOTP not supported
      expect(VaultItem.parseTotpUri('otpauth://totp/?secret='), null); // empty secret
    });

    test('generateTotpCode returns 6-digit code', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totpUri: testTotpUri,
      );

      final code = item.generateTotpCode();
      expect(code, isNotNull);
      expect(code!.length, 6);
      expect(int.tryParse(code), isNotNull); // All digits
    });

    test('generateTotpCode returns null for empty totpUri', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totpUri: null,
      );

      expect(item.generateTotpCode(), null);
    });

    test('generateTotpCode returns null for invalid totpUri', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totpUri: 'invalid-uri',
      );

      expect(item.generateTotpCode(), null);
    });

    test('totpSecondsRemaining returns 0-30', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totpUri: testTotpUri,
      );

      final remaining = item.totpSecondsRemaining;
      expect(remaining, greaterThanOrEqualTo(0));
      expect(remaining, lessThanOrEqualTo(30));
    });

    test('copyWith preserves totpUri', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totpUri: testTotpUri,
      );

      final copied = item.copyWith(title: 'New Title');
      expect(copied.totpUri, testTotpUri);
      expect(copied.title, 'New Title');
    });

    test('copyWith can update totpUri', () {
      final item = VaultItem(
        id: 1,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: '',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copied = item.copyWith(totpUri: testTotpUri);
      expect(copied.totpUri, testTotpUri);
    });

    test('toMap/fromMap roundtrip preserves totpUri', () {
      const now = DateTime(2026, 1, 1);
      final item = VaultItem(
        id: 42,
        title: 'Test',
        username: 'user',
        password: 'pass',
        url: 'https://example.com',
        notes: 'notes',
        createdAt: now,
        updatedAt: now,
        totpUri: testTotpUri,
      );

      final map = item.toMap();
      final restored = VaultItem.fromMap(map);

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.username, item.username);
      expect(restored.password, item.password);
      expect(restored.url, item.url);
      expect(restored.notes, item.notes);
      expect(restored.totpUri, item.totpUri);
      expect(restored.createdAt, item.createdAt);
      expect(restored.updatedAt, item.updatedAt);
    });

    test('fromMap handles missing totp_uri gracefully', () {
      final map = {
        'id': 1,
        'title': 'Test',
        'username': 'user',
        'password': 'pass',
        'url': '',
        'notes': '',
        'totp_uri': '',
        'created_at': 1700000000000,
        'updated_at': 1700000000000,
      };

      final item = VaultItem.fromMap(map);
      expect(item.totpUri, null);
    });
  });

  group('base32Decode', () {
    test('decodes valid base32', () {
      // JBSWY3DPEHPK3PXP = "Hello!" in base32
      final decoded = base32Decode('JBSWY3DPEHPK3PXP');
      expect(decoded.length, 10); // 10 bytes for "Hello!"
    });

    test('handles lowercase', () {
      final decoded = base32Decode('jbswy3dpehpK3pxp');
      expect(decoded.length, 10);
    });

    test('ignores padding', () {
      final decoded = base32Decode('JBSWY3DPEHPK3PXP======');
      expect(decoded.length, 10);
    });

    test('ignores invalid chars', () {
      // Add some invalid chars, should be skipped
      final decoded = base32Decode('JBSWY3DPEHPK3PXP!@#');
      expect(decoded.length, 10);
    });
  });
}