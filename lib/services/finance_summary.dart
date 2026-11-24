import '../models/finance_transaction.dart';

/// Ringkasan nominal untuk sekumpulan transaksi (seluruh data atau hasil filter).
class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
    required this.count,
  });

  final int income;
  final int expense;
  final int count;

  /// Pemasukan dikurangi pengeluaran pada kumpulan ini.
  int get net => income - expense;
}

/// Menjumlahkan transaksi dalam satu lintasan. Tidak menyentuh database,
/// jadi bisa diuji tanpa sqflite.
FinanceSummary summarizeTransactions(
  Iterable<FinanceTransaction> transactions,
) {
  var income = 0;
  var expense = 0;
  var count = 0;

  for (final tx in transactions) {
    count++;
    if (tx.isIncome) {
      income += tx.amount;
    } else {
      expense += tx.amount;
    }
  }

  return FinanceSummary(income: income, expense: expense, count: count);
}
