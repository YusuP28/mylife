import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/services/vault_encryption_service.dart';
import 'package:mylife/services/vault_row_codec.dart';

Map<String, Object?> _legacyRow() => <String, Object?>{
      'id': 1,
      'title': 'GitHub',
      'username': 'yusup',
      'password': 'p@ssw0rd',
      'url': 'https://github.com',
      'notes': 'akun kerja',
      'created_at': 1,
      'updated_at': 2,
    };

VaultRowCodec _aesCodec() => VaultRowCodec(
      AesGcmEncryption.fromBytes(
        List<int>.filled(AesGcmEncryption.keyLength, 9),
      ),
    );

void main() {
  group('NoOpEncryption', () {
    test('baris tidak berubah dan tidak perlu migrasi', () async {
      const codec = VaultRowCodec(NoOpEncryption());
      final row = _legacyRow();

      expect(codec.encryptsData, isFalse);
      expect(codec.rowNeedsMigration(row), isFalse);
      expect(await codec.encryptRow(row), row);
      expect(await codec.decryptRow(row), row);
    });
  });

  group('AesGcmEncryption', () {
    test('hanya password dan notes yang dienkripsi', () async {
      final codec = _aesCodec();
      final row = _legacyRow();

      final encrypted = await codec.encryptRow(row);

      expect(encrypted['password'], startsWith(vaultEncryptionPrefix));
      expect(encrypted['notes'], startsWith(vaultEncryptionPrefix));
      expect(encrypted['title'], row['title']);
      expect(encrypted['username'], row['username']);
      expect(encrypted['url'], row['url']);
      expect(encrypted['id'], row['id']);
      expect(encrypted['created_at'], row['created_at']);
    });

    test('decryptRow mengembalikan baris asli', () async {
      final codec = _aesCodec();
      final row = _legacyRow();

      final roundTrip = await codec.decryptRow(await codec.encryptRow(row));

      expect(roundTrip, row);
    });

    test('rowNeedsMigration hanya untuk plaintext tidak kosong', () async {
      final codec = _aesCodec();
      final row = _legacyRow();

      expect(codec.rowNeedsMigration(row), isTrue);
      expect(codec.rowNeedsMigration(await codec.encryptRow(row)), isFalse);
      expect(
        codec.rowNeedsMigration(<String, Object?>{
          'id': 2,
          'password': '',
          'notes': '',
        }),
        isFalse,
      );
    });

    test('enkripsi ulang baris terenkripsi tidak mengubah nilai', () async {
      final codec = _aesCodec();
      final encrypted = await codec.encryptRow(_legacyRow());

      final again = await codec.encryptRow(encrypted);

      expect(again['password'], encrypted['password']);
      expect(again['notes'], encrypted['notes']);
    });

    test('baris lama tanpa prefix tetap terbaca', () async {
      final codec = _aesCodec();

      final decoded = await codec.decryptRow(_legacyRow());

      expect(decoded['password'], 'p@ssw0rd');
      expect(decoded['notes'], 'akun kerja');
    });

    test('field kosong dibiarkan kosong', () async {
      final codec = _aesCodec();

      final encrypted = await codec.encryptRow(<String, Object?>{
        'password': '',
        'notes': '',
      });

      expect(encrypted['password'], '');
      expect(encrypted['notes'], '');
    });
  });
}
