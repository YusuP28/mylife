/// Layanan enkripsi untuk item brankas Vault.
///
/// **Catatan keamanan (Tahap 4A)**:
/// File ini menyediakan abstraksi enkripsi tanpa mengubah skema database.
/// Implementasi `NoOpEncryption` tidak mengubah data — hanya untuk migrasi keamanan.
///
/// **Prasyarat untuk Tahap 4B (enkripsi produksi)**:
/// 1. Tambah dependency `encrypt` atau `cryptography` di pubspec.yaml.
/// 2. Implementasikan `VaultEncryptionService` dengan AES-256-GCM.
/// 3. Tambahkan master password / kunci utama pengguna.
/// 4. Naikkan `_dbVersion` ke 4 untuk migration kolom kunci (misal: `is_encrypted INTEGER`).
/// 5. Backup data sebelum migrasi bulk.
///
/// **Field sensitif yang akan dienkripsi**:
/// - `VaultItem.password` (wajib)
/// - `VaultItem.notes` (opsional, tergantung kebijakan)
///
/// **Titik akses yang perlu di-audit**:
/// - `VaultItem.fromMap()` — deserialisasi: password sudah plaintext atau terenkripsi.
/// - `VaultItem.toMap()` — serialisasi: password harus dienkripsi sebelum disimpan.
/// - `VaultProvider.addItem()` / `updateItem()` — harus enkripsi sebelum store.
/// - `VaultProvider.loadItems()` — harus decrypt setelah ambil dari DB (bila Tahap 4B).
abstract class VaultEncryptionService {
  /// Mengenkripsi string sensitif.
  String encrypt(String plaintext);

  /// Mende-crypt string yang sudah dienkripsi.
  String decrypt(String ciphertext);

  /// Mengubah plaintext menjadi bentuk yang aman untuk disimpan.
  /// Untuk Tahap 4B: gunakan `encrypt()`. Untuk Tahap 4A: identity.
  String prepareForStorage(String value) => encrypt(value);

  /// Mengambil nilai yang aman untuk ditampilkan.
  /// Untuk Tahap 4B: gunakan `decrypt()`. Untuk Tahap 4A: identity.
  String getSecureValue(String storedValue) => decrypt(storedValue);
}

/// Implementasi NoOp — tidak mengubah data.
///
/// **Digunakan sampai Tahap 4B** ketika enkripsi resmi diaktifkan.
/// Semua data tetap plaintext di SQLite.
class NoOpEncryption implements VaultEncryptionService {
  const NoOpEncryption();

  @override
  String encrypt(String plaintext) => plaintext;

  @override
  String decrypt(String ciphertext) => ciphertext;
}

/// Singleton instance penggunaan default.
const vaultEncryptionService = NoOpEncryption();