
import 'package:intl/intl.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/models/report_models.dart';
import '../../../core/models/app_transaction.dart';
import 'report_engine.dart';

class ReportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<DashboardReport> getDashboardReport(ReportFilter filter) async {
    final db = await _dbHelper.database;
    final start = filter.startDate.toIso8601String();
    final end = filter.endDate.toIso8601String();
    final currency = filter.currency ?? 'YER';

    // 1. Current Stats
    final currentSales = await _getTotalSales(db, start, end, currency);
    final currentProfit = await _getTotalProfit(db, start, end, currency);
    final totalDebt = await _getTotalDebt(db);
    final invValue = await getInventoryValue();

    // 2. Previous Period for Comparison
    final duration = filter.endDate.difference(filter.startDate);
    final prevEnd = filter.startDate.subtract(const Duration(seconds: 1));
    final prevStart = prevEnd.subtract(duration);
    
    final prevSales = await _getTotalSales(db, prevStart.toIso8601String(), prevEnd.toIso8601String(), currency);
    final growth = ReportEngine.calculateGrowth(currentSales, prevSales);

    // 3. Trends & Peaks
    final salesTrend = await _getSalesTrend(db, filter, start, end, currency);
    final dailyStats = ReportEngine.calculateDailyStats(salesTrend);

    // 4. Products & Customers
    final topProducts = await _getTopProducts(db, start, end, currency);
    final topCustomers = await _getTopCustomers(db, start, end, currency);
    final performance = await getProductPerformance(filter);
    final deadItems = await getDeadStock(90); // Default 90 days

    // 5. Debt Movements
    final debtMov = await getDebtMovement(filter);

    final report = DashboardReport(
      totalSales: currentSales,
      totalProfit: currentProfit,
      totalDebt: totalDebt,
      inventoryValue: invValue,
      salesGrowth: growth,
      previousSales: prevSales,
      dailyStats: dailyStats,
      insights: [], // Will be generated below
      salesTrend: salesTrend,
      topProducts: topProducts,
      topCustomers: topCustomers,
      deadStock: deadItems,
      debtMovement: debtMov,
      productPerformance: performance,
    );

