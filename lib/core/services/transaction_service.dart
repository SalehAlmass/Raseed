import '../models/app_transaction.dart';
import '../models/transaction_item.dart';
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

    // 3. Check for debt limit if it's a sale transaction with remaining debt
    if (transaction.type == TransactionType.sale && transaction.customerId != null) {
      final settings = await _settingsService.getSettings();
      final customerMap = await db.query(
        'customers', 
        where: 'id = ?', 
        whereArgs: [transaction.customerId],
      ).then((maps) => maps.first);
      
      final currentDebt = (customerMap['total_debt'] as num).toDouble();
      final remainingDebt = transaction.amount - transaction.paidAmount;
      
      if (settings.strictMode && (currentDebt + remainingDebt) > settings.maxDebt) {
        throw Exception('over_limit');
      }
    }

    return await db.transaction((txn) async {
      // 1. Insert transaction
      final int transactionId = await txn.insert('transactions', transaction.toMap());

      // 2. Insert items and reduce stock (only for sales)
      if (transaction.type == TransactionType.sale && transaction.items.isNotEmpty) {
        for (final item in transaction.items) {
          await txn.insert('transaction_items', item.toMap()..['transaction_id'] = transactionId);
          
          // Deduct stock
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId]
          );
        }
      }

      // 3. Update customer debt if applicable
      if (transaction.customerId != null) {
        double debtChange = 0.0;
        
        if (transaction.type == TransactionType.payment) {
          // Payment reduces debt
          debtChange = -transaction.amount;
        } else if (transaction.type == TransactionType.sale) {
          // Sale adds remaining debt (amount - paid)
          final remainingDebt = transaction.amount - transaction.paidAmount;
          debtChange = remainingDebt;
        } else if (transaction.type == TransactionType.refund) {
          // Refund reduces debt
          debtChange = -transaction.amount;
        }

        if (debtChange != 0) {
          await _customerService.updateCustomerDebt(
            transaction.customerId!,
            debtChange,
            transaction.currency,
            transaction.date,
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
    
    final List<AppTransaction> transactions = [];
    for (final map in maps) {
      final items = await _getTransactionItems(db, map['id']);
      transactions.add(AppTransaction.fromMap(map, items: items));
    }
    return transactions;
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
    
    final List<AppTransaction> transactions = [];
    for (final map in maps) {
      final items = await _getTransactionItems(db, map['id']);
      transactions.add(AppTransaction.fromMap(map, items: items));
    }
    return transactions;
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
        "SELECT SUM(amount) as total FROM transactions WHERE date >= ? AND type IN ('cash', 'debt') AND currency = ?",
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
      // 1. Reverse stock for each item (only for sales)
      if (transaction.type == TransactionType.sale) {
        final items = await _getTransactionItems(txn, transaction.id!);
        for (final item in items) {
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item.quantity, item.productId]
          );
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
          // Reverse the payment (add debt back)
          debtChange = transaction.amount;
        } else if (transaction.type == TransactionType.refund) {
          // Reverse the refund (add debt back)
          debtChange = transaction.amount;
        }
        
        if (debtChange != 0) {
          await _customerService.updateCustomerDebt(
            transaction.customerId!,
            debtChange,
            transaction.currency,
            DateTime.now(),
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
      amount: refundAmount,
      currency: originalTransaction.currency,
      date: DateTime.now(),
      note: note.isEmpty ? 'Refund for transaction #${originalTransaction.id}' : 'Refund: $note',
      items: itemsToRefund,
    );

    return await addTransaction(refundTransaction);
  }
}
