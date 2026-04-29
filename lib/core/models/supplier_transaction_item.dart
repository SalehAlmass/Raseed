class SupplierTransactionItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName;
  final int quantity;
  final double costPrice;
  final String currency;

  SupplierTransactionItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    this.currency = 'YER',
  });

  Map<String, dynamic> toMap(int txId) {
    return {
      'id': id,
      'transaction_id': txId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'cost_price': costPrice,
      'currency': currency,
    };
  }

  factory SupplierTransactionItem.fromMap(Map<String, dynamic> map) {
    return SupplierTransactionItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
    );
  }
}
