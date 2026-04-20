
import 'package:equatable/equatable.dart';

enum ReportPeriod { daily, monthly, yearly, custom }

class ReportFilter extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final ReportPeriod period;
  final int? customerId;
  final String? currency;

  const ReportFilter({
    required this.startDate,
    required this.endDate,
    this.period = ReportPeriod.monthly,
    this.customerId,
    this.currency,
  });

  @override
  List<Object?> get props => [startDate, endDate, period, customerId, currency];

  ReportFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ReportPeriod? period,
    int? customerId,
    String? currency,
  }) {
    return ReportFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      period: period ?? this.period,
      customerId: customerId ?? this.customerId,
      currency: currency ?? this.currency,
    );
  }
}

class ReportMetric {
  final String label;
  final double value;
  final double? secondaryValue; 
  final DateTime? date;

  ReportMetric({
    required this.label,
    required this.value,
    this.secondaryValue,
    this.date,
  });
}

class DashboardReport {
  final double totalSales;
  final double totalProfit;
  final double totalDebt;
  final double inventoryValue;
  
  // Comparisons
  final double salesGrowth; // Percentage
  final double previousSales;

  // Analysis
  final Map<String, dynamic> dailyStats; // bestDay, worstDay, avg
  final List<String> insights;
  
  final List<ReportMetric> salesTrend;
  final List<ReportMetric> topProducts;
  final List<ReportMetric> topCustomers;
  final List<DeadStockItem> deadStock;
  final DebtMovement debtMovement;
  final List<ProductProfitItem> productPerformance;

  DashboardReport({
    required this.totalSales,
    required this.totalProfit,
    required this.totalDebt,
    required this.inventoryValue,
    required this.salesGrowth,
    required this.previousSales,
    required this.dailyStats,
    required this.insights,
    required this.salesTrend,
    required this.topProducts,
    required this.topCustomers,
    required this.deadStock,
    required this.debtMovement,
    required this.productPerformance,
  });
}

class DeadStockItem {
  final int productId;
  final String name;
  final int daysSinceLastSale;
  final int remainingStock;

  DeadStockItem({
    required this.productId,
    required this.name,
    required this.daysSinceLastSale,
    required this.remainingStock,
  });
}

class DebtMovement {
  final double totalCurrent;
  final double newDebt;
  final double collectedDebt;

  DebtMovement({
    required this.totalCurrent,
    required this.newDebt,
    required this.collectedDebt,
  });
}

class ProductProfitItem {
  final String productName;
  final double totalRevenue;
  final double totalCost;
  final double netProfit;
  final int soldCount;

  ProductProfitItem({
    required this.productName,
    required this.totalRevenue,
    required this.totalCost,
    required this.netProfit,
    required this.soldCount,
  });
}
