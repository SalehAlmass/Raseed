class TransactionItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double costPrice;
  final String currency;
  final double lineDiscount;

  TransactionItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.costPrice = 0.0,
    this.currency = 'YER',
    this.lineDiscount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'cost_price': costPrice,
      'currency': currency,
      'line_discount': lineDiscount > 0 ? lineDiscount : 0,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      lineDiscount: (map['line_discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double get total => (price * quantity) - lineDiscount;
  double get profit => ((price - costPrice) * quantity) - lineDiscount;

  TransactionItem copyWith({
    int? id,
    int? transactionId,
    int? productId,
    String? productName,
    int? quantity,
    double? price,
    double? costPrice,
    String? currency,
    double? lineDiscount,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      currency: currency ?? this.currency,
      lineDiscount: lineDiscount ?? this.lineDiscount,
    );
  }
}
