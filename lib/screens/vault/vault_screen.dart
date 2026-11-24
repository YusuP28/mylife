import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/vault_item.dart';
import '../../providers/vault_provider.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final TextEditingController _searchController;
  final Map<int, bool> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VaultProvider>().loadItems();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility(int id) {
    setState(() {
      _visiblePasswords[id] = !(_visiblePasswords[id] ?? false);
    });
  }

  void _openEditor([VaultItem? item]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VaultEditorScreen(item: item),
      ),
    );
  }

  Future<void> _confirmDelete(VaultItem item) async {
    final id = item.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus brankas'),
        content: Text('Hapus "${item.title}"? Tindakan ini tidak bisa dibatalkan.'),
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

    try {
      await context.read<VaultProvider>().deleteItem(id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VaultProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Tambah brankas',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          if (provider.error != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.loadItems(),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: provider.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Cari brankas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: provider.hasActiveSearch
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Bersihkan',
                        onPressed: () {
                          _searchController.clear();
                          provider.clearSearch();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (provider.hasActiveSearch &&
              !provider.loading &&
              provider.visibleItems.isEmpty)
            _NoResultsSearch(
              query: provider.searchQuery,
              onClear: () {
                provider.clearSearch();
                _searchController.clear();
              },
            ),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.visibleItems.isEmpty
                    ? _EmptyState(onAdd: () => _openEditor())
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: provider.visibleItems.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = provider.visibleItems[index];
                          return _VaultItemTile(
                            item: item,
                            onEdit: () => _openEditor(item),
                            onDelete: () => _confirmDelete(item),
                            isVisible:
                                _visiblePasswords[item.id ?? -1] ?? false,
                            onToggleVisibility: () {
                              final id = item.id;
                              if (id != null) _togglePasswordVisibility(id);
                            },
                            onCopy: () {
                              final pw = item.password;
                              if (pw.isEmpty) return;
                              Clipboard.setData(ClipboardData(text: pw));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Password disalin ke papan klip')),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsSearch extends StatelessWidget {
  const _NoResultsSearch({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off,
              size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Tidak ada hasil untuk "$query"',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            label: const Text('Bersihkan pencarian'),
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
          Icon(Icons.vpn_key_outlined,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Belum ada item brankas',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol + untuk menambah data sensitif pertama.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah brankas'),
          ),
        ],
      ),
    );
  }
}

class _VaultItemTile extends StatelessWidget {
  const _VaultItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onCopy,
  });

  final VaultItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title.isEmpty ? 'Tanpa judul' : item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd('id_ID')
                              .add_jm()
                              .format(item.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: onToggleVisibility, icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility)),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Salin password',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    tooltip: 'Hapus',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.username,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SelectableText(
                isVisible
                    ? item.password
                    : '•' *
                        (item.password.isNotEmpty ? item.password.length : 8),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: isVisible
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.url.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    item.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (item.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  item.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VaultEditorScreen extends StatefulWidget {
  const VaultEditorScreen({super.key, this.item});

  /// null = tambah, non-null = edit
  final VaultItem? item;

  @override
  State<VaultEditorScreen> createState() => _VaultEditorScreenState();
}

class _VaultEditorScreenState extends State<VaultEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;
  bool _showPassword = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _titleCtrl = TextEditingController(text: i?.title ?? '');
    _usernameCtrl = TextEditingController(text: i?.username ?? '');
    _passwordCtrl = TextEditingController(text: i?.password ?? '');
    _urlCtrl = TextEditingController(text: i?.url ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _showPassword = false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<VaultProvider>();
      final now = DateTime.now();
      final existing = widget.item;

      if (existing == null) {
        await provider.addItem(
          title: title,
          username: _usernameCtrl.text,
          password: _passwordCtrl.text,
          url: _urlCtrl.text,
          notes: _notesCtrl.text,
        );
      } else {
        await provider.updateItem(
          VaultItem(
            id: existing.id,
            title: title,
            username: _usernameCtrl.text,
            password: _passwordCtrl.text,
            url: _urlCtrl.text,
            notes: _notesCtrl.text,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyPassword() async {
    final pw = _passwordCtrl.text;
    if (pw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pw));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password disalin ke papan klip')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit brankas' : 'Brankas baru'),
        actions: [
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
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    IconButton(
                      onPressed: _copyPassword,
                      icon: const Icon(Icons.copy),
                      tooltip: 'Salin password',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outline),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}