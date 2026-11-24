# Mylife — Handover untuk AI Berikutnya

## Ringkasan Proyek
Aplikasi Flutter **All-in-One: Notes, Finance, Vault** (package `com.yusup28.mylife`).
Build **100% via GitHub Actions** (split ABI arm64-v8a). **Dilarang build lokal di Termux/HP.**

## Status Terkini (2026-11-23)
| Komponen | Status |
|----------|--------|
| Struktur folder (`lib/screens/*`, `models`, `providers`, `services`, `widgets`) | ✅ Done |
| `pubspec.yaml` deps: provider, sqflite, path_provider, intl, archive | ✅ Done |
| `lib/main.dart` + UI scaffold (tema, HomeShell, 4 screen modul, placeholder) | ✅ Done |
| Modul Catatan: `Note` + `DatabaseService` + `NotesProvider` + list/FAB + pencarian | ✅ Done |
| Android V2 embedding (MainActivity.kt, Manifest, styles, launch_background) | ✅ Done |
| Gradle 9.5.0 / AGP 9.3.1 / Built-in Kotlin 2.4.10 / Java 17 | ✅ Done |
| Build terakhir: Run ID **45367215117** (success, artifact `mylife-apk`) | ✅ Green |

## Struktur Kunci
```
mylife/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  # entry: ChangeNotifierProvider > MaterialApp
│   ├── theme/
│   │   └── app_theme.dart         # tema terang bersih (Material 3)
│   ├── models/
│   │   ├── note.dart              # entity Note + toMap/fromMap
│   │   ├── finance_transaction.dart
│   │   └── vault_item.dart
│   ├── providers/
│   │   ├── notes_provider.dart    # ChangeNotifier
│   │   ├── finance_provider.dart
│   │   └── vault_provider.dart
│   ├── services/
│   │   ├── database_service.dart  # singleton sqflite, mylife.db
│   │   └── vault_encryption_service.dart  # interface + NoOp (Tahap 4A)
│   ├── widgets/
│   │   └── module_placeholder.dart # kartu placeholder modul
│   └── screens/
│       ├── home_shell.dart        # NavigationBar + IndexedStack
│       ├── notes/notes_screen.dart
│       ├── notes/note_editor_screen.dart
│       ├── finance/finance_screen.dart
│       ├── finance/finance_editor_screen.dart
│       ├── vault/vault_screen.dart
│       ├── vault/vault_editor_screen.dart
│       └── settings/settings_screen.dart
├── android/
│   ├── settings.gradle           # pluginManagement: AGP 9.3.1 + flutter-plugin-loader
│   ├── build.gradle              # allprojects repositories only
│   ├── gradle.properties         # JVM args (heap/metaspace), AndroidX
│   ├── gradle/wrapper/gradle-wrapper.properties  # Gradle 9.5.0
│   ├── app/
│   │   ├── build.gradle          # plugins {} di atas, localProperties di bawah
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   ├── kotlin/com/yusup28/mylife/MainActivity.kt
│   │   │   ├── res/values/styles.xml
│   │   │   └── res/drawable/launch_background.xml
│   └── local.properties          # GENERATED (tidak di-track), dibaca Flutter tool
└── .github/workflows/build.yml   # Java 17 → Flutter 3.50 → pub get → build apk --split-per-abi
```

## Aturan Keras (WAJIB DIIKUTI)
1. **No local build** — hanya `gh workflow run build.yml` atau push ke `main`.
2. **Versi terbaru stabil** — Flutter, Kotlin, Gradle, AGP, paket Dart. Cek pub.dev/gradle.org/flutter.dev sebelum set versi.
3. **Flutter 3.50 / Gradle 9.5.0 compliance** — `plugins {}` block **harus di baris pertama** file `.gradle`; AGP 9.3.1 butuh Gradle 9.5.0.
4. **Split ABI arm64-v8a** — `--split-per-abi --target-platform android-arm64` untuk rilis.
5. **Scope aman** — jangan baca/tulis `~/.ssh/`, `~/.gnupg/`, `~/.config/opencode2/`.
6. **Post-build otomatis (tanpa konfirmasi)** — setiap build sukses langsung: update baris `Build terakhir` + link `Build terkini` di HANDOVER, commit `docs: update latest build run id in HANDOVER.md`, push `main`, lalu unduh artifact `mylife-apk` ke `build/artifact-<RUN_ID>/`.
7. **Pemantauan build manual** — Bos memantau status build sendiri. Agent **tidak** polling / menjalankan `gh run view` / `gh run watch` kecuali diminta.

## Perintah Rutin
```bash
# Cek status build (dijalankan Bos, bukan agent)
gh run view <RUN_ID>

# Trigger build manual
gh workflow run build.yml

# Lihat log error
gh run view <RUN_ID> --log-failed

# Push perubahan
cd ~/mylife && git add . && git commit -m "pesan" && git push

# Alur post-build otomatis (setelah build sukses, tanpa konfirmasi)
# 1) update baris "Build terakhir" + link "Build terkini" ke <RUN_ID>
# 2) commit: git commit -m "docs: update latest build run id in HANDOVER.md"
# 3) push ke main, lalu unduh:
cd ~/mylife && mkdir -p build/artifact-<RUN_ID> \
  && gh run download <RUN_ID> -n mylife-apk -D build/artifact-<RUN_ID>
```

