import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
  }

  Future<void> _confirmDelete(Note note) async {
    final id = note.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan'),
        content: Text(
          'Hapus "${note.title}"? Tindakan ini tidak bisa dibatalkan.',
        ),
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

    if (confirmed != true || !mounted) return;
    await context.read<NotesProvider>().deleteNote(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotesProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Tambah catatan',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          if (state.error != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: state.setQuery,
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          state.setQuery('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(NotesProvider state, ThemeData theme) {
    final notes = state.visibleNotes;

    if (state.loading && notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notes.isEmpty) {
      if (state.query.trim().isNotEmpty) {
        return _NoResults(query: state.query.trim());
      }
      return _EmptyState(onAdd: () => _openEditor());
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteTile(
          note: note,
          onTap: () => _openEditor(note),
          onDelete: () => _confirmDelete(note),
        );
      },
    );
  }
}

String _cleanPreview(String body) {
  return body
      // garis pemisah --- / *** / ___
      .replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '')
      // checklist sebelum bullet
      .replaceAll(RegExp(r'^\s*-\s+\[[ xX]\]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '')
      // daftar angka
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      // kutipan
      .replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '')
      // heading
      .replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '')
      // coret, tebal, miring
      .replaceAll('~~', '')
      .replaceAll('**', '')
      .replaceAll('*', '')
      // kode inline
      .replaceAll('`', '')
      // rapatkan baris kosong berlebih
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _cleanPreview(note.body);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Diubah ${DateFormat.yMMMd('id_ID').add_jm().format(note.updatedAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                tooltip: 'Hapus',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('Tidak ada hasil', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tidak ditemukan catatan untuk "$query".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.sticky_note_2_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Belum ada catatan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol + untuk menambah catatan pertama.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah catatan'),
          ),
        ],
      ),
    );
  }
}
