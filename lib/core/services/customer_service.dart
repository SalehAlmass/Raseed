import 'package:sqflite/sqflite.dart';
import '../models/customer.dart';
import 'database_helper.dart';

class CustomerService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> createCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<Map<String, dynamic>> getCustomerAnalytics() async {
    final db = await _dbHelper.database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_customers,
        SUM(CASE WHEN total_debt > 0 THEN 1 ELSE 0 END) as debtors_count,
        SUM(total_debt) as total_debt_sum,
        SUM(CASE WHEN last_transaction_date >= ? THEN 1 ELSE 0 END) as active_count
      FROM customers
    ''', [sevenDaysAgo]);

    final row = results.first;
    return {
      'total_customers': row['total_customers'] ?? 0,
      'debtors_count': row['debtors_count'] ?? 0,
      'total_debt_sum': (row['total_debt_sum'] as num?)?.toDouble() ?? 0.0,
      'active_count': row['active_count'] ?? 0,
    };
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

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<Customer?> getCustomer(int id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> updateCustomerStats({
    required int id, 
    required double debtChange, 
    required DateTime date, 
    double totalSpentChange = 0.0,
    DatabaseExecutor? executor
  }) async {
    final db = executor ?? await _dbHelper.database;
    final customer = await getCustomer(id, executor: executor);
    if (customer == null) return;

    final double newDebt = customer.totalDebt + debtChange;
    final double newSpent = customer.totalSpent + totalSpentChange;

    await db.update(
      'customers',
      {
        'total_debt': newDebt,
        'total_spent': newSpent,
        'last_transaction_date': date.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
