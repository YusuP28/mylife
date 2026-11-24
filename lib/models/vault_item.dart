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
  });

  final int? id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
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
        createdAt: _dateFrom(map['created_at']),
        updatedAt: _dateFrom(map['updated_at']),
      );

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
