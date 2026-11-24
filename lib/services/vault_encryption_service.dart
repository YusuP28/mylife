import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Layanan enkripsi untuk field sensitif brankas Vault.
///
/// Kontrak (Tahap 4B-1):
/// - Semua operasi kripto async karena `cryptography` async dan kunci bisa
///   berasal dari sumber async (master password / Keystore).
/// - `encrypt` menerima plaintext, mengembalikan string bertanda
///   [vaultEncryptionPrefix] agar bisa dibedakan dari data lama.
/// - `decrypt` menerima ciphertext bertanda tersebut. Nilai tanpa tanda
///   dianggap data lama plaintext dan dikembalikan apa adanya (mode transisi).
/// - String kosong tidak pernah dienkripsi: password boleh kosong.
///
/// Belum dipakai `DatabaseService`; integrasi ada di Tahap 4B-3.
abstract class VaultEncryptionService {
  /// `false` untuk [NoOpEncryption]: tidak ada yang perlu dienkripsi/dimigrasi.
  bool get encryptsData;

  Future<String> encrypt(String plaintext);

  Future<String> decrypt(String storedValue);

  bool isEncrypted(String value);
}

/// Penanda ciphertext versi 1. Base64 tidak pernah memuat `:`, jadi aman
/// dipakai sebagai pembeda tanpa mengubah skema database.
const String vaultEncryptionPrefix = 'enc:v1:';

/// Implementasi sementara: tidak mengubah data (plaintext di SQLite).
///
/// Dipertahankan sebagai default sampai `DatabaseService` diintegrasikan.
class NoOpEncryption implements VaultEncryptionService {
  const NoOpEncryption();

  @override
  bool get encryptsData => false;

  @override
  bool isEncrypted(String value) => false;

  @override
  Future<String> encrypt(String plaintext) async => plaintext;

  @override
  Future<String> decrypt(String storedValue) async => storedValue;
}

/// AES-256-GCM dengan nonce 12 byte acak per operasi.
///
/// Format tersimpan: `enc:v1:<base64(nonce ‖ ciphertext ‖ mac)>`.
class AesGcmEncryption implements VaultEncryptionService {
  AesGcmEncryption(SecretKey key)
      : _key = key,
        _algorithm = AesGcm.with256bits();

  /// Kunci dari byte mentah (32 byte untuk AES-256).
  factory AesGcmEncryption.fromBytes(List<int> bytes) =>
      AesGcmEncryption(SecretKeyData(bytes));

  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int keyLength = 32;

  final SecretKey _key;
  final AesGcm _algorithm;

  @override
  bool get encryptsData => true;

  @override
  bool isEncrypted(String value) => value.startsWith(vaultEncryptionPrefix);

  @override
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    if (isEncrypted(plaintext)) {
      throw ArgumentError.value(
        plaintext,
        'plaintext',
        'Nilai sudah terenkripsi, jangan enkripsi dua kali',
      );
    }

    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
    );

    final cipherLength = box.cipherText.length;
    final payload = Uint8List(nonceLength + cipherLength + macLength)
      ..setRange(0, nonceLength, box.nonce)
      ..setRange(nonceLength, nonceLength + cipherLength, box.cipherText)
      ..setRange(
        nonceLength + cipherLength,
        nonceLength + cipherLength + macLength,
        box.mac.bytes,
      );

    return '$vaultEncryptionPrefix${base64Encode(payload)}';
  }

  @override
  Future<String> decrypt(String storedValue) async {
    if (storedValue.isEmpty) return storedValue;

    if (storedValue.startsWith('enc:') && !isEncrypted(storedValue)) {
      throw UnsupportedError(
        'Versi enkripsi tidak dikenal: ${storedValue.split(':').take(2).join(':')}',
      );
    }

    // Data lama (sebelum Tahap 4B) belum punya penanda: kembalikan apa adanya.
    if (!isEncrypted(storedValue)) return storedValue;

    final payload = base64Decode(
      storedValue.substring(vaultEncryptionPrefix.length),
    );
    if (payload.length < nonceLength + macLength) {
      throw const FormatException('Payload enkripsi terlalu pendek');
    }

    final nonce = payload.sublist(0, nonceLength);
    final macStart = payload.length - macLength;
    final cipherText = payload.sublist(nonceLength, macStart);
    final mac = Mac(payload.sublist(macStart));

    final clearBytes = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: _key,
    );

    return utf8.decode(clearBytes);
  }
}

/// Cipher saat vault terkunci.
///
/// Semua operasi gagal keras: tidak pernah menulis plaintext dan tidak pernah
/// membocorkan ciphertext ke UI. Dipasang ulang ke `AesGcmEncryption` setelah
/// unlock berhasil.
class LockedEncryption implements VaultEncryptionService {
  const LockedEncryption();

  @override
  bool get encryptsData => true;

  @override
  bool isEncrypted(String value) => value.startsWith(vaultEncryptionPrefix);

  @override
  Future<String> encrypt(String plaintext) async =>
      throw StateError('Vault terkunci: buka dengan password');

  @override
  Future<String> decrypt(String storedValue) async =>
      throw StateError('Vault terkunci: buka dengan password');
}

/// Singleton default. Ganti ke [AesGcmEncryption] saat integrasi database.
const VaultEncryptionService vaultEncryptionService = NoOpEncryption();
