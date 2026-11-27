import 'package:cryptography/cryptography.dart' as crypto show Hmac, Mac, SecretKeyData, sha1;

/// Item brankas (kredensial/catatan sensitif).
///
/// Catatan keamanan: Tahap 1 menyimpan data sebagai teks biasa di database
/// lokal. Enkripsi belum diterapkan karena Tahap 1 fokus ke lapisan data dan
/// tidak menambah dependency. Jangan dipakai untuk kredensial produksi
/// sebelum enkripsi tersedia.
class VaultItem {
  const VaultItem({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totpUri, // TOTP secret URI (otpauth://...)
  });

  final int? id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? totpUri;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'totp_uri': totpUri ?? '',
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory VaultItem.fromMap(Map<String, Object?> map) => VaultItem(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        username: map['username'] as String? ?? '',
        password: map['password'] as String? ?? '',
        url: map['url'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        totpUri: (map['totp_uri'] as String? ?? '').isEmpty ? null : map['totp_uri'] as String?,
        createdAt: _dateFrom(map['created_at']),
        updatedAt: _dateFrom(map['updated_at']),
      );

  VaultItem copyWith({
    int? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? totpUri,
  }) => VaultItem(
        id: id ?? this.id,
        title: title ?? this.title,
        username: username ?? this.username,
        password: password ?? this.password,
        url: url ?? this.url,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        totpUri: totpUri ?? this.totpUri,
      );

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Parses TOTP URI and returns (secret, issuer, accountName).
  /// URI format: otpauth://totp/Issuer:accountName?secret=BASE32&issuer=Issuer
  static ({String secret, String issuer, String accountName})? parseTotpUri(String uri) {
    try {
      final uriObj = Uri.parse(uri);
      if (uriObj.scheme != 'otpauth' || uriObj.host != 'totp') return null;

      final path = uriObj.path;
      if (path.isEmpty) return null;

      // Path format: /Issuer:accountName or /accountName
      final pathParts = path.substring(1).split(':');
      String issuer = '';
      String accountName = '';
      if (pathParts.length == 2) {
        issuer = Uri.decodeComponent(pathParts[0]);
        accountName = Uri.decodeComponent(pathParts[1]);
      } else {
        accountName = Uri.decodeComponent(pathParts[0]);
      }

      final secret = uriObj.queryParameters['secret'];
      final issuerParam = uriObj.queryParameters['issuer'];
      if (secret == null || secret.isEmpty) return null;

      return (
        secret: secret.toUpperCase().replaceAll(' ', ''),
        issuer: issuerParam?.isNotEmpty == true ? issuerParam! : issuer,
        accountName: accountName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates current TOTP code from stored URI.
  String? generateTotpCode() {
    if (totpUri == null || totpUri!.isEmpty) return null;
    final parsed = parseTotpUri(totpUri!);
    if (parsed == null) return null;

    // TOTP implementation (RFC 6238) using cryptography package
    // Time step: 30 seconds, 6 digits, HMAC-SHA1
    final secretBytes = base32Decode(parsed.secret);
    final timeStep = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
    final timeBytes = _int64ToBytes(timeStep);

    // HMAC-SHA1 using cryptography package
    final secretKey = crypto.SecretKeyData(secretBytes);
    final hmac = crypto.Hmac(crypto.sha1);
    final mac = hmac.mac(timeBytes, secretKey: secretKey);
    final digest = mac.bytes;

    // Dynamic truncation
    final offset = digest[19] & 0x0F;
    final code = ((digest[offset] & 0x7F) << 24 |
        (digest[offset + 1] & 0xFF) << 16 |
        (digest[offset + 2] & 0xFF) << 8 |
        (digest[offset + 3] & 0xFF)) % 1000000;

    return code.toString().padLeft(6, '0');
  }

  /// Returns seconds until next code refresh.
  int get totpSecondsRemaining {
    if (totpUri == null || totpUri!.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 30 - (now % 30);
  }
}

// Simple base32 decode (RFC 4648)
List<int> base32Decode(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final clean = input.replaceAll('=', '').toUpperCase();
  final bits = <int>[];
  for (final codeUnit in clean.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final idx = alphabet.indexOf(char);
    if (idx == -1) continue;
    for (int i = 4; i >= 0; i--) {
      bits.add((idx >> i) & 1);
    }
  }
  final bytes = <int>[];
  for (int i = 0; i + 7 < bits.length; i += 8) {
    int byte = 0;
    for (int j = 0; j < 8; j++) {
      byte = (byte << 1) | bits[i + j];
    }
    bytes.add(byte);
  }
  return bytes;
}

List<int> _int64ToBytes(int value) {
  return List<int>.generate(8, (i) => (value >> (56 - i * 8)) & 0xFF);
}
