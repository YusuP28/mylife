import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'mylife.db';
  static const int _dbVersion = 1;
  static const String tableNotes = 'notes';

  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final opened = await openDatabase(
      '${dir.path}/$_dbName',
      version: _dbVersion,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE $tableNotes ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'title TEXT NOT NULL, '
        'body TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      ),
    );
    _database = opened;
    return opened;
  }

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
}
