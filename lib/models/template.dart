import 'dart:convert';

import 'package:flutter/material.dart';

/// Represents a note template with predefined content and styling.
class Template {
  const Template({
    this.id,
    required this.name,
    required this.contentJson,
    required this.category,
    this.thumbnail = '',
    this.isCustom = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String thumbnail; // Base64 encoded thumbnail image
  final String contentJson; // JSON serialized note content (text + drawing strokes)
  final String category; // e.g., 'meeting', 'diary', 'planning', 'drawing'
  final bool isCustom; // true = user created, false = built-in
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a copy with optional field overrides.
  Template copyWith({
    int? id,
    String? name,
    String? thumbnail,
    String? contentJson,
    String? category,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Template(
        id: id ?? this.id,
        name: name ?? this.name,
        thumbnail: thumbnail ?? this.thumbnail,
        contentJson: contentJson ?? this.contentJson,
        category: category ?? this.category,
        isCustom: isCustom ?? this.isCustom,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Serializes to a JSON-compatible map for database storage.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'thumbnail': thumbnail,
        'content_json': contentJson,
        'category': category,
        'is_custom': isCustom ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  /// Deserializes from a database row map.
  factory Template.fromMap(Map<String, Object?> map) => Template(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        thumbnail: map['thumbnail'] as String? ?? '',
        contentJson: map['content_json'] as String? ?? '',
        category: map['category'] as String? ?? '',
        isCustom: (map['is_custom'] as int? ?? 0) == 1,
        createdAt: _dateFrom(map['created_at']),
        updatedAt: _dateFrom(map['updated_at']),
      );

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Template &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          thumbnail == other.thumbnail &&
          contentJson == other.contentJson &&
          category == other.category &&
          isCustom == other.isCustom &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      thumbnail.hashCode ^
      contentJson.hashCode ^
      category.hashCode ^
      isCustom.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'Template(id: $id, name: $name, category: $category, isCustom: $isCustom)';
}

/// Built-in template categories
class TemplateCategory {
  static const String all = 'all';
  static const String meeting = 'meeting';
  static const String diary = 'diary';
  static const String planning = 'planning';
  static const String drawing = 'drawing';
  static const String education = 'education';
  static const String work = 'work';
  static const String personal = 'personal';

  static const List<String> allCategories = [
    all,
    meeting,
    diary,
    planning,
    drawing,
    education,
    work,
    personal,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case meeting:
        return 'Rapat';
      case diary:
        return 'Diary';
      case planning:
        return 'Perencanaan';
      case drawing:
        return 'Gambar';
      case education:
        return 'Pendidikan';
      case work:
        return 'Kerja';
      case personal:
        return 'Pribadi';
      default:
        return 'Semua';
    }
  }

  static IconData getIcon(String category) {
    switch (category) {
      case meeting:
        return Icons.meeting_room;
      case diary:
        return Icons.book;
      case planning:
        return Icons.calendar_today;
      case drawing:
        return Icons.brush;
      case education:
        return Icons.school;
      case work:
        return Icons.work;
      case personal:
        return Icons.person;
      default:
        return Icons.apps;
    }
  }

  /// Creates a template from a note.
  static Template fromNote(Note note, {
    required String name,
    String category = 'custom',
    String? thumbnail,
  }) {
    final content = {
      'title': note.title,
      'body': note.body,
      'strokes': note.strokes.map((s) => s.toMap()).toList(),
      'quillDelta': note.body.isNotEmpty 
          ? [
              {'insert': note.body}
            ] 
            : [],
      'fontFamily': note.fontFamily,
      'backgroundId': note.backgroundId,
    };

    return Template(
      name: name,
      contentJson: json.encode(content),
      category: category,
      isCustom: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      thumbnail: thumbnail ?? '',
    );
  }

  /// Updates template content from a note.
  Template updateFromNote(Note note) {
    final content = {
      'title': note.title,
      'body': note.body,
      'strokes': note.strokes.map((s) => s.toMap()).toList(),
      'quillDelta': note.body.isNotEmpty 
          ? [{'insert': note.body}] 
          : [],
      'fontFamily': note.fontFamily,
      'backgroundId': note.backgroundId,
    };

    return copyWith(
      contentJson: json.encode(content),
      updatedAt: DateTime.now(),
    );
  }
}