class PurchasePriceRecord {
  final int? id;
  final int productId;
  final int supplierId;
  final double costPrice;
  final int quantity;
  final int? transactionId;
  final DateTime date;

  PurchasePriceRecord({
    this.id,
    required this.productId,
    required this.supplierId,
    required this.costPrice,
    required this.quantity,
    this.transactionId,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'supplier_id': supplierId,
      'cost_price': costPrice,
      'quantity': quantity,
      'transaction_id': transactionId,
      'date': date.toIso8601String(),
    };
  }

  factory PurchasePriceRecord.fromMap(Map<String, dynamic> map) {
    return PurchasePriceRecord(
      id: map['id'],
      productId: map['product_id'],
      supplierId: map['supplier_id'],
      costPrice: (map['cost_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      transactionId: map['transaction_id'],
      date: DateTime.parse(map['date']),
    );
  }
}
