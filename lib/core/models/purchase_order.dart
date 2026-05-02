enum PurchaseOrderStatus { pending, received, cancelled }

class PurchaseOrder {
  final int? id;
  final int supplierId;
  final DateTime date;
  final PurchaseOrderStatus status;
  final double totalAmount;
  final String? note;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    this.id,
    required this.supplierId,
    required this.date,
    required this.status,
    required this.totalAmount,
    this.note,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'date': date.toIso8601String(),
      'status': status.name,
      'total_amount': totalAmount,
      'note': note,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {List<PurchaseOrderItem> items = const []}) {
    return PurchaseOrder(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int,
      date: DateTime.parse(map['date'] as String),
      status: PurchaseOrderStatus.values.byName(map['status'] as String),
      totalAmount: map['total_amount'] as double,
      note: map['note'] as String?,
      items: items,
    );
  }
}

class PurchaseOrderItem {
  final int? id;
  final int? purchaseOrderId;
  final int productId;
  final String productName;
  final int quantity;
  final double costPrice;

  PurchaseOrderItem({
    this.id,
    this.purchaseOrderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_order_id': purchaseOrderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'cost_price': costPrice,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'] as int?,
      purchaseOrderId: map['purchase_order_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      costPrice: map['cost_price'] as double,
    );
  }
}
