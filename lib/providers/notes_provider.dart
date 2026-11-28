import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../models/drawing_stroke.dart';
import '../models/template.dart';
import '../services/database_service.dart';

class NotesProvider extends ChangeNotifier {
  NotesProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<Note> _notes = <Note>[];
  List<Template> _templates = <Template>[];
  String _query = '';
  String _tagFilter = '';
  bool _loading = false;
  String? _error;

  List<Note> get notes => List<Note>.unmodifiable(_notes);
  List<Template> get templates => List<Template>.unmodifiable(_templates);
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
      final notes = await _service.getNotes();
      // Load drawing strokes for each note
      for (final note in notes) {
        final strokes = await _service.getDrawingStrokes(note.id!);
        // Note is immutable, we need to recreate with strokes
        final index = notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          notes[index] = note.copyWith(strokes: note.strokes);
        }
      }
      _notes = notes;
    } catch (e) {
      _error = 'Gagal memuat catatan: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadTemplates({String? category}) async {
    try {
      _templates = await _service.getTemplates(category: category);
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat template: $e';
      notifyListeners();
    }
  }

  Future<void> addNote({
    required String title,
    required String body,
    List<DrawingStroke> strokes = const [],
    String? templateId,
    String? fontFamily,
    String? backgroundId,
  }) async {
    final now = DateTime.now();
    await _service.insertNote(
      Note(
        title: title,
        body: body,
        createdAt: DateTime.now(),
        updatedAt: now,
        strokes: strokes,
        templateId: templateId,
        fontFamily: fontFamily,
        backgroundId: backgroundId,
      ),
    );
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await _service.updateNote(
      note.copyWith(updatedAt: DateTime.now()),
    );
    // Update drawing strokes if any
    if (note.strokes.isNotEmpty) {
      await _service.deleteDrawingStrokesForNote(note.id!);
      await _service.insertDrawingStrokes(note.strokes);
    }
    await loadNotes();
  }

  Future<void> saveDrawingStrokes(int noteId, List<DrawingStroke> strokes) async {
    await _service.deleteDrawingStrokesForNote(noteId);
    if (strokes.isNotEmpty) {
      await _service.insertDrawingStrokes(strokes);
    }
    await loadNotes();
  }

  // === Template Methods ===

  Future<void> addTemplate(Template template) async {
    await _service.insertTemplate(template);
    await loadTemplates();
  }

  Future<void> updateTemplate(Template template) async {
    await _service.updateTemplate(template);
    await loadTemplates();
  }

  Future<void> deleteTemplate(int id) async {
    await _service.deleteTemplate(id);
    await loadTemplates();
  }

  Future<void> createTemplateFromNote(Note note, {required String name, String category = 'custom'}) async {
    final template = Template(
      name: name,
      contentJson: note.toMap().toString(), // Simplified - in real app serialize properly
      category: category,
      isCustom: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await addTemplate(template);
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