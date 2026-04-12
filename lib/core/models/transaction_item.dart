class TransactionItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final String currency;

  TransactionItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.currency = 'YER',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'currency': currency,
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
      currency: map['currency'] ?? 'YER',
    );
  }

  double get total => price * quantity;

  TransactionItem copyWith({
    int? id,
    int? transactionId,
    int? productId,
    String? productName,
    int? quantity,
    double? price,
    String? currency,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      currency: currency ?? this.currency,
    );
  }
}
