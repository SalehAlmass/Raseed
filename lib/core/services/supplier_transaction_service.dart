import '../models/supplier_transaction.dart';
import '../models/supplier_transaction_item.dart';
import 'database_helper.dart';
import 'supplier_service.dart';
import 'product_service.dart';
import '../di/injection_container.dart';

class SupplierTransactionService {
  final _dbHelper = DatabaseHelper.instance;

  Future<int> addTransaction(SupplierTransaction tx) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 1. Insert transaction
      final txId = await txn.insert('supplier_transactions', tx.toMap());

      // 2. Insert items and update stock if it's a purchase
      for (var item in tx.items) {
        await txn.insert('supplier_transaction_items', item.toMap(txId));
        
        if (tx.type == SupplierTransactionType.purchase && !tx.isVoid) {
          // Increment stock
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // 3. Update supplier debt
      double debtChange = 0;
      if (tx.type == SupplierTransactionType.purchase) {
        debtChange = tx.amount - tx.paidAmount;
      } else if (tx.type == SupplierTransactionType.payment) {
        debtChange = -tx.amount;
      }

      if (debtChange != 0 && !tx.isVoid) {
        await txn.execute(
          'UPDATE suppliers SET total_debt = total_debt + ?, last_transaction_date = ? WHERE id = ?',
          [debtChange, tx.date.toIso8601String(), tx.supplierId],
        );
      }

      return txId;
    });
  }

  Future<List<SupplierTransaction>> getTransactionsBySupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'supplier_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date DESC',
    );

    List<SupplierTransaction> transactions = [];
    for (var map in maps) {
      final itemsMap = await db.query(
        'supplier_transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [map['id']],
      );
      final items = itemsMap.map((m) => SupplierTransactionItem.fromMap(m)).toList();
      transactions.add(SupplierTransaction.fromMap(map, items: items));
    }
    return transactions;
  }

  Future<void> voidTransaction(int txId) async {
    final db = await _dbHelper.database;
    final txMap = await db.query('supplier_transactions', where: 'id = ?', whereArgs: [txId]);
    if (txMap.isEmpty) return;
    
    final tx = SupplierTransaction.fromMap(txMap.first);
    if (tx.isVoid) return;

    await db.transaction((txn) async {
      // 1. Mark as void
      await txn.update('supplier_transactions', {'is_void': 1}, where: 'id = ?', whereArgs: [txId]);

      // 2. Reverse stock if purchase
      if (tx.type == SupplierTransactionType.purchase) {
        final itemsMap = await txn.query('supplier_transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
        for (var itemMap in itemsMap) {
          final item = SupplierTransactionItem.fromMap(itemMap);
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // 3. Reverse debt
      double debtReverse = 0;
      if (tx.type == SupplierTransactionType.purchase) {
        debtReverse = -(tx.amount - tx.paidAmount);
      } else if (tx.type == SupplierTransactionType.payment) {
        debtReverse = tx.amount;
      }

      if (debtReverse != 0) {
        await txn.execute(
          'UPDATE suppliers SET total_debt = total_debt + ? WHERE id = ?',
          [debtReverse, tx.supplierId],
        );
      }
    });
  }
}
