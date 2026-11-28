import 'package:flutter/material.dart';

/// Represents a single drawing stroke with points, color, and width.
class DrawingStroke {
  const DrawingStroke({
    this.id,
    required this.noteId,
    required this.points,
    required this.color,
    required this.width,
    required this.createdAt,
  });

  final int? id;
  final int noteId;
  final List<Offset> points;
  final Color color;
  final double width;
  final DateTime createdAt;

  /// Creates a copy with optional field overrides.
  DrawingStroke copyWith({
    int? id,
    int? noteId,
    List<Offset>? points,
    Color? color,
    double? width,
    DateTime? createdAt,
  }) => DrawingStroke(
        id: id ?? this.id,
        noteId: noteId ?? this.noteId,
        points: points ?? this.points,
        color: color ?? this.color,
        width: width ?? this.width,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Serializes to a JSON-compatible map for database storage.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'note_id': noteId,
        'stroke_data': _encodePoints(points),
        'color': color.value,
        'width': width,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  /// Deserializes from a database row map.
  factory DrawingStroke.fromMap(Map<String, Object?> map) => DrawingStroke(
        id: map['id'] as int?,
        noteId: map['note_id'] as int? ?? 0,
        points: _decodePoints(map['stroke_data'] as String? ?? ''),
        color: Color(map['color'] as int? ?? Colors.black.value),
        width: (map['width'] as num?)?.toDouble() ?? 2.0,
        createdAt: _dateFrom(map['created_at']),
      );

  /// Encodes a list of Offsets to a JSON string.
  static String _encodePoints(List<Offset> points) {
    return points
        .map((p) => '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}')
        .join(';');
  }

  /// Decodes a JSON string back to a list of Offsets.
  static List<Offset> _decodePoints(String data) {
    if (data.isEmpty) return [];
    return data.split(';').map((pair) {
      final parts = pair.split(',');
      if (parts.length != 2) return Offset.zero;
      return Offset(
        double.tryParse(parts[0]) ?? 0.0,
        double.tryParse(parts[1]) ?? 0.0,
      );
    }).toList(growable: false);
  }

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingStroke &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          noteId == other.noteId &&
          points == other.points &&
          color == other.color &&
          width == other.width &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      noteId.hashCode ^
      points.hashCode ^
      color.hashCode ^
      width.hashCode ^
      createdAt.hashCode;

  @override
  String toString() =>
      'DrawingStroke(id: $id, noteId: $noteId, points: ${points.length}, color: $color, width: $width)';
}