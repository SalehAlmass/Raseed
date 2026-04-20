
import 'package:easy_localization/easy_localization.dart';
import '../../../core/models/report_models.dart';

class ReportEngine {
  
  static double calculateGrowth(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  static Map<String, dynamic> calculateDailyStats(List<ReportMetric> trend) {
    if (trend.isEmpty) return {'best': null, 'worst': null, 'avg': 0.0};

    ReportMetric? best;
    ReportMetric? worst;
    double sum = 0;

    for (var m in trend) {
      sum += m.value;
      if (best == null || m.value > best.value) best = m;
      if (worst == null || m.value < worst.value) worst = m;
    }

    return {
      'best': best,
      'worst': worst,
      'avg': sum / trend.length,
    };
  }

  static List<String> generateInsights(DashboardReport report) {
    List<String> insights = [];

    // Sales Insights
    if (report.salesGrowth > 10) {
      insights.add('insight_sales_growing'.tr(args: [report.salesGrowth.toStringAsFixed(1)]));
    } else if (report.salesGrowth < -10) {
      insights.add('insight_sales_dropping'.tr(args: [report.salesGrowth.abs().toStringAsFixed(1)]));
    }

    // Inventory Insights
    if (report.deadStock.length > 5) {
      insights.add('insight_dead_stock'.tr(args: [report.deadStock.length.toString()]));
    }

    // Product Insights
    if (report.productPerformance.isNotEmpty) {
      final top = report.productPerformance.first;
      insights.add('insight_top_product'.tr(args: [top.productName]));
    }

    // Debt Insights
    if (report.debtMovement.collectedDebt < report.debtMovement.newDebt) {
      insights.add('insight_debt_increasing'.tr());
    }

    return insights;
  }
}
