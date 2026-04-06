import '../models/app_transaction.dart';
import 'database_helper.dart';
import 'customer_service.dart';
import 'settings_service.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CustomerService _customerService;
  final SettingsService _settingsService;

  TransactionService(this._customerService, this._settingsService);

  Future<int> addTransaction(AppTransaction transaction) async {
    // Check for debt limit if it's a debt transaction
    if (transaction.type == TransactionType.debt && transaction.customerId != null) {
      final settings = await _settingsService.getSettings();
      final customerMap = await _dbHelper.database.then((db) => db.query(
        'customers', 
        where: 'id = ?', 
        whereArgs: [transaction.customerId],
      )).then((maps) => maps.first);
      
      final String debtColumn = transaction.currency == 'SAR' ? 'total_debt_sar' : 'total_debt';
      final currentDebt = (customerMap[debtColumn] as num).toDouble();
      
      if (settings.strictMode && (currentDebt + transaction.amount) > settings.maxDebt) {
        throw Exception('over_limit');
      }
    }

    final db = await _dbHelper.database;
    final int id = await db.insert('transactions', transaction.toMap());

    // Update customer debt if applicable
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

    return id;
  }

  Future<List<AppTransaction>> getCustomerTransactions(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => AppTransaction.fromMap(maps[i]));
  }

  Future<List<AppTransaction>> getAllTransactions({int limit = 10}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => AppTransaction.fromMap(maps[i]));
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

    // Get total debt from all customers - Split by currency
    final List<Map<String, dynamic>> debtResultYer = await db.rawQuery(
      "SELECT SUM(total_debt) as total FROM customers"
    );
    final List<Map<String, dynamic>> debtResultSar = await db.rawQuery(
      "SELECT SUM(total_debt_sar) as total FROM customers"
    );

    return {
      'daily_sales_yer': await getDaily('YER'),
      'daily_sales_sar': await getDaily('SAR'),
      'total_debt_yer': (debtResultYer.first['total'] as num?)?.toDouble() ?? 0.0,
      'total_debt_sar': (debtResultSar.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<int> deleteTransaction(AppTransaction transaction) async {
    final db = await _dbHelper.database;
    
    // If it was a debt or payment, reverse the customer's balance
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
    
    return await db.delete('transactions', where: 'id = ?', whereArgs: [transaction.id]);
  }
}
