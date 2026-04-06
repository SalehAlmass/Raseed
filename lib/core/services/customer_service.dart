import '../models/customer.dart';
import 'database_helper.dart';

class CustomerService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> createCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
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

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<Customer?> getCustomer(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> updateCustomerDebt(int id, double amountChange, String currency, DateTime date) async {
    final db = await _dbHelper.database;
    final customer = await getCustomer(id);
    if (customer == null) return;

    final String column = currency == 'SAR' ? 'total_debt_sar' : 'total_debt';
    final double currentDebt = currency == 'SAR' ? customer.totalDebtSar : customer.totalDebt;
    final double newDebt = currentDebt + amountChange;

    await db.update(
      'customers',
      {
        column: newDebt,
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
