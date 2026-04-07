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

    // Check for debt limit if it's a debt transaction
    if (transaction.type == TransactionType.debt && transaction.customerId != null) {
      final settings = await _settingsService.getSettings();
      final customerMap = await db.query(
        'customers', 
        where: 'id = ?', 
        whereArgs: [transaction.customerId],
      ).then((maps) => maps.first);
      
      const String debtColumn = 'total_debt';
      final currentDebt = (customerMap[debtColumn] as num).toDouble();
      
      if (settings.strictMode && (currentDebt + transaction.amount) > settings.maxDebt) {
        throw Exception('over_limit');
      }
    }

    return await db.transaction((txn) async {
      // 1. Insert transaction
      final int transactionId = await txn.insert('transactions', transaction.toMap());

      // 2. Insert items and reduce stock
      for (final item in transaction.items) {
        await txn.insert('transaction_items', item.toMap()..['transaction_id'] = transactionId);
        
        // Deduct stock
        await txn.execute(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.productId]
        );
      }

      // 3. Update customer debt if applicable
      if (transaction.customerId != null) {
        double debtChange = 0.0;
        if (transaction.type == TransactionType.debt) {
          debtChange = transaction.amount;
        } else if (transaction.type == TransactionType.payment) {
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

  Future<List<AppTransaction>> getCustomerTransactions(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    
    final List<AppTransaction> transactions = [];
    for (final map in maps) {
      final items = await _getTransactionItems(db, map['id']);
      transactions.add(AppTransaction.fromMap(map, items: items));
    }
    return transactions;
  }

  Future<List<AppTransaction>> getAllTransactions({int limit = 10}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
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

  Future<int> deleteTransaction(AppTransaction transaction) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 1. Reverse stock for each item
      final items = await _getTransactionItems(txn, transaction.id!);
      for (final item in items) {
        await txn.execute(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.productId]
        );
      }

      // 2. Reverse customer balance
      if (transaction.customerId != null) {
        double debtChange = 0.0;
        if (transaction.type == TransactionType.debt) {
          debtChange = -transaction.amount;
        } else if (transaction.type == TransactionType.payment) {
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

      // 3. Delete transaction (cascades to items)
      return await txn.delete('transactions', where: 'id = ?', whereArgs: [transaction.id]);
    });
  }
}
