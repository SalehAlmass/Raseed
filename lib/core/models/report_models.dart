
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
  final double? secondaryValue; // e.g., profit vs sales
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
  final List<ReportMetric> salesTrend;
  final List<ReportMetric> topProducts;
  final List<ReportMetric> topCustomers;

  DashboardReport({
    required this.totalSales,
    required this.totalProfit,
    required this.totalDebt,
    required this.salesTrend,
    required this.topProducts,
    required this.topCustomers,
  });
}
