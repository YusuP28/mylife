import 'package:flutter/foundation.dart';

import '../models/finance_transaction.dart';
import '../models/note.dart';
import '../models/vault_item.dart';
import '../providers/finance_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/vault_provider.dart';

/// Hasil pencarian global lintas-modul.
class GlobalSearchResult {
  GlobalSearchResult.note({this.note, this.transaction, this.item});
  GlobalSearchResult.transaction({this.note, this.transaction, this.item});
  GlobalSearchResult.vaultItem({this.note, this.transaction, this.item});

  final Note? note;
  final FinanceTransaction? transaction;
  final VaultItem? item;
}

/// Provider untuk pencarian global lintas-modul.
/// Tidak mengubah skema database (`_dbVersion` tetap 3).
class GlobalsProvider extends ChangeNotifier {
  GlobalsProvider({
    required this.notesProvider,
    required this.financeProvider,
    required this.vaultProvider,
  });

  final NotesProvider notesProvider;
  final FinanceProvider financeProvider;
  final VaultProvider vaultProvider;

  String _query = '';
  List<GlobalSearchResult> _results = <GlobalSearchResult>[];

  List<GlobalSearchResult> get results =>
      List<GlobalSearchResult>.unmodifiable(_results);
  bool get hasResults => _results.isNotEmpty;
  bool get hasActiveSearch => _query.trim().isNotEmpty;
  String get query => _query;

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _performSearch();
  }

  void clearQuery() {
    if (_query.isEmpty) return;
    _query = '';
    _results = <GlobalSearchResult>[];
    notifyListeners();
  }

  void _performSearch() {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) {
      _results = <GlobalSearchResult>[];
      notifyListeners();
      return;
    }

    final matches = <GlobalSearchResult>[];

    // Pencarian di Notes
    for (final note in notesProvider.notes) {
      if (note.title.toLowerCase().contains(keyword) ||
          note.body.toLowerCase().contains(keyword)) {
        matches.add(GlobalSearchResult.note(note: note));
      }
    }

    // Pencarian di Finance
    for (final tx in financeProvider.transactions) {
      final haystack =
          '${tx.category} ${tx.note} ${tx.amount}'.toLowerCase();
      if (haystack.contains(keyword)) {
        matches.add(GlobalSearchResult.transaction(transaction: tx));
      }
    }

    // Pencarian di Vault
    for (final item in vaultProvider.items) {
      final haystack =
          '${item.title} ${item.username} ${item.url} ${item.notes}'
              .toLowerCase();
      if (haystack.contains(keyword)) {
        matches.add(GlobalSearchResult.vaultItem(item: item));
      }
    }

    _results = matches;
    notifyListeners();
  }
}
