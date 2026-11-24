import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/database_service.dart';

class NotesProvider extends ChangeNotifier {
  NotesProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<Note> _notes = <Note>[];
  String _query = '';
  bool _loading = false;
  String? _error;

  List<Note> get notes => List<Note>.unmodifiable(_notes);

  List<Note> get visibleNotes {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return notes;

    return _notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(keyword) ||
              note.body.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
  }

  String get query => _query;
  bool get loading => _loading;
  String? get error => _error;

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
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
