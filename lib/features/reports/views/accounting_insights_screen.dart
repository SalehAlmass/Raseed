import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/report_models.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';
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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'accounting_insights'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
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
          );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DesktopMetrics.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: 'accounting_insights'.tr()),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopMetricCards(),
              const SizedBox(height: AppSpace.xxl),
              _buildSectionTitle('top_profitable_products'.tr()),
              const SizedBox(height: AppSpace.sm),
              _buildDesktopProductPerformance(),
              const SizedBox(height: AppSpace.xxl),
              _buildSectionTitle('dead_stock_alert'.tr()),
              const SizedBox(height: AppSpace.sm),
              _buildDesktopDeadStock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopMetricCards() {
    final profit = _report?.totalProfit ?? 0.0;
    final isPositive = profit >= 0;
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'net_profit'.tr(),
          value:
              '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(profit)} YER',
          subtitle: 'current_month'.tr(),
          icon: Icons.trending_up_rounded,
          color: isPositive ? AppColors.success : AppColors.error,
        ),
        StatCard(
          title: 'total_sales'.tr(),
          value: NumberFormat.compact().format(_report?.totalSales ?? 0.0),
          icon: Icons.point_of_sale_rounded,
          color: Colors.blue,
        ),
        StatCard(
          title: 'inventory_value'.tr(),
          value: NumberFormat.compact().format(_report?.inventoryValue ?? 0.0),
          icon: Icons.inventory_2_rounded,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildDesktopProductPerformance() {
    final performance = _report?.productPerformance ?? [];
    final rows = performance.take(5).map((p) {
      return <Widget>[
        Text(
          p.productName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          '${'sold'.tr()}: ${p.soldCount}',
          style: const TextStyle(fontSize: 12),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '+${NumberFormat.compact().format(p.netProfit)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'product_name'.tr(),
        'sold'.tr(),
        'net_profit'.tr(),
      ],
      flexes: const [4, 2, 2],
      rows: rows,
      emptyMessage: 'no_data'.tr(),
      isLoading: _isLoading,
    );
  }

  Widget _buildDesktopDeadStock() {
    final deadStock = _report?.deadStock ?? [];
    final rows = deadStock.take(5).map((d) {
      return <Widget>[
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                d.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Text(
          '${'days_since_last_sale'.tr()}: ${d.daysSinceLastSale}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '${'stock'.tr()}: ${d.remainingStock}',
          style: const TextStyle(fontSize: 12),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'name'.tr(),
        'days_since_last_sale'.tr(),
        'stock'.tr(),
      ],
      flexes: const [4, 2, 2],
      rows: rows,
      emptyMessage: 'no_dead_stock'.tr(),
      isLoading: _isLoading,
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.customers);
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 3:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.viewReports)) {
          Navigator.pushReplacementNamed(context, Routes.reports);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 4:
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
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
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              NumberFormat.compact().format(value),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8)),
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
          subtitle: Text('${'sold'.tr()}: ${p.soldCount}'),
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
          subtitle: Text('${'days_since_last_sale'.tr()}: ${d.daysSinceLastSale}'),
          trailing: Text('${'stock'.tr()}: ${d.remainingStock}'),
        ),
      )).toList(),
    );
  }
}
