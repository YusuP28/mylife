import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/services/vault_encryption_service.dart';

void main() {
  final key = SecretKeyData(List<int>.filled(AesGcmEncryption.keyLength, 7));
  final cipher = AesGcmEncryption(key);

  group('AesGcmEncryption', () {
    test('round-trip mengembalikan plaintext asli', () async {
      const plaintext = 'P@ssw0rd rahasia ✓';

      final encrypted = await cipher.encrypt(plaintext);

      expect(encrypted, startsWith(vaultEncryptionPrefix));
      expect(cipher.isEncrypted(encrypted), isTrue);
      expect(await cipher.decrypt(encrypted), plaintext);
    });

    test('nonce berbeda untuk plaintext yang sama', () async {
      final first = await cipher.encrypt('sama');
      final second = await cipher.encrypt('sama');

      String nonceOf(String stored) => base64Decode(
            stored.substring(vaultEncryptionPrefix.length),
          ).sublist(0, AesGcmEncryption.nonceLength).join(',');

      expect(first, isNot(second));
      expect(nonceOf(first), isNot(nonceOf(second)));
    });

    test('string kosong tidak dienkripsi', () async {
      expect(await cipher.encrypt(''), '');
      expect(cipher.isEncrypted(''), isFalse);
      expect(await cipher.decrypt(''), '');
    });

    test('plaintext lama tanpa prefix dikembalikan apa adanya', () async {
      expect(cipher.isEncrypted('password lama'), isFalse);
      expect(await cipher.decrypt('password lama'), 'password lama');
    });

    test('enkripsi ganda ditolak', () async {
      final encrypted = await cipher.encrypt('sekali saja');

      await expectLater(cipher.encrypt(encrypted), throwsArgumentError);
    });

    test('payload yang diubah gagal diautentikasi', () async {
      final encrypted = await cipher.encrypt('jangan diubah');
      final payload = base64Decode(
        encrypted.substring(vaultEncryptionPrefix.length),
      );
      payload[payload.length - 1] = payload.last ^ 0xFF;
      final tampered = '$vaultEncryptionPrefix${base64Encode(payload)}';

      await expectLater(
        cipher.decrypt(tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('versi prefix tak dikenal ditolak', () async {
      await expectLater(
        cipher.decrypt('enc:v2:AAAA'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('NoOpEncryption', () {
    test('identitas dan tidak pernah mengaku terenkripsi', () async {
      const noop = NoOpEncryption();

      expect(await noop.encrypt('teks'), 'teks');
      expect(await noop.decrypt('teks'), 'teks');
      expect(noop.isEncrypted('teks'), isFalse);
    });
  });
}
