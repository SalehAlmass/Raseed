
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/models/report_models.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SalesTrendChart extends StatelessWidget {
  final List<ReportMetric> trend;
  const SalesTrendChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const Center(child: Text('No data'));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= trend.length) return const SizedBox.shrink();
                if (trend.length > 7 && value.toInt() % (trend.length ~/ 4) != 0) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    trend[value.toInt()].label.split('-').last,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
            isCurved: true,
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.3), AppColors.secondary.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopProductsChart extends StatelessWidget {
  final List<ReportMetric> products;
  const TopProductsChart({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const Center(child: Text('No data'));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: products.fold(0, (max, p) => p.value > max ? p.value : max) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= products.length) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    products[value.toInt()].label.length > 8 
                      ? products[value.toInt()].label.substring(0, 8) 
                      : products[value.toInt()].label,
                    style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: products.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                gradient: AppColors.primaryGradient,
                width: 16.w,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
