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
    
    final totalCustomers = (await db.rawQuery("SELECT COUNT(*) as count FROM customers")).first['count'] as int;
    final debtorsCount = (await db.rawQuery("SELECT COUNT(*) as count FROM customers WHERE total_debt > 0")).first['count'] as int;
    final totalDebtSum = (await db.rawQuery("SELECT SUM(total_debt) as sum FROM customers")).first['sum'] as double? ?? 0.0;
    
    // Active customers (last transaction within 7 days)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final activeCount = (await db.rawQuery("SELECT COUNT(*) as count FROM customers WHERE last_transaction_date >= ?", [sevenDaysAgo])).first['count'] as int;

    return {
      'total_customers': totalCustomers,
      'debtors_count': debtorsCount,
      'total_debt_sum': totalDebtSum,
      'active_count': activeCount,
    };
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
