import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance_transaction.dart';
import '../models/note.dart';
import '../models/vault_item.dart';
import '../models/drawing_stroke.dart';
import '../models/template.dart';
import 'vault_encryption_service.dart';
import 'vault_row_codec.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'mylife.db';
  static const int _dbVersion = 5;

  static const String tableNotes = 'notes';
  static const String tableTransactions = 'transactions';
  static const String tableVaultItems = 'vault_items';
  static const String tableDrawingStrokes = 'drawing_strokes';
  static const String tableTemplates = 'templates';

  /// Default [NoOpEncryption]: belum ada enkripsi sampai vault dibuka
  /// (Tahap 4B-4 mengisi ini lewat [vaultEncryption]).
  VaultEncryptionService _vaultEncryption = vaultEncryptionService;

  VaultRowCodec get _vaultCodec => VaultRowCodec(_vaultEncryption);

  /// Pasang cipher aktif. Dipanggil setelah kunci sesi tersedia.
  set vaultEncryption(VaultEncryptionService service) {
    _vaultEncryption = service;
  }

  /// Dipakai di `onCreate` dan `onUpgrade` (aman dipanggil berulang).
  static const String _createVaultItemsSql =
      'CREATE TABLE IF NOT EXISTS $tableVaultItems ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'title TEXT NOT NULL, '
      'username TEXT NOT NULL DEFAULT \'\', '
      'password TEXT NOT NULL DEFAULT \'\', '
      'url TEXT NOT NULL DEFAULT \'\', '
      'notes TEXT NOT NULL DEFAULT \'\', '
      'totp_uri TEXT NOT NULL DEFAULT \'\', '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)';

  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final opened = await openDatabase(
      '${dir.path}/$_dbName',
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $tableNotes ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT NOT NULL, '
          'body TEXT NOT NULL DEFAULT \'\', '
          'strokes TEXT NOT NULL DEFAULT \'\', '
          'template_id TEXT NOT NULL DEFAULT \'\', '
          'font_family TEXT NOT NULL DEFAULT \'\', '
          'background_id TEXT NOT NULL DEFAULT \'\', '
          'created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE $tableTransactions ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'type TEXT NOT NULL CHECK(type IN (\'income\', \'expense\')), '
          'amount INTEGER NOT NULL, '
          'category TEXT NOT NULL DEFAULT \'\', '
          'note TEXT NOT NULL DEFAULT \'\', '
          'occurred_at INTEGER NOT NULL, '
          'created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL)',
        );
        await db.execute(_createVaultItemsSql);
        await db.execute(
          'CREATE TABLE $tableDrawingStrokes ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'note_id INTEGER NOT NULL, '
          'stroke_data TEXT NOT NULL, '
          'color INTEGER NOT NULL, '
          'width REAL NOT NULL, '
          'created_at INTEGER NOT NULL, '
          'FOREIGN KEY(note_id) REFERENCES $tableNotes(id) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE $tableTemplates ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, '
          'thumbnail TEXT NOT NULL DEFAULT \'\', '
          'content_json TEXT NOT NULL, '
          'category TEXT NOT NULL DEFAULT \'\', '
          'is_custom INTEGER NOT NULL DEFAULT 0, '
          'created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX idx_drawing_strokes_note_id ON $tableDrawingStrokes(note_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE $tableTransactions ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'type TEXT NOT NULL CHECK(type IN (\'income\', \'expense\')), '
            'amount INTEGER NOT NULL, '
            'category TEXT NOT NULL DEFAULT \'\', '
            'note TEXT NOT NULL DEFAULT \'\', '
            'occurred_at INTEGER NOT NULL, '
            'created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(_createVaultItemsSql);
        }
        if (oldVersion < 4) {
          // Add totp_uri column to existing vault_items table
          await db.execute('ALTER TABLE $tableVaultItems ADD COLUMN totp_uri TEXT NOT NULL DEFAULT \'\'');
        }
        if (oldVersion < 5) {
          // Add new columns to notes table
          await db.execute('ALTER TABLE $tableNotes ADD COLUMN strokes TEXT NOT NULL DEFAULT \'\'');
          await db.execute('ALTER TABLE $tableNotes ADD COLUMN template_id TEXT NOT NULL DEFAULT \'\'');
          await db.execute('ALTER TABLE $tableNotes ADD COLUMN font_family TEXT NOT NULL DEFAULT \'\'');
          await db.execute('ALTER TABLE $tableNotes ADD COLUMN background_id TEXT NOT NULL DEFAULT \'\'');
          
          // Create drawing_strokes table
          await db.execute(
            'CREATE TABLE $tableDrawingStrokes ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'note_id INTEGER NOT NULL, '
            'stroke_data TEXT NOT NULL, '
            'color INTEGER NOT NULL, '
            'width REAL NOT NULL, '
            'created_at INTEGER NOT NULL, '
            'FOREIGN KEY(note_id) REFERENCES $tableNotes(id) ON DELETE CASCADE)',
          );
          await db.execute(
            'CREATE INDEX idx_drawing_strokes_note_id ON $tableDrawingStrokes(note_id)',
          );
          
          // Create templates table
          await db.execute(
            'CREATE TABLE $tableTemplates ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'thumbnail TEXT NOT NULL DEFAULT \'\', '
            'content_json TEXT NOT NULL, '
            'category TEXT NOT NULL DEFAULT \'\', '
            'is_custom INTEGER NOT NULL DEFAULT 0, '
            'created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          );
        }
      },
    );
    _database = opened;
    return opened;
  }

  // === Notes API (unchanged, data-safe) ===

  Future<List<Note>> getNotes() async {
    final db = await database;
    final rows = await db.query(tableNotes, orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList(growable: false);
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert(tableNotes, note.toMap());
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(
      tableNotes,
      note.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(
      tableNotes,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Menghapus SEMUA catatan (untuk reset data).
  Future<void> clearNotes() async {
    final db = await database;
    await db.delete(tableNotes);
  }

  // === Finance API ===

  Future<List<FinanceTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? category,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object?>[];

    if (from != null) {
      filters.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      filters.add('occurred_at <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (category != null && category.isNotEmpty) {
      filters.add('category = ?');
      args.add(category);
    }

    final where = filters.isNotEmpty ? '${filters.join(' AND ')}' : null;
    final rows = await db.query(
      tableTransactions,
      orderBy: 'occurred_at DESC',
      where: where,
      whereArgs: args,
    );
    return rows.map(FinanceTransaction.fromMap).toList(growable: false);
  }

  Future<int> insertTransaction(FinanceTransaction tx) async {
    final db = await database;
    return db.insert(tableTransactions, tx.toMap());
  }

  Future<int> updateTransaction(FinanceTransaction tx) async {
    final db = await database;
    return db.update(
      tableTransactions,
      tx.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[tx.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Menghapus SEMUA transaksi (untuk reset data).
  Future<void> clearTransactions() async {
    final db = await database;
    await db.delete(tableTransactions);
  }

  Future<double> calculateBalance({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object?>[];

    if (from != null) {
      filters.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      filters.add('occurred_at <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final where = filters.isNotEmpty ? '${filters.join(' AND ')}' : null;
    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableTransactions '
      'WHERE type = \'income\' ${where != null ? 'AND $where' : ''}',
      args,
    );
    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableTransactions '
      'WHERE type = \'expense\' ${where != null ? 'AND $where' : ''}',
      args,
    );

    final income = (incomeResult.first['total'] as int).toDouble();
    final expense = (expenseResult.first['total'] as int).toDouble();
    return income - expense;
  }

  // === Vault API ===

  Future<List<VaultItem>> getVaultItems() async {
    final db = await database;
    final rows = await db.query(tableVaultItems, orderBy: 'updated_at DESC');
    final codec = _vaultCodec;
    final items = <VaultItem>[];
    for (final row in rows) {
      items.add(VaultItem.fromMap(await codec.decryptRow(row)));
    }
    return List<VaultItem>.unmodifiable(items);
  }

  Future<int> insertVaultItem(VaultItem item) async {
    final db = await database;
    final values = await _vaultCodec.encryptRow(item.toMap());
    return db.insert(tableVaultItems, values);
  }

  Future<int> updateVaultItem(VaultItem item) async {
    final db = await database;
    return db.update(
      tableVaultItems,
      await _vaultCodec.encryptRow(item.toMap()),
      where: 'id = ?',
      whereArgs: <Object?>[item.id],
    );
  }

  /// Mengenkripsi baris lama yang masih plaintext, sekali jalan, dalam satu
  /// transaksi. Tidak mengubah skema dan tidak menaikkan `_dbVersion`.
  ///
  /// Mengembalikan jumlah baris yang dimigrasi. `0` bila cipher masih NoOp.
  Future<int> migrateVaultItems() async {
    final codec = _vaultCodec;
    if (!codec.encryptsData) return 0;

    final db = await database;
    var migrated = 0;

    await db.transaction((txn) async {
      final rows = await txn.query(tableVaultItems);
      for (final row in rows) {
        if (!codec.rowNeedsMigration(row)) continue;

        final id = row['id'];
        if (id is! int) continue;

        final values = Map<String, Object?>.of(await codec.encryptRow(row))
          ..remove('id');
        await txn.update(
          tableVaultItems,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        migrated++;
      }
    });

    return migrated;
  }

  /// Mengenkripsi ulang semua field sensitif dengan cipher baru dalam satu
  /// transaksi. Dipakai saat ganti password: bila gagal di tengah jalan,
  /// seluruh perubahan di-rollback sehingga tidak ada campuran kunci.
  ///
  /// `from` harus cipher yang sedang aktif; `to` cipher dengan kunci baru.
  Future<int> reencryptVaultItems({
    required VaultEncryptionService from,
    required VaultEncryptionService to,
  }) async {
    if (!from.encryptsData || !to.encryptsData) {
      throw ArgumentError('Kedua cipher harus aktif untuk re-enkripsi');
    }

    final fromCodec = VaultRowCodec(from);
    final toCodec = VaultRowCodec(to);
    final db = await database;
    var changed = 0;

    await db.transaction((txn) async {
      final rows = await txn.query(tableVaultItems);
      for (final row in rows) {
        final id = row['id'];
        if (id is! int) continue;

        final plain = await fromCodec.decryptRow(row);
        final values = Map<String, Object?>.of(await toCodec.encryptRow(plain))
          ..remove('id');
        await txn.update(
          tableVaultItems,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        changed++;
      }
    });

    return changed;
  }

  Future<int> deleteVaultItem(int id) async {
    final db = await database;
    return db.delete(
      tableVaultItems,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Menghapus SEMUA item brankas (untuk reset data).
  Future<void> clearVaultItems() async {
    final db = await database;
    await db.delete(tableVaultItems);
  }

  // === Drawing Strokes API ===

  Future<List<DrawingStroke>> getDrawingStrokes(int noteId) async {
    final db = await database;
    final rows = await db.query(
      tableDrawingStrokes,
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DrawingStroke.fromMap).toList(growable: false);
  }

  Future<int> insertDrawingStroke(DrawingStroke stroke) async {
    final db = await database;
    return db.insert(tableDrawingStrokes, stroke.toMap());
  }

  Future<int> insertDrawingStrokes(List<DrawingStroke> strokes) async {
    if (strokes.isEmpty) return 0;
    final db = await database;
    var count = 0;
    await db.transaction((txn) async {
      for (final stroke in strokes) {
        await txn.insert(tableDrawingStrokes, stroke.toMap());
        count++;
      }
    });
    return count;
  }

  Future<int> deleteDrawingStrokesForNote(int noteId) async {
    final db = await database;
    return db.delete(
      tableDrawingStrokes,
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  // === Templates API ===

  Future<List<Template>> getTemplates({String? category}) async {
    final db = await database;
    final where = category != null && category.isNotEmpty ? 'category = ?' : null;
    final whereArgs = category != null && category.isNotEmpty ? [category] : null;
    final rows = await db.query(
      tableTemplates,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Template.fromMap).toList(growable: false);
  }

  Future<int> insertTemplate(Template template) async {
    final db = await database;
    return db.insert(tableTemplates, template.toMap());
  }

  Future<int> updateTemplate(Template template) async {
    final db = await database;
    return db.update(
      tableTemplates,
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return db.delete(
      tableTemplates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertTemplates(List<Template> templates) async {
    if (templates.isEmpty) return 0;
    final db = await database;
    var count = 0;
    await db.transaction((txn) async {
      for (final template in templates) {
        await txn.insert(tableTemplates, template.toMap());
        count++;
      }
    });
    return count;
  }
}