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
| Modul Catatan: `Note` + `DatabaseService` (sqflite) + `NotesProvider` + list/FAB + pencarian | ✅ Done |
| Android V2 embedding (MainActivity.kt, Manifest, styles, launch_background) | ✅ Done |
| Gradle 9.5.0 / AGP 9.3.1 / Built-in Kotlin 2.4.10 / Java 17 | ✅ Done |
| GitHub Actions workflow (Flutter 3.50.0, Java 17, cache Gradle) | ✅ Done |
| Repo GitHub: `YusuP28/mylife` (public) | ✅ Done |
**| **Build terakhir:** Run ID **45276708972** (success, artifact `mylife-apk`) | ✅ Green |** (success, artifact `mylife-apk`) | ✅ Green |** (success, artifact `mylife-apk`) | ✅ Green |

## Struktur Kunci
```
mylife/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  # entry: ChangeNotifierProvider > MaterialApp
│   ├── theme/
│   │   └── app_theme.dart         # tema terang bersih (Material 3)
│   ├── models/
│   │   └── note.dart              # entity Note + toMap/fromMap
│   ├── providers/
│   │   └── notes_provider.dart    # ChangeNotifier: load/add/update/delete
│   ├── services/
│   │   └── database_service.dart  # singleton sqflite, mylife.db, tabel notes
│   ├── widgets/
│   │   └── module_placeholder.dart # kartu placeholder modul
│   └── screens/
│       ├── home_shell.dart        # NavigationBar + IndexedStack
│       ├── notes/notes_screen.dart
│       ├── finance/finance_screen.dart
│       ├── vault/vault_screen.dart
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

## Perintah Rutin
```bash
# Cek status build
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
- **Arsitektur modul Catatan**: `Note` (model murni) → `DatabaseService` (singleton sqflite, `mylife.db`, tabel `notes` dengan `CREATE TABLE IF NOT EXISTS`, `_dbVersion = 1`, belum ada migrasi) → `NotesProvider` (`ChangeNotifier`) → UI. Provider didaftarkan di `main.dart` dan di-`loadNotes()` saat inisialisasi. Modul lain masih placeholder.
- **Arsitektur modul Keuangan (Tahap 1)**: `FinanceTransaction` (model) → `DatabaseService` (tabel `transactions` dengan `type`, `amount` INTEGER, `category`, `note`, `occurred_at`, `created_at`, `updated_at`; `_dbVersion = 2`, `onUpgrade` menambah tabel tanpa menyentuh `notes`). → `FinanceProvider` (`ChangeNotifier` + `balance`, `totalIncome`, `totalExpense`) → `main.dart` pakai `MultiProvider`. UI placeholder.**
- **Keuangan Tahap 2**: `FinanceScreen` menampilkan kartu ringkasan (saldo total, pemasukan, pengeluaran, format `NumberFormat.currency(id_ID)`), daftar transaksi (kategori, catatan, tanggal, nominal dengan indikator warna hijau-merah), state `loading`/`error`/`empty`. Tombol `+` diarahkan ke Tahap 3. Tidak ada aksi dummy: tap tile menampilkan SnackBar info tahap selanjutnya. `_dbVersion` tetap 2.**
- **Pencarian catatan**: `NotesProvider._query` + `setQuery()` + getter `visibleNotes` (filter in-memory judul/isi, case-insensitive). `Note.fromMap()` pakai fallback untuk field null/format lama agar baris lama tidak crash, tanpa ubah skema DB.
- **Editor catatan**: `NoteEditorScreen` (`lib/screens/notes/note_editor_screen.dart`) untuk buat (`note == null`) dan edit (`note` terisi) memakai `addNote`/`updateNote`. AppBar punya simpan (`✓`) + menu `⋮` (salin, bersihkan, hapus saat edit). Toolbar: undo/redo (`UndoHistoryController`), heading, bold, italic, bullet, checklist, kutipan, coret (`~~`), kode inline (`` ` ``), daftar angka (`1. `), toggle centang checklist (`- [ ]`/`- [x]`), garis pemisah (`---`), dan sisip tanggal (`id_ID`). Format disimpan sebagai marker teks ringan di kolom `body` (tanpa ubah skema). Ada guard perubahan belum disimpan saat keluar.
- **Kartu catatan**: bisa diketuk untuk membuka editor, menampilkan waktu terakhir diubah (`DateFormat` locale `id_ID`; inisialisasi di `main.dart`), preview dibersihkan dari marker (`_cleanPreview`), dan tombol hapus memakai dialog konfirmasi.
- **UI/navigasi**: `lib/screens/home_shell.dart` memakai `NavigationBar` (Material 3) + `IndexedStack` untuk 4 modul; tiap modul punya screen sendiri di `lib/screens/<modul>/` yang memakai `ModulePlaceholder` dari `lib/widgets/`.
- Tema terang bersih terpusat di `lib/theme/app_theme.dart` (`AppTheme.light`).
- `android/app/build.gradle` memakai **plugins DSL** (bukan `apply plugin:`).
- **Flutter Gradle plugin**: `settings.gradle` memakai `includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")` **di dalam** `pluginManagement {}`, lalu plugin `dev.flutter.flutter-plugin-loader` (v1.0.0) di-apply di settings dan `dev.flutter.flutter-gradle-plugin` di-apply di `app/build.gradle`.
- **Built-in Kotlin** (AGP 9.3.1 mengelola Kotlin): TIDAK apply `org.jetbrains.kotlin.android`; target JVM diatur via `kotlin { compilerOptions { jvmTarget = ...JVM_17 } }`.
- `android/gradle.properties` di-commit dengan `org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError` (cegah OOM `lintVitalAnalyzeRelease`) + `android.useAndroidX=true`/`android.enableJetifier=true`.
- `android/local.properties` **tidak di-track** (generated; `flutter.sdk`/version diisi Flutter tool). Ada di `.gitignore`.
- Icon sementara memakai `@android:drawable/sym_def_app_icon` (placeholder sampai aset ikon asli dibuat).
- `setup-java@v4` di workflow **sebelum** `flutter-action` (Java 17 Temurin).

## Langkah Berikutnya (saat build sukses)
1. Unduh artifact APK dari Actions → `mylife-apk` (arm64-v8a).
2. Mulai implementasi fitur per modul: Notes → Finance → Vault → Settings.
3. Gunakan **Provider** untuk state management, **sqflite** untuk persistence.
4. Tulis test minimal untuk logika non-trivial (TDD ringan).

## Link Cepat
- Repo: https://github.com/YusuP28/mylife
- Actions: https://github.com/YusuP28/mylife/actions
- Build terkini: https://github.com/YusuP28/mylife/actions/runs/45276708972