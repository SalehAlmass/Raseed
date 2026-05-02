import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/report_models.dart';
import '../services/report_service.dart';

class AccountingInsightsScreen extends StatefulWidget {
  const AccountingInsightsScreen({super.key});

  @override
  State<AccountingInsightsScreen> createState() => _AccountingInsightsScreenState();
}

class _AccountingInsightsScreenState extends State<AccountingInsightsScreen> {
  final _reportService = sl<ReportService>();
  DashboardReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final filter = ReportFilter(
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime.now(),
    );
    final report = await _reportService.getDashboardReport(filter);
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('accounting_insights'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfitCard(),
                  const SizedBox(height: 20),
                  _buildMetricRow(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('top_profitable_products'.tr()),
                  _buildProductPerformance(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('dead_stock_alert'.tr()),
                  _buildDeadStockList(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfitCard() {
    final profit = _report?.totalProfit ?? 0.0;
    final isPositive = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPositive ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Column(
        children: [
          Text('net_profit'.tr(), style: TextStyle(color: isPositive ? Colors.green.shade700 : Colors.red.shade700)),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(profit)} YER',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text('current_month'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMetricRow() {
    return Row(
      children: [
        _buildMetricItem('total_sales'.tr(), _report?.totalSales ?? 0.0, Colors.blue),
        const SizedBox(width: 12),
        _buildMetricItem('inventory_value'.tr(), _report?.inventoryValue ?? 0.0, Colors.purple),
      ],
    );
  }

  Widget _buildMetricItem(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              NumberFormat.compact().format(value),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProductPerformance() {
    final performance = _report?.productPerformance ?? [];
    if (performance.isEmpty) return Center(child: Text('no_data'.tr()));

    return Column(
      children: performance.take(5).map((p) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(p.productName),
          subtitle: Text('sold'.tr() + ': ${p.soldCount}'),
          trailing: Text(
            '+${NumberFormat.compact().format(p.netProfit)}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDeadStockList() {
    final deadStock = _report?.deadStock ?? [];
    if (deadStock.isEmpty) return Center(child: Text('no_dead_stock'.tr()));

    return Column(
      children: deadStock.take(5).map((d) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.warning_amber, color: Colors.orange),
          title: Text(d.name),
          subtitle: Text('days_since_last_sale'.tr() + ': ${d.daysSinceLastSale}'),
          trailing: Text('stock'.tr() + ': ${d.remainingStock}'),
        ),
      )).toList(),
    );
  }
}
