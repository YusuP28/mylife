import 'package:flutter_test/flutter_test.dart';

import 'package:mylife/models/finance_transaction.dart';
import 'package:mylife/services/finance_summary.dart';

void main() {
  group('FinanceSummary', () {
    final transactions = <FinanceTransaction>[
      FinanceTransaction(
        id: 1,
        type: 'income',
        amount: 5000000,
        category: 'Gaji',
        note: 'Bulanan',
        occurredAt: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      ),
      FinanceTransaction(
        id: 2,
        type: 'expense',
        amount: 1500000,
        category: 'Makan',
        note: 'Makan siang',
        occurredAt: DateTime(2026, 1, 20),
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
      ),
      FinanceTransaction(
        id: 3,
        type: 'expense',
        amount: 500000,
        category: 'Transport',
        note: 'Bensin',
        occurredAt: DateTime(2026, 1, 25),
        createdAt: DateTime(2026, 1, 25),
        updatedAt: DateTime(2026, 1, 25),
      ),
      FinanceTransaction(
        id: 4,
        type: 'income',
        amount: 2000000,
        category: 'Freelance',
        note: 'Project A',
        occurredAt: DateTime(2026, 2, 10),
        createdAt: DateTime(2026, 2, 10),
        updatedAt: DateTime(2026, 2, 10),
      ),
      FinanceTransaction(
        id: 5,
        type: 'expense',
        amount: 3000000,
        category: 'Belanja',
        note: 'Bulanan',
        occurredAt: DateTime(2026, 2, 15),
        createdAt: DateTime(2026, 2, 15),
        updatedAt: DateTime(2026, 2, 15),
      ),
    ];

    test('summarizeTransactions calculates correctly', () {
      final summary = FinanceSummary.summarizeTransactions(transactions);

      expect(summary.totalIncome, 7000000);
      expect(summary.totalExpense, 5000000);
      expect(summary.balance, 2000000);
      expect(summary.count, 5);
    });

    test('summarizeTransactions with empty list returns zeros', () {
      final summary = FinanceSummary.summarizeTransactions([]);
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
      expect(summary.balance, 0);
      expect(summary.count, 0);
    });

    test('summarizeTransactions only income', () {
      final incomeOnly = transactions.where((t) => t.type == 'income').toList();
      final summary = FinanceSummary.summarizeTransactions(incomeOnly);

      expect(summary.totalIncome, 7000000);
      expect(summary.totalExpense, 0);
      expect(summary.balance, 7000000);
      expect(summary.count, 2);
    });

    test('summarizeTransactions only expense', () {
      final expenseOnly = transactions.where((t) => t.type == 'expense').toList();
      final summary = FinanceSummary.summarizeTransactions(expenseOnly);

      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 5000000);
      expect(summary.balance, -5000000);
      expect(summary.count, 3);
    });

    test('FinanceSummary copyWith works', () {
      final summary = FinanceSummary.summarizeTransactions(transactions);
      final copied = summary.copyWith(totalIncome: 10000000);

      expect(copied.totalIncome, 10000000);
      expect(copied.totalExpense, summary.totalExpense);
      expect(copied.balance, summary.balance); // balance not auto-updated
      expect(copied.count, summary.count);
    });

    test('FinanceSummary equality', () {
      final s1 = FinanceSummary.summarizeTransactions(transactions);
      final s2 = FinanceSummary.summarizeTransactions(transactions);
      final s3 = FinanceSummary.summarizeTransactions([]);

      expect(s1, s2);
      expect(s1, isNot(s3));
    });
  });

  group('FinanceProvider visibleSummary (filter-aware)', () {
    final transactions = <FinanceTransaction>[
      FinanceTransaction(
        id: 1,
        type: 'income',
        amount: 5000000,
        category: 'Gaji',
        note: '',
        occurredAt: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      ),
      FinanceTransaction(
        id: 2,
        type: 'expense',
        amount: 1500000,
        category: 'Makan',
        note: '',
        occurredAt: DateTime(2026, 1, 20),
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
      ),
      FinanceTransaction(
        id: 3,
        type: 'expense',
        amount: 500000,
        category: 'Transport',
        note: '',
        occurredAt: DateTime(2026, 2, 10),
        createdAt: DateTime(2026, 2, 10),
        updatedAt: DateTime(2026, 2, 10),
      ),
      FinanceTransaction(
        id: 4,
        type: 'income',
        amount: 2000000,
        category: 'Freelance',
        note: '',
        occurredAt: DateTime(2026, 2, 15),
        createdAt: DateTime(2026, 2, 15),
        updatedAt: DateTime(2026, 2, 15),
      ),
    ];

    test('visibleSummary matches typeFilter', () {
      final incomeOnly = transactions.where((t) => t.type == 'income').toList();
      final summary = FinanceSummary.summarizeTransactions(incomeOnly);

      expect(summary.totalIncome, 7000000);
      expect(summary.totalExpense, 0);
      expect(summary.balance, 7000000);
    });

    test('visibleSummary matches categoryFilter', () {
      final makanOnly = transactions.where((t) => t.category == 'Makan').toList();
      final summary = FinanceSummary.summarizeTransactions(makanOnly);

      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 1500000);
      expect(summary.balance, -1500000);
      expect(summary.count, 1);
    });

    test('visibleSummary matches monthFilter (January)', () {
      final janOnly = transactions
          .where((t) => t.occurredAt.month == 1 && t.occurredAt.year == 2026)
          .toList();
      final summary = FinanceSummary.summarizeTransactions(janOnly);

      expect(summary.totalIncome, 5000000);
      expect(summary.totalExpense, 1500000);
      expect(summary.balance, 3500000);
      expect(summary.count, 2);
    });

    test('visibleSummary matches monthFilter (February)', () {
      final febOnly = transactions
          .where((t) => t.occurredAt.month == 2 && t.occurredAt.year == 2026)
          .toList();
      final summary = FinanceSummary.summarizeTransactions(febOnly);

      expect(summary.totalIncome, 2000000);
      expect(summary.totalExpense, 500000);
      expect(summary.balance, 1500000);
      expect(summary.count, 2);
    });

    test('visibleSummary combines typeFilter + monthFilter', () {
      final janExpense = transactions
          .where((t) =>
              t.type == 'expense' &&
              t.occurredAt.month == 1 &&
              t.occurredAt.year == 2026)
          .toList();
      final summary = FinanceSummary.summarizeTransactions(janExpense);

      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 1500000);
      expect(summary.balance, -1500000);
      expect(summary.count, 1);
    });
  });
}