import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';

enum _EditorMenuAction { copy, clear, delete }

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  /// null = buat catatan baru, non-null = edit catatan.
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const List<String> _linePrefixes = <String>['- [ ] ', '- ', '> ', '# '];

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final UndoHistoryController _undoController = UndoHistoryController();

  late final String _initialTitle;
  late final String _initialBody;
  bool _saving = false;

  bool get _isEditing => widget.note != null;

  bool get _hasChanges =>
      _titleController.text != _initialTitle ||
      _bodyController.text != _initialBody;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.note?.title ?? '';
    _initialBody = widget.note?.body ?? '';
    _titleController = TextEditingController(text: _initialTitle);
    _bodyController = TextEditingController(text: _initialBody);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  int _lineStartOf(String text, int cursor) {
    if (cursor <= 0) return 0;
    final index = text.lastIndexOf('\n', cursor - 1);
    return index == -1 ? 0 : index + 1;
  }

  int _lineEndOf(String text, int cursor) {
    final index = text.indexOf('\n', cursor);
    return index == -1 ? text.length : index;
  }

  void _toggleLinePrefix(String prefix) {
    final value = _bodyController.value;
    final text = value.text;
    final cursor = value.selection.isValid
        ? value.selection.start
        : text.length;
    final lineStart = _lineStartOf(text, cursor);
    final lineEnd = _lineEndOf(text, cursor);
    final line = text.substring(lineStart, lineEnd);

    String newLine;
    if (line.startsWith(prefix)) {
      newLine = line.substring(prefix.length);
    } else {
      var stripped = line;
      for (final marker in _linePrefixes) {
        if (stripped.startsWith(marker)) {
          stripped = stripped.substring(marker.length);
          break;
        }
      }
      newLine = '$prefix$stripped';
    }

    final updated = text.replaceRange(lineStart, lineEnd, newLine);
    _bodyController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
  }

  void _wrapSelection(String marker) {
    final value = _bodyController.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      final updated = text.replaceRange(
        selection.start,
        selection.start,
        '$marker$marker',
      );
      _bodyController.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(
          offset: selection.start + marker.length,
        ),
      );
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final updated = text.replaceRange(
      selection.start,
      selection.end,
      '$marker$selected$marker',
    );
    _bodyController.value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: selection.start + marker.length,
        extentOffset: selection.end + marker.length,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut mengedit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (_hasChanges) {
      final discard = await _confirmDiscard();
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
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

  Future<void> _copyToClipboard() async {
    final text =
        '${_titleController.text.trim()}\n\n${_bodyController.text.trim()}'
            .trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Catatan disalin ke clipboard')),
    );
  }

  Future<void> _clearBody() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bersihkan isi'),
        content: const Text('Hapus seluruh isi catatan?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _bodyController.clear();
    }
  }

  Future<void> _deleteNote() async {
    final note = widget.note;
    final id = note?.id;
    if (note == null || id == null) return;

    final provider = context.read<NotesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan'),
        content: Text('Hapus "${note.title}"? Tindakan ini tidak bisa dibatalkan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await provider.deleteNote(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onMenuSelected(_EditorMenuAction action) async {
    switch (action) {
      case _EditorMenuAction.copy:
        await _copyToClipboard();
      case _EditorMenuAction.clear:
        await _clearBody();
      case _EditorMenuAction.delete:
        await _deleteNote();
    }
  }

  Widget _toolButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: <Widget>[
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _undoController,
            builder: (context, value, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _toolButton(
                  Icons.undo,
                  'Urungkan',
                  value.canUndo ? _undoController.undo : null,
                ),
                _toolButton(
                  Icons.redo,
                  'Ulangi',
                  value.canRedo ? _undoController.redo : null,
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          _toolButton(
            Icons.title,
            'Heading',
            () => _toggleLinePrefix('# '),
          ),
          _toolButton(
            Icons.format_bold,
            'Tebal',
            () => _wrapSelection('**'),
          ),
          _toolButton(
            Icons.format_italic,
            'Miring',
            () => _wrapSelection('*'),
          ),
          _toolButton(
            Icons.format_list_bulleted,
            'Daftar',
            () => _toggleLinePrefix('- '),
          ),
          _toolButton(
            Icons.checklist,
            'Checklist',
            () => _toggleLinePrefix('- [ ] '),
          ),
          _toolButton(
            Icons.format_quote,
            'Kutipan',
            () => _toggleLinePrefix('> '),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.note;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _handleBack),
          title: Text(_isEditing ? 'Edit catatan' : 'Catatan baru'),
          actions: <Widget>[
            IconButton(
              onPressed: _saving ? null : _save,
              tooltip: 'Simpan',
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
            ),
            PopupMenuButton<_EditorMenuAction>(
              tooltip: 'Menu lainnya',
              onSelected: _onMenuSelected,
              itemBuilder: (context) => <PopupMenuEntry<_EditorMenuAction>>[
                const PopupMenuItem<_EditorMenuAction>(
                  value: _EditorMenuAction.copy,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Salin catatan'),
                  ),
                ),
                const PopupMenuItem<_EditorMenuAction>(
                  value: _EditorMenuAction.clear,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.cleaning_services_outlined),
                    title: Text('Bersihkan isi'),
                  ),
                ),
                if (_isEditing)
                  const PopupMenuItem<_EditorMenuAction>(
                    value: _EditorMenuAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Hapus catatan'),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Judul catatan',
                  ),
                ),
              ),
              const Divider(height: 16),
              _buildToolbar(),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _bodyController,
                    undoController: _undoController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Tulis catatan di sini...',
                    ),
                  ),
                ),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Dibuat ${DateFormat.yMMMd('id_ID').add_jm().format(note.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
