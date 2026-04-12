
import 'package:intl/intl.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/models/report_models.dart';
import '../../../core/models/app_transaction.dart';

class ReportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<DashboardReport> getDashboardReport(ReportFilter filter) async {
    final db = await _dbHelper.database;
    final start = filter.startDate.toIso8601String();
    final end = filter.endDate.toIso8601String();
    final currency = filter.currency ?? 'YER';

    // 1. Total Sales
    final salesRes = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE type = ? AND is_void = 0 AND currency = ? AND date BETWEEN ? AND ?
    ''', [TransactionType.sale.name, currency, start, end]);
    final totalSales = (salesRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Total Profit
    final profitRes = await db.rawQuery('''
      SELECT SUM(ti.quantity * (ti.price - ti.cost_price)) as total
      FROM transactions t
      JOIN transaction_items ti ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
    ''', [TransactionType.sale.name, currency, start, end]);
    final totalProfit = (profitRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Total Current Debt
    final debtRes = await db.rawQuery('SELECT SUM(total_debt) as total FROM customers');
    final totalDebt = (debtRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Sales Trend
    String groupBy;
    String format;
    if (filter.period == ReportPeriod.daily) {
      groupBy = "strftime('%Y-%m-%d', date)";
      format = "yyyy-MM-dd";
    } else if (filter.period == ReportPeriod.monthly) {
      groupBy = "strftime('%Y-%m', date)";
      format = "yyyy-MM";
    } else {
      groupBy = "strftime('%Y', date)";
      format = "yyyy";
    }

    final trendRes = await db.rawQuery('''
      SELECT $groupBy as label, SUM(amount) as value
      FROM transactions
      WHERE type = ? AND is_void = 0 AND currency = ? AND date BETWEEN ? AND ?
      GROUP BY label
      ORDER BY label ASC
    ''', [TransactionType.sale.name, currency, start, end]);

    final salesTrend = trendRes.map((r) {
      final label = r['label'] as String;
      DateTime? dt;
      try {
        if (filter.period == ReportPeriod.daily) dt = DateTime.parse(label);
        if (filter.period == ReportPeriod.monthly) dt = DateTime.parse("$label-01");
        if (filter.period == ReportPeriod.yearly) dt = DateTime.parse("$label-01-01");
      } catch (_) {}
      
      return ReportMetric(
        label: label,
        value: (r['value'] as num?)?.toDouble() ?? 0.0,
        date: dt,
      );
    }).toList();

    // 5. Top Products
    final productRes = await db.rawQuery('''
      SELECT product_name as label, SUM(quantity * price) as value
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
      GROUP BY product_id
      ORDER BY value DESC
      LIMIT 5
    ''', [TransactionType.sale.name, currency, start, end]);

    final topProducts = productRes.map((r) => ReportMetric(
      label: r['label'] as String,
      value: (r['value'] as num?)?.toDouble() ?? 0.0,
    )).toList();

    // 6. Top Customers
    final customerRes = await db.rawQuery('''
      SELECT c.name as label, SUM(t.amount) as value
      FROM transactions t
      JOIN customers c ON c.id = t.customer_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
      GROUP BY t.customer_id
      ORDER BY value DESC
      LIMIT 5
    ''', [TransactionType.sale.name, currency, start, end]);

    final topCustomers = customerRes.map((r) => ReportMetric(
      label: r['label'] as String,
      value: (r['value'] as num?)?.toDouble() ?? 0.0,
    )).toList();

    return DashboardReport(
      totalSales: totalSales,
      totalProfit: totalProfit,
      totalDebt: totalDebt,
      salesTrend: salesTrend,
      topProducts: topProducts,
      topCustomers: topCustomers,
    );
  }
}
