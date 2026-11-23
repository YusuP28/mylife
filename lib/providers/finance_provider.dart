import 'package:flutter/foundation.dart';

import '../models/finance_transaction.dart';
import '../services/database_service.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<FinanceTransaction> _transactions = <FinanceTransaction>[];
  bool _loading = false;
  String? _error;

  List<FinanceTransaction> get transactions =>
      List<FinanceTransaction>.unmodifiable(_transactions);
  bool get loading => _loading;
  String? get error => _error;

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
}
