class Product {
  final int? id;
  final String name;
  final double price;
  final double costPrice;
  final String currency;
  final int stockQuantity;
  final String? barcode;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.currency = 'YER',
    this.stockQuantity = 0,
    this.barcode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'currency': currency,
      'stock_quantity': stockQuantity,
      'barcode': barcode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'YER',
      stockQuantity: map['stock_quantity'] ?? 0,
      barcode: map['barcode'],
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    double? costPrice,
    String? currency,
    int? stockQuantity,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      currency: currency ?? this.currency,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      barcode: barcode ?? this.barcode,
    );
  }
}
