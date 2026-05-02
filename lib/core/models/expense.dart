class Expense {
  final int? id;
  final int? categoryId;
  final double amount;
  final DateTime date;
  final String? note;
  final String? imagePath;
  final int? accountId;

  Expense({
    this.id,
    this.categoryId,
    required this.amount,
    required this.date,
    this.note,
    this.imagePath,
    this.accountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'image_path': imagePath,
      'account_id': accountId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int?,
      amount: map['amount'] as double,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      imagePath: map['image_path'] as String?,
      accountId: map['account_id'] as int?,
    );
  }
}
