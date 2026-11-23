import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  /// null = buat catatan baru, non-null = edit catatan.
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<NotesProvider>();
      final existing = widget.note;

      if (existing == null) {
        await provider.addNote(title: title, body: body);
      } else {
        await provider.updateNote(
          Note(
            id: existing.id,
            title: title,
            body: body,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan catatan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.note;

    return Scaffold(
      appBar: AppBar(
        title: Text(note == null ? 'Catatan baru' : 'Edit catatan'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Judul',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              minLines: 6,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Isi',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (note != null)
              Text(
                'Dibuat ${DateFormat.yMMMd('id_ID').add_jm().format(note.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
