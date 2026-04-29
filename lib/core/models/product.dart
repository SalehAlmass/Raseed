import 'batch.dart';

class Product {
  final int? id;
  final String name;
  final double price;
  final double costPrice;
  final String currency;
  final int stockQuantity; // Stored in sub-units
  final String? barcode;

  final int unitsPerPackage; // Legacy, will use conversionFactor
  final double packagePrice; // Purchase price for main unit
  
  final int? categoryId;
  final int? mainUnitId;
  final int? subUnitId;
  final int conversionFactor;
  final int reorderLevel;
  final double wholesalePrice;
  final String? shelfLocation;
  final int? supplierId;

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
    this.categoryId,
    this.mainUnitId,
    this.subUnitId,
    this.conversionFactor = 1,
    this.reorderLevel = 0,
    this.wholesalePrice = 0.0,
    this.shelfLocation,
    this.supplierId,
    this.batches = const [],
  });

  // Convenience getters
  double get purchasePricePerMainUnit => packagePrice;
  double get salePricePerSubUnit => price;
  
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
      'category_id': categoryId,
      'main_unit_id': mainUnitId,
      'sub_unit_id': subUnitId,
      'conversion_factor': conversionFactor,
      'reorder_level': reorderLevel,
      'wholesale_price': wholesalePrice,
      'shelf_location': shelfLocation,
      'supplier_id': supplierId,
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
      categoryId: map['category_id'],
      mainUnitId: map['main_unit_id'],
      subUnitId: map['sub_unit_id'],
      conversionFactor: map['conversion_factor'] ?? 1,
      reorderLevel: map['reorder_level'] ?? 0,
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0.0,
      shelfLocation: map['shelf_location'],
      supplierId: map['supplier_id'],
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
    int? categoryId,
    int? mainUnitId,
    int? subUnitId,
    int? conversionFactor,
    int? reorderLevel,
    double? wholesalePrice,
    String? shelfLocation,
    int? supplierId,
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
      categoryId: categoryId ?? this.categoryId,
      mainUnitId: mainUnitId ?? this.mainUnitId,
      subUnitId: subUnitId ?? this.subUnitId,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      supplierId: supplierId ?? this.supplierId,
      batches: batches ?? this.batches,
    );
  }
}
