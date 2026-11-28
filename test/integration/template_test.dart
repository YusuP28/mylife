import 'package:flutter_test/flutter_test.dart';

import 'package:mylife/models/template.dart';
import 'package:mylife/models/note.dart';
import 'package:mylife/models/drawing_stroke.dart';

void main() {
  group('Template', () {
    test('TemplateCategory allCategories contains expected categories', () {
      expect(TemplateCategory.allCategories.contains(TemplateCategory.meeting), true);
      expect(TemplateCategory.allCategories.contains(TemplateCategory.diary), true);
      expect(TemplateCategory.allCategories.contains(TemplateCategory.planning), true);
      expect(TemplateCategory.allCategories.contains(TemplateCategory.drawing), true);
    });

    test('TemplateCategory getDisplayName returns correct Indonesian names', () {
      expect(TemplateCategory.getDisplayName(TemplateCategory.meeting), 'Rapat');
      expect(TemplateCategory.getDisplayName(TemplateCategory.diary), 'Diary');
      expect(TemplateCategory.getDisplayName(TemplateCategory.planning), 'Perencanaan');
      expect(TemplateCategory.getDisplayName(TemplateCategory.drawing), 'Gambar');
    });

    test('TemplateCategory getIcon returns correct icons', () {
      expect(TemplateCategory.getIcon(TemplateCategory.meeting), Icons.meeting_room);
      expect(TemplateCategory.getIcon(TemplateCategory.diary), Icons.book);
    });

    test('Template copyWith works correctly', () {
      const template = Template(
        id: 1,
        name: 'Test Template',
        category: TemplateCategory.meeting,
        isCustom: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final copied = template.copyWith(name: 'Updated Template');

      expect(copied.id, 1);
      expect(copied.name, 'Updated Template');
      expect(copied.category, TemplateCategory.meeting);
      expect(copied.isCustom, false);
    });

    test('Template fromMap and toMap roundtrip', () {
      const now = DateTime(2026, 1, 1);
      final template = Template(
        id: 42,
        name: 'Meeting Template',
        thumbnail: 'base64data',
        contentJson: '{"title": "Meeting"}',
        category: TemplateCategory.meeting,
        isCustom: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = template.toMap();
      final restored = Template.fromMap(map);

      expect(restored.id, template.id);
      expect(restored.name, template.name);
      expect(restored.thumbnail, template.thumbnail);
      expect(restored.contentJson, template.contentJson);
      expect(restored.category, template.category);
      expect(restored.isCustom, template.isCustom);
      expect(restored.createdAt, template.createdAt);
      expect(restored.updatedAt, template.updatedAt);
    });

    test('Template copyWith preserves all fields when not specified', () {
      const template = Template(
        id: 1,
        name: 'Test',
        category: 'meeting',
        isCustom: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final copied = template.copyWith();

      expect(copied, template);
    });
  });

  group('Note with new fields', () {
    test('Note copyWith preserves new fields', () {
      final note = Note(
        id: 1,
        title: 'Test',
        body: 'Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        strokes: [],
        templateId: 'template1',
        fontFamily: 'Roboto',
        backgroundId: 'bg1',
      );

      final copied = note.copyWith(title: 'Updated');

      expect(copied.title, 'Updated');
      expect(copied.strokes, isEmpty);
      expect(copied.templateId, 'template1');
      expect(copied.fontFamily, 'Roboto');
      expect(copied.backgroundId, 'bg1');
    });

    test('Note toMap and fromMap roundtrip with new fields', () {
      final now = DateTime.now();
      final note = Note(
        id: 42,
        title: 'Test Note',
        body: 'Body content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        strokes: [],
        templateId: 'tmpl1',
        fontFamily: 'Roboto',
        backgroundId: 'bg_dark',
      );

      final map = note.toMap();
      final restored = Note.fromMap(map);

      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.body, note.body);
      expect(restored.templateId, note.templateId);
      expect(restored.fontFamily, note.fontFamily);
      expect(restored.backgroundId, note.backgroundId);
      expect(restored.createdAt, note.createdAt);
      expect(restored.updatedAt, note.updatedAt);
    });
  });

  group('DrawingStroke', () {
    test('DrawingStroke fromMap and toMap roundtrip', () {
      final now = DateTime.now();
      final stroke = DrawingStroke(
        id: 1,
        noteId: 42,
        points: [Offset(10, 10), Offset(20, 20)],
        color: Colors.red,
        width: 3.0,
        createdAt: now,
      );

      final map = stroke.toMap();
      final restored = DrawingStroke.fromMap(map);

      expect(restored.id, stroke.id);
      expect(restored.noteId, stroke.noteId);
      expect(restored.color, stroke.color);
      expect(restored.width, stroke.width);
      expect(restored.createdAt, stroke.createdAt);
    });

    test('DrawingStroke _encodePoints and _decodePoints roundtrip', () {
      final points = [
        Offset(10.5, 20.3),
        Offset(30.7, 40.8),
        Offset(50.1, 60.9),
      ];

      final encoded = DrawingStroke._encodePoints(points);
      final decoded = DrawingStroke._decodePoints(encoded);

      expect(decoded.length, points.length);
      for (int i = 0; i < points.length; i++) {
        expect(decoded[i].dx, closeTo(points[i].dx, 0.01));
        expect(decoded[i].dy, closeTo(points[i].dy, 0.01));
      }
    });

    test('DrawingStroke copyWith works correctly', () {
      final stroke = DrawingStroke(
        id: 1,
        noteId: 1,
        points: [Offset(0, 0)],
        color: Colors.red,
        width: 2.0,
        createdAt: DateTime.now(),
      );

      final copied = stroke.copyWith(color: Colors.blue, width: 5.0);

      expect(copied.color, Colors.blue);
      expect(copied.width, 5.0);
      expect(copied.points, stroke.points);
      expect(copied.noteId, stroke.noteId);
    });
  });

  group('TemplateCategory', () {
    test('allCategories contains all expected categories', () {
      expect(TemplateCategory.allCategories.length, 8);
      expect(TemplateCategory.allCategories, contains(TemplateCategory.all));
      expect(TemplateCategory.allCategories, contains(TemplateCategory.meeting));
      expect(TemplateCategory.allCategories, contains(TemplateCategory.diary));
    });

    test('getDisplayName returns correct Indonesian names', () {
      expect(TemplateCategory.getDisplayName(TemplateCategory.meeting), 'Rapat');
      expect(TemplateCategory.getDisplayName(TemplateCategory.diary), 'Diary');
      expect(TemplateCategory.getDisplayName(TemplateCategory.planning), 'Perencanaan');
      expect(TemplateCategory.getDisplayName(TemplateCategory.drawing), 'Gambar');
      expect(TemplateCategory.getDisplayName(TemplateCategory.education), 'Pendidikan');
      expect(TemplateCategory.getDisplayName(TemplateCategory.work), 'Kerja');
      expect(TemplateCategory.getDisplayName(TemplateCategory.personal), 'Pribadi');
    });

    test('getIcon returns correct icons', () {
      expect(TemplateCategory.getIcon(TemplateCategory.meeting), Icons.meeting_room);
      expect(TemplateCategory.getIcon(TemplateCategory.diary), Icons.book);
      expect(TemplateCategory.getIcon(TemplateCategory.drawing), Icons.brush);
    });
  });