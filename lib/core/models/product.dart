class Product {
  final int? id;
  final String name;
  final double price;
  final String currency;
  final int stockQuantity;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.currency = 'YER',
    this.stockQuantity = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'stock_quantity': stockQuantity,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      currency: map['currency'] ?? 'YER',
      stockQuantity: map['stock_quantity'] ?? 0,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? currency,
    int? stockQuantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }
}
