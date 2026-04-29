import 'supplier_transaction_item.dart';

enum SupplierTransactionType { purchase, payment }

class SupplierTransaction {
  final int? id;
  final int supplierId;
  final SupplierTransactionType type;
  final double amount;
  final double paidAmount;
  final String currency;
  final DateTime date;
  final String note;
  final List<SupplierTransactionItem> items;
  final bool isVoid;

  SupplierTransaction({
    this.id,
    required this.supplierId,
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
      'supplier_id': supplierId,
      'type': type.name,
      'amount': amount,
      'paid_amount': paidAmount,
      'currency': currency,
      'date': date.toIso8601String(),
      'note': note,
      'is_void': isVoid ? 1 : 0,
    };
  }

  factory SupplierTransaction.fromMap(Map<String, dynamic> map,
      {List<SupplierTransactionItem> items = const []}) {
    return SupplierTransaction(
      id: map['id'],
      supplierId: map['supplier_id'],
      type: SupplierTransactionType.values.byName(map['type']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      items: items,
      isVoid: (map['is_void'] as num?)?.toInt() == 1,
    );
  }

  SupplierTransaction copyWith({
    int? id,
    int? supplierId,
    SupplierTransactionType? type,
    double? amount,
    double? paidAmount,
    String? currency,
    DateTime? date,
    String? note,
    List<SupplierTransactionItem>? items,
    bool? isVoid,
  }) {
    return SupplierTransaction(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
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
