enum FinanceTransactionType {
  income,
  expense;

  static FinanceTransactionType fromValue(Object? value) =>
      value == income.name ? income : expense;
}

class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final FinanceTransactionType type;

  /// Nominal dalam rupiah penuh (integer, bukan desimal).
  final int amount;
  final String category;
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIncome => type == FinanceTransactionType.income;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory FinanceTransaction.fromMap(Map<String, Object?> map) =>
      FinanceTransaction(
        id: map['id'] as int?,
        type: FinanceTransactionType.fromValue(map['type']),
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        category: map['category'] as String? ?? '',
        note: map['note'] as String? ?? '',
        occurredAt: _dateFrom(map['occurred_at']),
        createdAt: _dateFrom(map['created_at']),
        updatedAt: _dateFrom(map['updated_at']),
      );

  static DateTime _dateFrom(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
