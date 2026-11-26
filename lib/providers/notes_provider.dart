import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/database_service.dart';

class NotesProvider extends ChangeNotifier {
  NotesProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<Note> _notes = <Note>[];
  String _query = '';
  String _tagFilter = '';
  bool _loading = false;
  String? _error;

  List<Note> get notes => List<Note>.unmodifiable(_notes);
  String get query => _query;
  String get tagFilter => _tagFilter;
  bool get loading => _loading;
  String? get error => _error;

  List<Note> get visibleNotes {
    final allNotes = _notes;
    final tagKeyword = _tagFilter.trim().toLowerCase();
    final searchKeyword = _query.trim().toLowerCase();

    // Filter gabungan tag + pencarian
    if (tagKeyword.isNotEmpty && searchKeyword.isNotEmpty) {
      return allNotes.where((n) {
        final byTag = n.body.toLowerCase().contains('#tag:$tagKeyword');
        final byQuery =
            n.title.toLowerCase().contains(searchKeyword) ||
                n.body.toLowerCase().contains(searchKeyword);
        return byTag && byQuery;
      }).toList();
    }

    // Filter hanya tag
    if (tagKeyword.isNotEmpty) {
      return allNotes
          .where((n) => n.body.toLowerCase().contains('#tag:$tagKeyword'))
          .toList();
    }

    // Filter hanya pencarian (existing)
    if (searchKeyword.isNotEmpty) {
      return allNotes
          .where((note) =>
              note.title.toLowerCase().contains(searchKeyword) ||
              note.body.toLowerCase().contains(searchKeyword))
          .toList();
    }

    return List<Note>.unmodifiable(allNotes);
  }

  /// Ekstrak semua tag unik dari semua catatan.
  List<String> get tags {
    final tagPattern = RegExp(r'#tag:(\w+)', multiLine: true);
    final Set<String> tagSet = {};
    for (final note in _notes) {
      for (final match in tagPattern.allMatches(note.body)) {
        if (match.groupCount >= 1) {
          tagSet.add(match.group(1)!.toLowerCase());
        }
      }
    }
    final result = tagSet.toList();
    result.sort();
    return result;
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setTagFilter(String value) {
    if (_tagFilter == value) return;
    _tagFilter = value;
    notifyListeners();
  }

  void clearTagFilter() {
    if (_tagFilter.isEmpty) return;
    _tagFilter = '';
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _notes = await _service.getNotes();
    } catch (e) {
      _error = 'Gagal memuat catatan: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addNote({required String title, required String body}) async {
    final now = DateTime.now();
    await _service.insertNote(
      Note(title: title, body: body, createdAt: now, updatedAt: now),
    );
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await _service.updateNote(
      Note(
        id: note.id,
        title: note.title,
        body: note.body,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    await loadNotes();
  }

  Future<void> deleteNote(int id) async {
    await _service.deleteNote(id);
    await loadNotes();
  }

  /// Menghapus SEMUA catatan (reset data).
  Future<void> clearAllNotes() async {
    await _service.clearNotes();
    await loadNotes();
  }
}