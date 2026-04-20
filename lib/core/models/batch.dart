class Batch {
  final String? id;
  final int productId;
  final int quantity;
  final double costPrice;
  final DateTime createdAt;
  final DateTime? expiryDate;

  Batch({
    this.id,
    required this.productId,
    required this.quantity,
    required this.costPrice,
    required this.createdAt,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'cost_price': costPrice,
      'created_at': createdAt.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id']?.toString(),
      productId: map['product_id'],
      quantity: map['quantity'],
      costPrice: (map['cost_price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      expiryDate: map['expiry_date'] != null ? DateTime.parse(map['expiry_date']) : null,
    );
  }

  Batch copyWith({
    String? id,
    int? productId,
    int? quantity,
    double? costPrice,
    DateTime? createdAt,
    DateTime? expiryDate,
  }) {
    return Batch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isNearExpiry {
    if (expiryDate == null) return false;
    // Less than 30 days remaining
    return expiryDate!.difference(DateTime.now()).inDays < 30;
  }
}