## Catatan Teknis Penting
- **Arsitektur modul Catatan**: `Note` (model murni) → `DatabaseService` (sqflite, `mylife.db`, tabel `notes` dengan `CREATE TABLE IF NOT EXISTS`, `_dbVersion = 1`) → `NotesProvider` (`ChangeNotifier`) → UI. Provider didaftarkan di `main.dart` dan di-`loadNotes()` saat inisialisasi. **Pencarian**: `NotesProvider._query` + `setQuery()` + getter `visibleNotes` (filter in-memory, case-insensitive). **Editor**: `NoteEditorScreen` untuk create/edit dengan toolbar format ringan (markdown-style markers), undo/redo, save guard. **Peringatan**: tidak ada enkripsi.
- **Arsitektur modul Keuangan (Tahap 1)**: `FinanceTransaction` (model) → `DatabaseService` (tabel `transactions` dengan `type`, `amount` INTEGER, `category`, `note`, `occurred_at`, `created_at`, `updated_at`; `_dbVersion = 2`) → `FinanceProvider` → `main.dart`. **Tahap 2**: `FinanceScreen` dengan kartu ringkasan (saldo, pemasukan, pengeluaran, format `NumberFormat.currency(id_ID)`), daftar transaksi berwarna hijau-merah. **Tahap 3**: `FinanceEditorScreen` dengan `SegmentedButton` tipe, validasi nominal, `showDatePicker`. **Tahap 4**: pencarian + filter in-memory (`visibleTransactions`, `typeFilter`, `monthFilter`, `categoryFilter`, `resetFilters()`). Semua tahap: tidak ubah skema DB.
- **Vault Tahap 1 (data layer)**: tabel `vault_items` (id, title*, username, password, url, notes, created_at, updated_at), CRUD via `DatabaseService` (`_dbVersion = 3`), tidak ada enkripsi.
- **Vault Tahap 2**: `VaultScreen` dengan list item, password toggle (`🔒`/`🔓`), timestamp, tidak ada hapus/edit.
- **Vault Tahat 3**: `VaultProvider.visibleItems` dengan pencarian aktif, `VaultEditorScreen` (5 field), copy password ke clipboard, delete dengan dialog konfirmasi. Semua method nyata, tidak ada placeholder dummy. **Peringatan: data tetap plaintext — jangan simpan kredensial penting sebelum Tahap 4 (enkripsi).**
- **Pengaturan Tahap 1**: `SettingsScreen` menampilkan ringkasan status data lokal (catatan, Keuangan, Vault), tautan info "Tentang", security warning. Tidak ada aksi dummy, tidak ubah skema DB (`_dbVersion` tetap 3), tidak ada dependency baru.
- **Settings Tahap 2**: tambahkan `DataManagementSection` dengan tombol reset per modul (Catatan / Keuangan / Vault), dialog konfirmasi ganda, dan SnackBar feedback (`clearAllNotes`, `clearAllTransactions`, `clearAllItems`). Semua aksi method nyata. `_dbVersion` tetap 3, tidak ada dependency baru.
- **Tema terang bersih** terpusat di `lib/theme/app_theme.dart` (`AppTheme.light`).
- **Flutter Gradle plugin**: `settings.gradle` memakai `includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")` **di dalam** `pluginManagement {}`, lalu plugin `dev.flutter.flutter-plugin-loader` di-apply di settings dan `dev.flutter.flutter-gradle-plugin` di-apply di `app/build.gradle`.
- **Built-in Kotlin** (AGP 9.3.1 mengelola Kotlin): TIDAK apply `org.jetbrains.kotlin.android`; target JVM diatur via `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.
- `android/gradle.properties` di-commit dengan `org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError` + `android.useAndroidX=true`/`android.enableJetifier=true`.
- `android/local.properties` **tidak di-track** (generated; `flutter.sdk`/version diisi Flutter tool). Ada di `.gitignore`.
- Icon sementara memakai `@android:drawable/sym_def_app_icon` (placeholder sampai aset ikon asli dibuat).
- `setup-java@v4` di workflow **sebelum** `flutter-action` (Java 17 Temurin).

## Pengaturan Keamanan Vault (Tahap 4A — audit & abstraksi)
- **Field sensitif yang akan dienkripsi**: `VaultItem.password` (wajib), `VaultItem.notes` (opsional).
- **Titik akses yang harus di-audit**:
  - `VaultItem.fromMap()` / `toMap()` — deserialisasi/serialisasi.
  - `VaultProvider.addItem()` / `updateItem()` — harus enkripsi sebelum store.
  - `VaultProvider.loadItems()` — harus decrypt setelah ambil (Tahap 4B).
  - `VaultScreen` / `VaultEditorScreen` — tidak menyimpan password di UI/ternyata.
- **Kerangka (`lib/services/vault_encryption_service.dart`)**:
  - `VaultEncryptionService` — interface abstrak.
  - `NoOpEncryption` — implementasi identity (Tahap 4A).
  - `vaultEncryptionService` — singleton default.
- **Prasyarat Tahap 4B** (enkripsi produksi):
  1. Tambah dependency `encrypt` atau `cryptography` di `pubspec.yaml`.
  2. Implementasikan `VaultEncryptionService` dengan AES-256-GCM.
  3. Tambahkan master password / kunci utama pengguna (Keychain / Keystore).
  4. Naikkan `_dbVersion` ke **4** untuk migration (kolom `is_encrypted INTEGER` atau prefix enkripsi di `password`).
  5. Backup data sebelum migrasi bulk.

## Langkah Berikutnya (saat build sukses)
1. Unduh artifact APK dari Actions → `mylife-apk` (arm64-v8a).
2. Mulai implementasi fitur per modul: Notes → Finance → Vault → Settings.
3. Gunakan **Provider** untuk state management, **sqflite** untuk persistence.
4. Tulis test minimal untuk logika non-trivial (TDD ringan).

## Link Cepat
- Repo: https://github.com/YusuP28/mylife
- Actions: https://github.com/YusuP28/mylife/actions
- Build terkini: https://github.com/YusuP28/mylife/actions/runs/45367215117