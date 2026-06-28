import 'transaction_item.dart';

enum TransactionType { sale, payment, refund }

enum DiscountType { none, percentage, fixed }

class AppTransaction {
  final int? id;
  final int? customerId;
  final TransactionType type;
  final double amount;
  final double paidAmount;
  final String currency;
  final DateTime date;
  final String note;
  final List<TransactionItem> items;
  final bool isVoid;
  final String returnReason;
  final String returnCondition;
  final DiscountType discountType;
  final double discountValue;
  final String promoCode;

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
    this.returnReason = '',
    this.returnCondition = 'good',
    this.discountType = DiscountType.none,
    this.discountValue = 0.0,
    this.promoCode = '',
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  double get netAmount => subtotal - totalDiscount;
  double get totalDiscount {
    if (discountType == DiscountType.percentage) return subtotal * discountValue / 100;
    if (discountType == DiscountType.fixed) return discountValue;
    return 0.0;
  }

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
      'return_reason': returnReason.isEmpty ? null : returnReason,
      'return_condition': returnCondition,
      'discount_type': discountType == DiscountType.none ? null : discountType.name,
      'discount_value': discountValue > 0 ? discountValue : 0,
      'promo_code': promoCode.isEmpty ? null : promoCode,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map, {List<TransactionItem> items = const []}) {
    final dtStr = map['discount_type'] as String?;
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
      returnReason: map['return_reason'] ?? '',
      returnCondition: map['return_condition'] ?? 'good',
      discountType: dtStr != null && dtStr.isNotEmpty ? DiscountType.values.byName(dtStr) : DiscountType.none,
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
      promoCode: map['promo_code'] ?? '',
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
    String? returnReason,
    String? returnCondition,
    DiscountType? discountType,
    double? discountValue,
    String? promoCode,
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
      returnReason: returnReason ?? this.returnReason,
      returnCondition: returnCondition ?? this.returnCondition,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      promoCode: promoCode ?? this.promoCode,
    );
  }
}