    // Generate Insights
    return report.copyWithInsights(ReportEngine.generateInsights(report));
  }

  Future<double> _getTotalSales(dynamic db, String start, String end, String currency) async {
    final res = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = ? AND is_void = 0 AND currency = ? AND date BETWEEN ? AND ?
    ''', [TransactionType.sale.name, currency, start, end]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> _getTotalProfit(dynamic db, String start, String end, String currency) async {
    final res = await db.rawQuery('''
      SELECT SUM(ti.quantity * (ti.price - ti.cost_price)) as total
      FROM transactions t
      JOIN transaction_items ti ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
    ''', [TransactionType.sale.name, currency, start, end]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> _getTotalDebt(dynamic db) async {
    final res = await db.rawQuery('SELECT SUM(total_debt) as total FROM customers');
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<ReportMetric>> _getSalesTrend(dynamic db, ReportFilter filter, String start, String end, String currency) async {
    String groupBy = filter.period == ReportPeriod.daily ? "strftime('%Y-%m-%d', date)" : "strftime('%Y-%m', date)";
    
    final trendRes = await db.rawQuery('''
      SELECT $groupBy as label, SUM(amount) as value, SUM(amount - COALESCE((SELECT SUM(ti.quantity * ti.cost_price) FROM transaction_items ti WHERE ti.transaction_id = transactions.id), 0)) as profit
      FROM transactions
      WHERE type = ? AND is_void = 0 AND currency = ? AND date BETWEEN ? AND ?
      GROUP BY label ORDER BY label ASC
    ''', [TransactionType.sale.name, currency, start, end]);

    return trendRes.map<ReportMetric>((r) => ReportMetric(
      label: r['label'] as String,
      value: (r['value'] as num?)?.toDouble() ?? 0.0,
      secondaryValue: (r['profit'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(r['label'] as String),
    )).toList();
  }

  Future<List<ReportMetric>> _getTopProducts(dynamic db, String start, String end, String currency) async {
    final res = await db.rawQuery('''
      SELECT product_name as label, SUM(quantity * price) as value
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
      GROUP BY product_id ORDER BY value DESC LIMIT 5
    ''', [TransactionType.sale.name, currency, start, end]);
    return res.map<ReportMetric>((r) => ReportMetric(label: r['label'] as String, value: (r['value'] as num?)?.toDouble() ?? 0.0)).toList();
  }

  Future<List<ReportMetric>> _getTopCustomers(dynamic db, String start, String end, String currency) async {
    final res = await db.rawQuery('''
      SELECT c.name as label, SUM(t.amount) as value
      FROM transactions t JOIN customers c ON c.id = t.customer_id
      WHERE t.type = ? AND t.is_void = 0 AND t.currency = ? AND t.date BETWEEN ? AND ?
      GROUP BY t.customer_id ORDER BY value DESC LIMIT 5
    ''', [TransactionType.sale.name, currency, start, end]);
    return res.map<ReportMetric>((r) => ReportMetric(label: r['label'] as String, value: (r['value'] as num?)?.toDouble() ?? 0.0)).toList();
  }

  Future<double> getInventoryValue() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery("SELECT SUM(quantity * cost_price) as total FROM product_batches");
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<DeadStockItem>> getDeadStock(int days) async {
    final db = await _dbHelper.database;
    final dateLimit = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final res = await db.rawQuery('''
      SELECT p.id, p.name, p.stock_quantity, 
      (SELECT MAX(t.date) FROM transactions t JOIN transaction_items ti ON t.id = ti.transaction_id WHERE ti.product_id = p.id) as last_sale
      FROM products p
      WHERE last_sale IS NULL OR last_sale < ?
      AND p.stock_quantity > 0
      ORDER BY last_sale ASC
    ''', [dateLimit]);

    return res.map((r) {
      final lastSale = r['last_sale'] != null ? DateTime.parse(r['last_sale'] as String) : null;
      final diff = lastSale != null ? DateTime.now().difference(lastSale).inDays : 999;
      return DeadStockItem(
        productId: r['id'] as int,
        name: r['name'] as String,
        daysSinceLastSale: diff,
        remainingStock: r['stock_quantity'] as int,
      );
    }).toList();
  }

  Future<DebtMovement> getDebtMovement(ReportFilter filter) async {
    final db = await _dbHelper.database;
    final start = filter.startDate.toIso8601String();
    final end = filter.endDate.toIso8601String();

    final newDebtRes = await db.rawQuery('''
      SELECT SUM(amount - paid_amount) as total FROM transactions 
      WHERE type = 'sale' AND is_void = 0 AND date BETWEEN ? AND ?
    ''', [start, end]);

    final collectedRes = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'payment' AND is_void = 0 AND date BETWEEN ? AND ?
    ''', [start, end]);

    final totalCurrent = await _getTotalDebt(db);

    return DebtMovement(
      totalCurrent: totalCurrent,
      newDebt: (newDebtRes.first['total'] as num?)?.toDouble() ?? 0.0,
      collectedDebt: (collectedRes.first['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<List<ProductProfitItem>> getProductPerformance(ReportFilter filter) async {
    final db = await _dbHelper.database;
    final start = filter.startDate.toIso8601String();
    final end = filter.endDate.toIso8601String();

    final res = await db.rawQuery('''
      SELECT product_name, SUM(quantity * price) as revenue, SUM(quantity * cost_price) as cost, SUM(quantity) as count
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.type = 'sale' AND t.is_void = 0 AND t.date BETWEEN ? AND ?
      GROUP BY product_id
      ORDER BY (revenue - cost) DESC
    ''', [start, end]);

    return res.map((r) => ProductProfitItem(
      productName: r['product_name'] as String,
      totalRevenue: (r['revenue'] as num?)?.toDouble() ?? 0.0,
      totalCost: (r['cost'] as num?)?.toDouble() ?? 0.0,
      netProfit: ((r['revenue'] as num) - (r['cost'] as num)).toDouble(),
      soldCount: (r['count'] as num).toInt(),
    )).toList();
  }

  Future<List<Map<String, dynamic>>> getLowStockBySupplier(int supplierId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT id, name, stock_quantity, reorder_level
      FROM products
      WHERE supplier_id = ? AND stock_quantity <= reorder_level
      ORDER BY stock_quantity ASC
    ''', [supplierId]);
  }
}

extension ReportInsightsExtension on DashboardReport {
  DashboardReport copyWithInsights(List<String> insights) {
    return DashboardReport(
      totalSales: totalSales,
      totalProfit: totalProfit,
      totalDebt: totalDebt,
      inventoryValue: inventoryValue,
      salesGrowth: salesGrowth,
      previousSales: previousSales,
      dailyStats: dailyStats,
      insights: insights,
      salesTrend: salesTrend,
      topProducts: topProducts,
      topCustomers: topCustomers,
      deadStock: deadStock,
      debtMovement: debtMovement,
      productPerformance: productPerformance,
    );
  }
}
