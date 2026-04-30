import 'transaction_item.dart';

enum TransactionType { sale, payment, refund }

class AppTransaction {
  final int? id;
  final int? customerId; // null for generic cash sales
  final TransactionType type;
  final double amount;
  final double paidAmount; // For sales: how much was actually paid. Default 0 for payment/refund.
  final String currency;
  final DateTime date;
  final String note;
  final List<TransactionItem> items;
  final bool isVoid;

  AppTransaction({
    this.id,
    this.customerId,
    required this.type,
    required this.amount,
    this.paidAmount = 0,
    this.currency = 'YER',
    required this.date,
    this.note = '',
    this.items = const [],
    this.isVoid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'type': type.name,
      'amount': amount,
      'paid_amount': paidAmount,
      'currency': currency,
      'date': date.toIso8601String(),
      'note': note,
      'is_void': isVoid ? 1 : 0,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map, {List<TransactionItem> items = const []}) {
    return AppTransaction(
      id: map['id'],
      customerId: map['customer_id'],
      type: TransactionType.values.byName(map['type']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      items: items,
      isVoid: (map['is_void'] as num?)?.toInt() == 1,
    );
  }

  AppTransaction copyWith({
    int? id,
    int? customerId,
    TransactionType? type,
    double? amount,
    double? paidAmount,
    String? currency,
    DateTime? date,
    String? note,
    List<TransactionItem>? items,
    bool? isVoid,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      note: note ?? this.note,
      items: items ?? this.items,
      isVoid: isVoid ?? this.isVoid,
    );
  }
}
