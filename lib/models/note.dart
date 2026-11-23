class Note {
  const Note({
    this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, Object?> map) => Note(
        id: map['id'] as int?,
        title: map['title']! as String,
        body: map['body'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      );
}
