enum TransactionType { debt, payment }

class DebtTransaction {
  final int? id;
  final int customerId;
  final TransactionType type;
  final double amount; // دائماً موجب
  final String note;
  final DateTime date;

  DebtTransaction({
    this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now(); // التاريخ يُحفظ تلقائياً

  factory DebtTransaction.fromMap(Map<String, dynamic> map) => DebtTransaction(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int,
        type: map['type'] == 'debt' ? TransactionType.debt : TransactionType.payment,
        amount: (map['amount'] as num).toDouble(),
        note: (map['note'] ?? '') as String,
        date: DateTime.parse(map['date'] as String),
      );

  Map<String, dynamic> toMap() => {
        'customer_id': customerId,
        'type': type == TransactionType.debt ? 'debt' : 'payment',
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
      };
}