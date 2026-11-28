import 'package:flutter/material.dart';
import 'drawing_stroke.dart';

class Note {
  const Note({
    this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.strokes = const [],
    this.templateId,
    this.fontFamily,
    this.backgroundId,
  });

  final int? id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DrawingStroke> strokes;
  final String? templateId;
  final String? fontFamily;
  final String? backgroundId;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'strokes': _encodeStrokes(strokes),
        'template_id': templateId ?? '',
        'font_family': fontFamily ?? '',
        'background_id': backgroundId ?? '',
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, Object?> map) => Note(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: _dateFrom(map['created_at']),
        updatedAt: _dateFrom(map['updated_at']),
        strokes: _decodeStrokes(map['strokes'] as String? ?? ''),
        templateId: (map['template_id'] as String? ?? '').isEmpty ? null : map['template_id'] as String?,
        fontFamily: (map['font_family'] as String? ?? '').isEmpty ? null : map['font_family'] as String?,
        backgroundId: (map['background_id'] as String? ?? '').isEmpty ? null : map['background_id'] as String?,
      );

  Note copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DrawingStroke>? strokes,
    String? templateId,
    String? fontFamily,
    String? backgroundId,
  }) => Note(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        strokes: strokes ?? this.strokes,
        templateId: templateId ?? this.templateId,
        fontFamily: fontFamily ?? this.fontFamily,
        backgroundId: backgroundId ?? this.backgroundId,
      );

  static String _encodeStrokes(List<DrawingStroke> strokes) {
    return strokes.map((s) => s.toMap()).map((m) => _mapToJson(m)).join('|');
  }

  static String _mapToJson(Map<String, Object?> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static List<DrawingStroke> _decodeStrokes(String data) {
    if (data.isEmpty) return [];
    return data.split('|').map((s) {
      final map = <String, Object?>{};
      for (final pair in s.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          map[parts[0]] = parts[1];
        }
      }
      return DrawingStroke.fromMap(map);
    }).toList();
  }

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
