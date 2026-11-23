import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/finance_transaction.dart';
import '../models/note.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'mylife.db';
  static const int _dbVersion = 2;

  static const String tableNotes = 'notes';
  static const String tableTransactions = 'transactions';

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
}