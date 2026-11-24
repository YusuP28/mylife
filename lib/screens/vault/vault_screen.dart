import 'package:flutter/material.dart';
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
  final Set<int> _visiblePasswords = {};

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

  void _toggleVisibility(int? id) {
    if (id == null) return;
    setState(() {
      if (_visiblePasswords.contains(id)) {
        _visiblePasswords.remove(id);
      } else {
        _visiblePasswords.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VaultProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
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
              onChanged: (value) {
                // TODO Tahap 3: implement search filter di provider
              },
              decoration: InputDecoration(
                hintText: 'Cari brankas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(provider, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(VaultProvider provider, ThemeData theme) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return _EmptyState(onAdd: () {
        // Tahap 3: buka editor
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Tekan tombol + untuk menambah item brankas pertama.'),
          ),
        );
      });
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: provider.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = provider.items[index];
        return _VaultItemTile(
          item: item,
          isVisible: _visiblePasswords.contains(item.id),
          onToggleVisibility: () {
            final id = item.id;
            if (id != null) _toggleVisibility(id);
          },
        );
      },
    );
  }
}

class _VaultItemTile extends StatelessWidget {
  const _VaultItemTile({
    required this.item,
    required this.onVisible,
    required this.onToggleVisibility,
  });

  final VaultItem item;
  final bool onVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggleVisibility,
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
                        const SizedBox(height: 6),
                        Text(
                          item.url.isEmpty ? '' : 'URL: ${item.url}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleVisibility,
                    tooltip:
                        onVisible ? 'Sembunyikan password' : 'Tunjukkan password',
                    icon: Icon(
                      onVisible
                          ? Icons.lock_outline
                          : Icons.lock_open,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.username.isNotEmpty) ...<Widget>[
                Text(
                  'Username: ${item.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                onVisible
                    ? item.password
                    : '•' * (item.password.length > 0 ? item.password.length : 8),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: onVisible
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  item.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                DateFormat.yMMMd('id_ID').add_jm().format(item.updatedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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