import 'package:flutter/foundation.dart';

import '../models/finance_transaction.dart';
import '../services/database_service.dart';
import '../services/finance_summary.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<FinanceTransaction> _transactions = <FinanceTransaction>[];
  bool _loading = false;
  String? _error;
  String _query = '';
  FinanceTransactionType? _typeFilter;
  DateTime? _monthFilter;
  String? _categoryFilter;

  List<FinanceTransaction> get transactions =>
      List<FinanceTransaction>.unmodifiable(_transactions);
  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  FinanceTransactionType? get typeFilter => _typeFilter;
  DateTime? get monthFilter => _monthFilter;
  String? get categoryFilter => _categoryFilter;

  bool get hasActiveFilter =>
      _query.trim().isNotEmpty ||
      _typeFilter != null ||
      _monthFilter != null ||
      _categoryFilter != null;

  /// Kategori unik (tanpa string kosong), terurut abjad.
  List<String> get categories {
    final names = <String>{};
    for (final tx in _transactions) {
      final name = tx.category.trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Bulan unik dari transaksi (hari pertama bulan), terbaru dulu.
  List<DateTime> get months {
    final byKey = <int, DateTime>{};
    for (final tx in _transactions) {
      final month = DateTime(tx.occurredAt.year, tx.occurredAt.month);
      byKey[month.year * 12 + month.month] = month;
    }
    return byKey.values.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Transaksi setelah difilter pencarian, tipe, bulan, dan kategori.
  List<FinanceTransaction> get visibleTransactions {
    final keyword = _query.trim().toLowerCase();
    return _transactions.where((tx) {
      if (_typeFilter != null && tx.type != _typeFilter) return false;
      if (_monthFilter != null &&
          (tx.occurredAt.year != _monthFilter!.year ||
              tx.occurredAt.month != _monthFilter!.month)) {
        return false;
      }
      if (_categoryFilter != null && tx.category != _categoryFilter) {
        return false;
      }
      if (keyword.isEmpty) return true;
      final haystack = '${tx.category} ${tx.note} ${tx.amount}'.toLowerCase();
      return haystack.contains(keyword);
    }).toList(growable: false);
  }

  /// Ringkasan transaksi yang sedang tampil, mengikuti filter aktif.
  FinanceSummary get visibleSummary =>
      summarizeTransactions(visibleTransactions);

  /// Ringkasan bulanan untuk semua transaksi (terbaru dulu).
  /// Format: [Bulan] -> {income, expense, net}
  Map<DateTime, FinanceSummary> get monthlySummaries {
    final result = <DateTime, FinanceSummary>{};
    for (final tx in _transactions) {
      final key = DateTime(tx.occurredAt.year, tx.occurredAt.month);
      final existing = result[key] ?? const FinanceSummary(income: 0, expense: 0, count: 0);
      final newIncome = tx.isIncome ? existing.income + tx.amount : existing.income;
      final newExpense = !tx.isIncome ? existing.expense + tx.amount : existing.expense;
      final newCount = existing.count + 1;
      result[key] = FinanceSummary(income: newIncome, expense: newExpense, count: newCount);
    }
    return Map<DateTime, FinanceSummary>.fromEntries(
      result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  /// Cek apakah transaksi bertanda berulang (shadow metadata `#rec:`).
  static bool isRecurring(FinanceTransaction tx) {
    return tx.note.contains('#rec:');
  }

  /// Dapatkan frekuensi recurring dari transaksi (default: 'bulanan').
  static String getRecurringFrequency(FinanceTransaction tx) {
    final pattern = RegExp(r'#rec:(\w+)');
    final match = pattern.firstMatch(tx.note);
    return match?.group(1) ?? 'bulanan';
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setTypeFilter(FinanceTransactionType? value) {
    if (_typeFilter == value) return;
    _typeFilter = value;
    notifyListeners();
  }

  void setMonthFilter(DateTime? value) {
    final normalized = value == null ? null : DateTime(value.year, value.month);
    if (_monthFilter == normalized) return;
    _monthFilter = normalized;
    notifyListeners();
  }

  void setCategoryFilter(String? value) {
    final normalized = (value == null || value.isEmpty) ? null : value;
    if (_categoryFilter == normalized) return;
    _categoryFilter = normalized;
    notifyListeners();
  }

  void resetFilters() {
    if (!hasActiveFilter) return;
    _query = '';
    _typeFilter = null;
    _monthFilter = null;
    _categoryFilter = null;
    notifyListeners();
  }

  double get balance => _transactions.fold<double>(
      0,
      (sum, tx) =>
          sum + (tx.isIncome ? tx.amount : -tx.amount),
    );

  int get totalIncome => _transactions
      .where((tx) => tx.isIncome)
      .fold<int>(0, (sum, tx) => sum + tx.amount);

  int get totalExpense => _transactions
      .where((tx) => !tx.isIncome)
      .fold<int>(0, (sum, tx) => sum + tx.amount);

  Future<void> loadTransactions({DateTime? from, DateTime? to}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _service.getTransactions(
        from: from,
        to: to,
      );
    } catch (e) {
      _error = 'Gagal memuat transaksi: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction({
    required FinanceTransactionType type,
    required int amount,
    required String category,
    required String note,
    required DateTime occurredAt,
  }) async {
    final now = DateTime.now();
    await _service.insertTransaction(
      FinanceTransaction(
        type: type,
        amount: amount,
        category: category,
        note: note,
        occurredAt: occurredAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await loadTransactions();
  }

  Future<void> updateTransaction(FinanceTransaction tx) async {
    await _service.updateTransaction(
      FinanceTransaction(
        id: tx.id,
        type: tx.type,
        amount: tx.amount,
        category: tx.category,
        note: tx.note,
        occurredAt: tx.occurredAt,
        createdAt: tx.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _service.deleteTransaction(id);
    await loadTransactions();
  }

  /// Menghapus SEMUA transaksi (reset data).
  Future<void> clearAllTransactions() async {
    await _service.clearTransactions();
    await loadTransactions();
  }
}