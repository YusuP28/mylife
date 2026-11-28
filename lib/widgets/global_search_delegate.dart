import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/finance_transaction.dart';
import '../models/note.dart';
import '../models/vault_item.dart';
import '../providers/globals_provider.dart';
import '../providers/vault_provider.dart';
import '../screens/finance/finance_editor_screen.dart';
import '../screens/drawing/drawing_screen.dart';
import '../screens/vault/vault_screen.dart';

class GlobalSearchDelegate extends StatelessWidget {
  const GlobalSearchDelegate({super.key});

  void _navigateToNote(BuildContext context, int id, {String? title, String? body}) {
    // DrawingNoteScreen expects `note` (Note model), not noteId.
    // For search results we open editor in view mode — pass null for new-note path.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingNoteScreen(note: null),
      ),
    );
  }

  void _navigateToTransaction(BuildContext context, int id) {
    // FinanceEditorScreen expects `transaction` (FinanceTransaction model).
    // Open fresh for now; details screen can be refined later.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinanceEditorScreen(transaction: null),
      ),
    );
  }

  void _navigateToVaultItem(BuildContext context, VaultItem item) {
    final id = item.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item tidak valid')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultEditorScreen(item: item),
      ),
    );
  }

  /// Bangun RichText dengan link [[type:id]] yang dapat diklik.
  Widget _buildTextWithLinks(
    String text, {
    required ThemeData theme,
    required BuildContext parentContext,
    VoidCallback? onVaultLinkTap,
  }) {
    final linkPattern = RegExp(r'\[\[(note|tx|vault):(\d+)\]\]');
    final matches = linkPattern.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final spans = <InlineSpan>[];
    int lastOffset = 0;

    for (final match in matches) {
      // Teks sebelum link
      if (match.start > lastOffset) {
        spans.add(TextSpan(
          text: text.substring(lastOffset, match.start),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ));
      }

      // Link
      final type = match.group(1)!;
      final id = int.parse(match.group(2)!);
      final linkText = text.substring(match.start, match.end);

      void Function()? onTap;
      if (type == 'note') {
        onTap = () => _navigateToNote(parentContext, id);
      } else if (type == 'tx') {
        onTap = () => _navigateToTransaction(parentContext, id);
      } else if (type == 'vault' && onVaultLinkTap != null) {
        onTap = onVaultLinkTap;
      }

      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: (() {
          if (onTap == null) return null;
          final recognizer = TapGestureRecognizer();
          recognizer.onTap = onTap;
          return recognizer;
        })(),
      ));

      lastOffset = match.end;
    }

    // Teks setelah link terakhir
    if (lastOffset < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastOffset),
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildNoteCard(GlobalSearchResult result, ThemeData theme) {
    final note = result.note!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: () => _navigateToNote(context, note.id!),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sticky_note_2,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Catatan',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (innerContext) {
                      final body = note.body.isEmpty ? 'Tanpa isi' : note.body;
                      final isLong = body.length > 100;
                      String displayBody =
                          isLong ? '${body.substring(0, 100)}...' : body;
                      return _buildTextWithLinks(
                        displayBody,
                        theme: theme,
                        parentContext: innerContext,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(GlobalSearchResult result, ThemeData theme) {
    final tx = result.transaction!;
    final isIncome = tx.type == FinanceTransactionType.income;
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final amount = formatter.format(tx.amount);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: () => _navigateToTransaction(context, tx.id!),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 20,
                        color: isIncome
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text('Keuangan',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tx.category.isEmpty ? 'Tanpa kategori' : tx.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (innerContext) {
                      final note =
                          tx.note.isEmpty ? 'Tanpa keterangan' : tx.note;
                      return _buildTextWithLinks(
                        note,
                        theme: theme,
                        parentContext: innerContext,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIncome
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVaultCard(GlobalSearchResult result, ThemeData theme) {
    final item = result.item!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              InkWell(
                onTap: () => _navigateToVaultItem(context, item),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Vault',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (innerContext) {
                          final url = item.url.isEmpty ? '' : item.url;
                          return _buildTextWithLinks(
                            url,
                            theme: theme,
                            parentContext: innerContext,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Tombol Salin Password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    icon: Icon(Icons.copy, size: 16,
                        color: theme.colorScheme.primary),
                    onPressed: () {
                      if (item.password.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: item.password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password disalin ke papan klip'),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final globals = context.watch<GlobalsProvider>();

    if (!globals.hasResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tidak ada hasil untuk "${globals.query}"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: globals.results.length,
      itemBuilder: (context, index) {
        final result = globals.results[index];
        if (result.note != null) return _buildNoteCard(result, theme);
        if (result.transaction != null) {
          return _buildTransactionCard(result, theme);
        }
        if (result.item != null) return _buildVaultCard(result, theme);
        return const SizedBox.shrink();
      },
    );
  }
}

