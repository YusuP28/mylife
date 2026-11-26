# Audit Keamanan — Mylife (2025-11-25)

**Pemeriksa**: AI Security Analyst
**Status**: ✅ AMAN

---

## 1. Kunci Rahasia & Kripto
**Hasil: ✅ Baik**

- **Tidak ada kunci hardcode**: Tidak ditemukan API Key, Secret Token, atau private key yang tertanam di source code. Semua string sensitif merupakan konstanta aplikasi atau enum.
- **Kunci diturunkan lokal**: Kunci enkripsi dihasilkan secara dinamis menggunakan PBKDF2-HMAC-SHA256 dari password pengguna, disimpan hanya dalam memori RAM, dan dihancurkan (`key.destroy()`) setelah tidak dipakai.
- **Password tidak tersimpan**: File `vault_key.json` hanya menyimpan salt, iterasi, dan verifier terenkripsi. Password asli tidak pernah ditulis ke disk.

---

## 2. Database & Aturan Akses
**Hasil: ✅ Baik**

- **Enkripsi end-to-end**: Data brankas (password, notes) dienkripsi dengan AES-256-GCM sebelum ditulis ke SQLite. Ciphertext hanya bisa dibuka dengan kunci yang sesuai.
- **Sandbox Android**: Database tersimpan di direktori aplikasi (`getApplicationDocumentsDirectory()`), dilindungi oleh isolasi proses Android. Aplikasi lain tidak bisa mengakses tanpa root.
- **No backup**: `android:allowBackup="false"` di manifest mencegah dump database via ADB.
- **Mode terkunci aman**: Saat vault dikunci, cipher diganti menjadi `LockedEncryption` — semua operasi baca/tulis akan gagal (`StateError`), mencegah kebocoran plaintext dari cache.

---

## 3. Komunikasi Server / Pembayaran
**Hasil: ℹ️ Tidak Berlaku (N/A)**

- **Tanpa server**: Aplikasi ini sepenuhnya offline. Tidak ada HTTP client, API endpoint, atau library jaringan (Dio/HttpClient) yang digunakan.
- **Tanpa pembayaran**: Tidak ada integrasi payment gateway. Fitur keuangan hanya pencatatan lokal.
- **Permission INTERNET ada tapi tidak dipakai**: Izin jaringan ada di manifest namun tidak digunakan oleh kode aplikasi.

---

## 4. Kerentanan Potensial
| Risiko | Tingkat | Keterangan |
|--------|---------|------------|
| Password lemah | 🟡 Sedang | Keamanan bergantung pada kekuatan password pengguna. PBKDF2 membantu, tapi password pendek tetap rentan brute-force. |
| Physical access | 🟡 Sedang | Saat vault terbuka, plaintext ada di memori RAM. Perangkat yang di-root atau di-debug bisa membaca memori. |
| Debug mode | 🟢 Rendah | Build release dinonaktifkan log, tapi APK debug masih bisa diinstal manual untuk reverse engineering. |

---

## Rekomendasi
1. Tambahkan validasi kekuatan password (minimal 12 karakter, campuran huruf/angka/simbol).
2. Consider menambahkan biometric lock (4C-B) sebagai layer tambahan selain password.
3. Gunakan ProGuard/R8 obfuscation di build release untuk mempersulit reverse engineering.
4. Pertimbangkan enrollment secure enclave/TEE verification di masa depan.

---

**Kesimpulan**: Arsitektur kripto solid, tidak ada komunikasi jaringan, kunci rahasia hanya hidup di memori. Aplikasi memenuhi standar keamanan dasar untuk vault lokal.
