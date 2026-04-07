import 'transaction_item.dart';

enum TransactionType { cash, debt, payment }

class AppTransaction {
  final int? id;
  final int? customerId; // null for generic cash sales
  final TransactionType type;
  final double amount;
  final String currency;
  final DateTime date;
  final String note;
  final List<TransactionItem> items;

  AppTransaction({
    this.id,
    this.customerId,
    required this.type,
    required this.amount,
    this.currency = 'YER',
    required this.date,
    this.note = '',
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'type': type.name,
      'amount': amount,
      'currency': currency,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map, {List<TransactionItem> items = const []}) {
    return AppTransaction(
      id: map['id'],
      customerId: map['customer_id'],
      type: TransactionType.values.byName(map['type']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      items: items,
    );
  }

  AppTransaction copyWith({
    int? id,
    int? customerId,
    TransactionType? type,
    double? amount,
    String? currency,
    DateTime? date,
    String? note,
    List<TransactionItem>? items,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      note: note ?? this.note,
      items: items ?? this.items,
    );
  }
}
