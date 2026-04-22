import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../../core/models/report_models.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../services/export_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/models/app_feature.dart';
import '../../../../core/widgets/subscription_dialog.dart';
import 'widgets/report_charts.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  late ReportFilter _filter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filter = ReportFilter(
      startDate: DateTime(now.year, now.month, 1),
      endDate: now,
      period: ReportPeriod.monthly,
      currency: 'YER',
    );
    context.read<ReportsBloc>().add(LoadReportsEvent(_filter));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'reports'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _handleExport(context, 'pdf'),
          ),
          IconButton(
            icon: const Icon(Icons.explicit_outlined), // Placeholder for Excel
            onPressed: () => _handleExport(context, 'excel'),
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ReportsError) {
            return Center(child: Text(state.message));
          }
          if (state is ReportsLoaded) {
            return _buildDashboard(state.report);
          }
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        activeIndex: 3,
        onTap: _onNavTap,
      ),
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
          Navigator.pushNamed(context, Routes.sale).then((result) {
            if (result == true) {
              context.read<ReportsBloc>().add(LoadReportsEvent(_filter));
            }
          });
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
  }

  void _handleExport(BuildContext context, String type) async {
    final state = context.read<ReportsBloc>().state;
    if (state is ReportsLoaded) {
      if (type == 'pdf') {
        await sl<ExportService>().exportToPdf(state.report, state.filter);
      } else {
        await sl<ExportService>().exportToExcel(state.report, state.filter);
      }
    }
  }

  Widget _buildDashboard(DashboardReport report) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20.h),
          //_buildInsightsSection(report),
          //SizedBox(height: 25.h),
          _buildSummaryCards(report),
          SizedBox(height: 25.h),
          _buildInventoryCard(report),
          SizedBox(height: 30.h),
          _buildSectionHeader('sales_trend'.tr()),
          SizedBox(height: 15.h),
          Container(
            height: 250.h,
            padding: EdgeInsets.all(16.w),
            decoration: _cardDecoration(),
            child: SalesTrendChart(trend: report.salesTrend),
          ),
          SizedBox(height: 30.h),
          _buildSectionHeader('top_products'.tr()),
          SizedBox(height: 15.h),
          Container(
            height: 250.h,
            padding: EdgeInsets.all(16.w),
            decoration: _cardDecoration(),
            child: TopProductsChart(products: report.topProducts),
          ),
          SizedBox(height: 30.h),
          _buildSectionHeader('product_performance'.tr()),
          SizedBox(height: 15.h),
          _buildPerformanceList(report.productPerformance),
          SizedBox(height: 30.h),
          _buildSectionHeader('dead_stock'.tr()),
          SizedBox(height: 15.h),
          _buildDeadStockList(report.deadStock),
          SizedBox(height: 30.h),
          _buildSectionHeader('top_customers'.tr()),
          SizedBox(height: 15.h),
          _buildCustomerList(report.topCustomers),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(DashboardReport report) {
    if (report.insights.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: report.insights
            .map(
              (insight) => ListTile(
                dense: true,
                leading: Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
                title: Text(
                  insight,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInventoryCard(DashboardReport report) {
    return _metricCard(
      'inventory_value'.tr(),
      report.inventoryValue,
      Colors.blueGrey,
      Icons.warehouse_outlined,
      fullWidth: true,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _filterChip('daily'.tr(), ReportPeriod.daily),
          _filterChip('monthly'.tr(), ReportPeriod.monthly),
          _filterChip('yearly'.tr(), ReportPeriod.yearly),
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.primary),
            onPressed: () => _selectCustomDate(context),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ReportPeriod period) {
    final isSelected = _filter.period == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          final now = DateTime.now();
          DateTime start;
          if (period == ReportPeriod.daily)
            start = DateTime(now.year, now.month, now.day);
          else if (period == ReportPeriod.monthly)
            start = DateTime(now.year, now.month, 1);
          else
            start = DateTime(now.year, 1, 1);

          setState(() {
            _filter = _filter.copyWith(
              period: period,
              startDate: start,
              endDate: now,
            );
          });
          context.read<ReportsBloc>().add(LoadReportsEvent(_filter));
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _filter.startDate,
        end: _filter.endDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _filter = _filter.copyWith(
          startDate: picked.start,
          endDate: picked.end,
          period: ReportPeriod.custom,
        );
      });
      context.read<ReportsBloc>().add(LoadReportsEvent(_filter));
    }
  }

  Widget _buildSummaryCards(DashboardReport report) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'total_sales'.tr(),
                report.totalSales,
                AppColors.success,
                Icons.trending_up,
                growth: report.salesGrowth,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _metricCard(
                'net_income'.tr(),
                report.totalProfit,
                AppColors.info,
                Icons.payments_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        _metricCard(
          'total_debt'.tr(),
          report.totalDebt,
          AppColors.error,
          Icons.account_balance_wallet,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _metricCard(
    String title,
    double value,
    Color color,
    IconData icon, {
    bool fullWidth = false,
    double? growth,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(16.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (growth != null)
                Row(
                  children: [
                    Icon(
                      growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: growth >= 0 ? AppColors.success : AppColors.error,
                      size: 14.sp,
                    ),
                    Text(
                      '${growth.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: growth >= 0
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            CurrencyHelper.getFormatter(
              _filter.currency ?? 'YER',
            ).format(value),
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCustomerList(List<ReportMetric> customers) {
    return Container(
      decoration: _cardDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: customers.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = customers[index];
          return ListTile(
            title: Text(
              c.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Text(
              CurrencyHelper.getFormatter(
                _filter.currency ?? 'YER',
              ).format(c.value),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceList(List<ProductProfitItem> performance) {
    return Container(
      decoration: _cardDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: performance.length > 10 ? 10 : performance.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = performance[index];
          return ListTile(
            title: Text(
              p.productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${'sold'.tr()}: ${p.soldCount}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyHelper.getFormatter(
                    _filter.currency ?? 'YER',
                  ).format(p.netProfit),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'profit'.tr(),
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeadStockList(List<DeadStockItem> deadStock) {
    if (deadStock.isEmpty) return Center(child: Text('no_dead_stock'.tr()));
    return Container(
      decoration: _cardDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: deadStock.length > 5 ? 5 : deadStock.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = deadStock[index];
          return ListTile(
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${'stock'.tr()}: ${p.remainingStock}'),
            trailing: Text(
              '${p.daysSinceLastSale} ${'days_ago'.tr()}',
              style: TextStyle(color: AppColors.error, fontSize: 12.sp),
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
