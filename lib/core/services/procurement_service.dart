import '../models/purchase_order.dart';
import '../models/supplier_transaction.dart';
import '../models/supplier_transaction_item.dart';
import 'database_helper.dart';
import 'supplier_transaction_service.dart';

class ProcurementService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupplierTransactionService _supplierTxService = SupplierTransactionService();

  Future<int> createPurchaseOrder(PurchaseOrder po) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Insert PO header
      final poId = await txn.insert('purchase_orders', po.toMap());

      // 2. Insert PO items
      for (var item in po.items) {
        await txn.insert('purchase_order_items', {
          ...item.toMap(),
          'purchase_order_id': poId,
        });
      }
      return poId;
    });
  }

  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('purchase_orders', orderBy: 'date DESC');
    
    List<PurchaseOrder> pos = [];
    for (var map in maps) {
      final poId = map['id'] as int;
      final itemsMap = await db.query('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [poId]);
      final items = itemsMap.map((m) => PurchaseOrderItem.fromMap(m)).toList();
      pos.add(PurchaseOrder.fromMap(map, items: items));
    }
    return pos;
  }

  Future<void> updatePurchaseOrderStatus(int poId, PurchaseOrderStatus status) async {
    final db = await _dbHelper.database;
    await db.update('purchase_orders', {'status': status.name}, where: 'id = ?', whereArgs: [poId]);
  }

  Future<void> receivePurchaseOrder(int poId, {double? paidAmount}) async {
    final db = await _dbHelper.database;
    final poMap = await db.query('purchase_orders', where: 'id = ?', whereArgs: [poId]);
    if (poMap.isEmpty) return;
    
    final itemsMap = await db.query('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [poId]);
    final items = itemsMap.map((m) => PurchaseOrderItem.fromMap(m)).toList();
    final po = PurchaseOrder.fromMap(poMap.first, items: items);

    if (po.status == PurchaseOrderStatus.received) return;

    // 1. Convert PO to SupplierTransaction (Purchase)
    final txItems = po.items.map((item) => SupplierTransactionItem(
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      costPrice: item.costPrice,
    )).toList();

    final tx = SupplierTransaction(
      supplierId: po.supplierId,
      type: SupplierTransactionType.purchase,
      amount: po.totalAmount,
      paidAmount: paidAmount ?? 0,
      currency: 'YER',
      date: DateTime.now(),
      note: 'Received PO #${po.id}. ${po.note ?? ""}',
      items: txItems,
    );

    // 2. Add transaction (this handles stock update and accounting)
    await _supplierTxService.addTransaction(tx);

    // 3. Update PO status
    await updatePurchaseOrderStatus(poId, PurchaseOrderStatus.received);
  }
}
