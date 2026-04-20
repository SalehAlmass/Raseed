import 'batch.dart';

class Product {
  final int? id;
  final String name;
  final double price;
  final double costPrice;
  final String currency;
  final int stockQuantity;
  final String? barcode;

  final int unitsPerPackage;
  final double packagePrice;
  final List<Batch> batches;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.currency = 'YER',
    this.stockQuantity = 0,
    this.barcode,
    this.unitsPerPackage = 1,
    this.packagePrice = 0.0,
    this.batches = const [],
  });

  double get unitPrice => unitsPerPackage > 0 ? packagePrice / unitsPerPackage : price;
  
  bool get hasExpiredBatch => batches.any((b) => b.isExpired);
  bool get hasNearExpiryBatch => batches.any((b) => b.isNearExpiry);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'currency': currency,
      'stock_quantity': stockQuantity,
      'barcode': barcode,
      'units_per_package': unitsPerPackage,
      'package_price': packagePrice,
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
      unitsPerPackage: map['units_per_package'] ?? 1,
      packagePrice: (map['package_price'] as num?)?.toDouble() ?? 0.0,
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
    int? unitsPerPackage,
    double? packagePrice,
    List<Batch>? batches,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      currency: currency ?? this.currency,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      barcode: barcode ?? this.barcode,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      packagePrice: packagePrice ?? this.packagePrice,
      batches: batches ?? this.batches,
    );
  }
}
