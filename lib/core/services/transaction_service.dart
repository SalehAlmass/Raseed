import '../models/app_transaction.dart';
import '../models/transaction_item.dart';
import '../models/app_settings.dart';
import 'database_helper.dart';
import 'customer_service.dart';
import 'settings_service.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CustomerService _customerService;
  final SettingsService _settingsService;

  TransactionService(this._customerService, this._settingsService);

  Future<int> addTransaction(AppTransaction transaction) async {
    final db = await _dbHelper.database;

    // --- Strict Validations ---
    
    // 1. Check for debt repayment rules
    if (transaction.type == TransactionType.payment && transaction.customerId != null) {
      final customerMap = await db.query(
        'customers', 
        where: 'id = ?', 
        whereArgs: [transaction.customerId],
      ).then((maps) => maps.first);
      
      final currentDebt = (customerMap['total_debt'] as num).toDouble();
      
      if (currentDebt <= 0) {
        throw Exception('no_debt_to_repay');
      }
      
      if (transaction.amount > currentDebt) {
        throw Exception('payment_exceeds_debt');
      }
    }

    // 2. Check for Sale overpayment
    if (transaction.type == TransactionType.sale && transaction.paidAmount > transaction.amount) {
      throw Exception('amount_exceeds_total');
    }

    // 3. Check for Stock (if SALE and strictMode ON)
    final settings = await _settingsService.getSettings();
    if (transaction.type == TransactionType.sale && settings.strictMode) {
      for (final item in transaction.items) {
        final productMap = await db.query(
          'products',
          columns: ['stock_quantity'],
          where: 'id = ?',
          whereArgs: [item.productId],
        ).then((maps) => maps.first);
        
        final currentStock = (productMap['stock_quantity'] as num).toInt();
        if (currentStock < item.quantity) {
          throw Exception('insufficient_stock');
        }
      }
    }

    // 4. Check for debt limit
    if (transaction.type == TransactionType.sale && transaction.customerId != null) {
      final customerMap = await db.query(
        'customers', 
        where: 'id = ?', 
        whereArgs: [transaction.customerId],
      ).then((maps) => maps.first);
      
      final currentDebt = (customerMap['total_debt'] as num).toDouble();
      final remainingDebt = transaction.amount - transaction.paidAmount;
      final totalNewDebt = currentDebt + remainingDebt;
      
      if (totalNewDebt > settings.maxDebt) {
        if (settings.debtMode == DebtMode.block) {
          throw Exception('over_limit');
        } else if (settings.debtMode == DebtMode.warning) {
          // In a real app, we might return a status that includes a warning.
          // For now, we allow it but we could log it or throw a specific 'warning_triggered' 
          // that the UI can catch and then re-summit with a flag.
          // Simplification: just allow it if mode is warning, but we could add a note.
        }
      }
    }

    return await db.transaction((txn) async {
      // 1. Insert transaction
      final int transactionId = await txn.insert('transactions', transaction.toMap());

      // 2. Insert items and update stock
      if (transaction.items.isNotEmpty) {
        for (final item in transaction.items) {
          final itemId = await txn.insert('transaction_items', item.toMap()..['transaction_id'] = transactionId);
          
          if (transaction.type == TransactionType.sale) {
            // FIFO Logic: Deduct from batches
            int remainingToDeduct = item.quantity;
            double totalCostForThisItem = 0;

            final List<Map<String, dynamic>> batches = await txn.query(
              'product_batches',
              where: 'product_id = ? AND quantity > 0',
              orderBy: 'created_at ASC',
            );

            for (var batchMap in batches) {
              if (remainingToDeduct <= 0) break;

              final int batchId = batchMap['id'];
              final int batchQty = batchMap['quantity'];
              final double batchCost = (batchMap['cost_price'] as num).toDouble();

              if (batchQty <= remainingToDeduct) {
                // Consume entire batch
                totalCostForThisItem += batchQty * batchCost;
                remainingToDeduct -= batchQty;
                await txn.delete('product_batches', where: 'id = ?', whereArgs: [batchId]);
              } else {
                // Consume partial batch
                totalCostForThisItem += remainingToDeduct * batchCost;
                await txn.execute(
                  'UPDATE product_batches SET quantity = quantity - ? WHERE id = ?',
                  [remainingToDeduct, batchId]
                );
                remainingToDeduct = 0;
              }
            }

            // If there's still quantity remaining but no batches found (fallback for old products)
            if (remainingToDeduct > 0) {
              totalCostForThisItem += remainingToDeduct * item.costPrice;
            }

            // Update the cost price in the transaction item row to the actual FIFO cost
            final avgCost = totalCostForThisItem / item.quantity;
            await txn.update(
              'transaction_items',
              {'cost_price': avgCost},
              where: 'id = ?',
              whereArgs: [itemId]
            );

            // Update total stock in products table
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [item.quantity, item.productId]
            );
          } else if (transaction.type == TransactionType.refund) {
            // Restore stock
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [item.quantity, item.productId]
            );
          }
        }
      }

      // 3. Update customer debt if applicable
      if (transaction.customerId != null) {
        double debtChange = 0.0;
        
        if (transaction.type == TransactionType.payment) {
          // Payment reduces debt (Payment is stored as positive amount)
          debtChange = -transaction.amount;
        } else if (transaction.type == TransactionType.sale) {
          // Sale adds remaining debt (amount - paid)
          final remainingDebt = transaction.amount - transaction.paidAmount;
          debtChange = remainingDebt;
        } else if (transaction.type == TransactionType.refund) {
          // Refund reduces debt. 
          // If transaction.amount is stored as negative (e.g., -500), 
          // then adding it will reduce debt.
          debtChange = transaction.amount;
        }

        if (debtChange != 0 || transaction.type == TransactionType.sale || transaction.type == TransactionType.refund) {
          await _customerService.updateCustomerStats(
            id: transaction.customerId!,
            debtChange: debtChange,
            date: transaction.date,
            totalSpentChange: transaction.type == TransactionType.sale 
                ? transaction.amount 
                : (transaction.type == TransactionType.refund ? transaction.amount : 0.0),
            executor: txn,
          );
        }
      }

      return transactionId;
    });
  }

  Future<List<AppTransaction>> getCustomerTransactions(int customerId, {int limit = 50, int offset = 0}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'customer_id = ? AND is_void = 0',
      whereArgs: [customerId],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    
    return await Future.wait(maps.map((map) async {
      final items = await _getTransactionItems(db, map['id']);
      return AppTransaction.fromMap(map, items: items);
    }));
  }

  Future<List<AppTransaction>> getAllTransactions({int limit = 10, int offset = 0}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'is_void = 0',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    
    return await Future.wait(maps.map((map) async {
      final items = await _getTransactionItems(db, map['id']);
      return AppTransaction.fromMap(map, items: items);
    }));
  }

  Future<List<TransactionItem>> _getTransactionItems(dynamic db, int transactionId) async {
    final List<Map<String, dynamic>> itemMaps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return itemMaps.map((m) => TransactionItem.fromMap(m)).toList();
  }

  Future<Map<String, double>> getDashboardSummary() async {
    final db = await _dbHelper.database;
    
    // Get daily sales (cash + debts from today) - Split by currency
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    
    Future<double> getDaily(String curr) async {
      final res = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE date >= ? AND type = 'sale' AND is_void = 0 AND currency = ?",
        [todayStart, curr]
      );
      return (res.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Get total debt from all customers
    final List<Map<String, dynamic>> debtResultYer = await db.rawQuery(
      "SELECT SUM(total_debt) as total FROM customers"
    );

    return {
      'daily_sales_yer': await getDaily('YER'),
      'total_debt_yer': (debtResultYer.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Void a transaction (soft delete) - reverses all effects
  Future<void> voidTransaction(AppTransaction transaction) async {
    if (transaction.isVoid) {
      throw Exception('Transaction already voided');
    }

    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Reverse stock for each item
      if (transaction.type == TransactionType.sale || transaction.type == TransactionType.refund) {
        final items = await _getTransactionItems(txn, transaction.id!);
        for (final item in items) {
          if (transaction.type == TransactionType.sale) {
            // Restore stock (it was deducted)
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [item.quantity, item.productId]
            );
          } else if (transaction.type == TransactionType.refund) {
            // Deduct stock (it was restored during refund)
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [item.quantity, item.productId]
            );
          }
        }
      }

      // 2. Reverse customer balance
      if (transaction.customerId != null) {
        double debtChange = 0.0;
        
        if (transaction.type == TransactionType.sale) {
          // Reverse the debt that was added
          final remainingDebt = transaction.amount - transaction.paidAmount;
          debtChange = -remainingDebt;
        } else if (transaction.type == TransactionType.payment) {
          // Reverse the payment (add debt back). Payment is positive.
          debtChange = transaction.amount;
        } else if (transaction.type == TransactionType.refund) {
          // Reverse the refund (add debt back). 
          // If refund amount is negative (e.g., -500), 
          // then subtracting it will add debt back.
          debtChange = -transaction.amount;
        }
        
        if (debtChange != 0 || transaction.type == TransactionType.sale || transaction.type == TransactionType.refund) {
          await _customerService.updateCustomerStats(
            id: transaction.customerId!,
            debtChange: debtChange,
            date: DateTime.now(),
            totalSpentChange: transaction.type == TransactionType.sale 
                ? -transaction.amount 
                : (transaction.type == TransactionType.refund ? -transaction.amount : 0.0),
            executor: txn,
          );
        }
      }

      // 3. Mark as void (don't physically delete)
      await txn.update(
        'transactions',
        {'is_void': 1},
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    });
  }

  /// Process a refund/return transaction
  Future<int> processRefund({
    required AppTransaction originalTransaction,
    required List<TransactionItem> itemsToRefund,
    int? customerId,
    String note = '',
  }) async {
    if (originalTransaction.type != TransactionType.sale) {
      throw Exception('Can only refund sale transactions');
    }

    // Calculate refund amount
    final refundAmount = itemsToRefund.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    if (refundAmount <= 0) {
      throw Exception('Refund amount must be greater than 0');
    }

    final refundTransaction = AppTransaction(
      customerId: customerId ?? originalTransaction.customerId,
      type: TransactionType.refund,
      amount: -refundAmount, // Store as NEGATIVE transaction
      currency: originalTransaction.currency,
      date: DateTime.now(),
      note: note.isEmpty ? 'Refund for transaction #${originalTransaction.id}' : 'Refund: $note',
      items: itemsToRefund,
    );

    return await addTransaction(refundTransaction);
  }
}
