import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/models/finance_transaction.dart';
import 'package:mylife/services/finance_summary.dart';

FinanceTransaction _tx(
  int amount, {
  bool income = false,
  String category = '',
}) {
  final at = DateTime(2026, 1, 1);
  return FinanceTransaction(
    type: income
        ? FinanceTransactionType.income
        : FinanceTransactionType.expense,
    amount: amount,
    category: category,
    note: '',
    occurredAt: at,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('menjumlahkan pemasukan dan pengeluaran', () {
    final summary = summarizeTransactions(<FinanceTransaction>[
      _tx(100000, income: true),
      _tx(25000),
      _tx(15000),
    ]);

    expect(summary.income, 100000);
    expect(summary.expense, 40000);
    expect(summary.net, 60000);
    expect(summary.count, 3);
  });

  test('daftar kosong menghasilkan nol', () {
    final summary = summarizeTransactions(const <FinanceTransaction>[]);

    expect(summary.income, 0);
    expect(summary.expense, 0);
    expect(summary.net, 0);
    expect(summary.count, 0);
  });

  test('selisih bisa negatif', () {
    final summary = summarizeTransactions(<FinanceTransaction>[_tx(5000)]);

    expect(summary.net, -5000);
  });
}
