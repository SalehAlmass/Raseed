import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/installment_plan.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/receivable_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';

class ReceivablesDashboardScreen extends StatefulWidget {
  const ReceivablesDashboardScreen({super.key});

  @override
  State<ReceivablesDashboardScreen> createState() => _ReceivablesDashboardScreenState();
}

class _ReceivablesDashboardScreenState extends State<ReceivablesDashboardScreen> {
  final _service = sl<ReceivableService>();
  final _customerService = sl<CustomerService>();
  List<InstallmentPlan> _plans = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, active, completed, defaulted

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _service.updateOverdueStatus();
    final plans = await _service.getAllPlans();
    if (mounted) setState(() { _plans = plans; _isLoading = false; });
  }

  List<InstallmentPlan> get _filteredPlans {
    if (_filter == 'all') return _plans;
    return _plans.where((p) => p.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalDue = _plans.fold(0.0, (s, p) => s + p.remaining);
    final overdueCount = _plans.where((p) => p.status == 'defaulted' || p.isOverdue).length;

    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'receivables'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(totalDue, overdueCount),
      desktopBody: _buildDesktopBody(totalDue, overdueCount),
    );
  }

  Widget _buildMobileBody(double totalDue, int overdueCount) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    _buildStatCard(Icons.account_balance_wallet, totalDue, AppColors.primary),
                    SizedBox(width: 12.w),
                    _buildStatCard(Icons.warning_amber, overdueCount.toDouble(), AppColors.error),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    _buildFilterChip('all', context.locale.languageCode == 'ar' ? 'الكل' : 'All'),
                    SizedBox(width: 8.w),
                    _buildFilterChip('active', context.locale.languageCode == 'ar' ? 'نشط' : 'Active'),
                    SizedBox(width: 8.w),
                    _buildFilterChip('completed', context.locale.languageCode == 'ar' ? 'مكتمل' : 'Completed'),
                    SizedBox(width: 8.w),
                    _buildFilterChip('defaulted', context.locale.languageCode == 'ar' ? 'متأخر' : 'Overdue'),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: _filteredPlans.isEmpty
                    ? Center(child: Text('no_installment_plans'.tr()))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        itemCount: _filteredPlans.length,
                        itemBuilder: (context, index) => _buildPlanCard(_filteredPlans[index]),
                      ),
              ),
            ],
          );
  }

  Widget _buildDesktopBody(double totalDue, int overdueCount) {
    final colors = AppColors.of(context);
    final formatter = CurrencyHelper.getFormatter('YER');
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
              PageHeader(
                title: 'receivables'.tr(),
                subtitle: '${_filteredPlans.length} ${'installments'.tr()}',
              ),
              const SizedBox(height: AppSpace.md),
              _buildDesktopKpis(formatter, totalDue, overdueCount),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopToolbar(colors),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTable(colors, formatter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopKpis(NumberFormat formatter, double totalDue, int overdueCount) {
    return ResponsiveGrid(
      columns: 2,
      children: [
        StatCard(
          title: 'total_remaining'.tr(),
          value: formatter.format(totalDue),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'overdue'.tr(),
          value: '$overdueCount',
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildDesktopToolbar(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Wrap(
        spacing: AppSpace.xs,
        runSpacing: AppSpace.xs,
        children: [
          _buildDesktopFilterChip('all', context.locale.languageCode == 'ar' ? 'الكل' : 'All'),
          _buildDesktopFilterChip('active', context.locale.languageCode == 'ar' ? 'نشط' : 'Active'),
          _buildDesktopFilterChip('completed', context.locale.languageCode == 'ar' ? 'مكتمل' : 'Completed'),
          _buildDesktopFilterChip('defaulted', context.locale.languageCode == 'ar' ? 'متأخر' : 'Overdue'),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterChip(String key, String label) {
    final isSelected = _filter == key;
    final colors = AppColors.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() => _filter = key);
        }
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colors.surface,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDesktopTable(AppColorSet colors, NumberFormat formatter) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _filteredPlans
        .map((p) => _buildPlanRow(formatter, p))
        .toList();
    return DesktopTable(
      headers: [
        'installment_plan'.tr(),
        'installments'.tr(),
        'status'.tr(),
        'remaining'.tr(),
        'total'.tr(),
        '',
      ],
      flexes: const [3, 2, 2, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_installment_plans'.tr(),
    );
  }

  List<Widget> _buildPlanRow(NumberFormat formatter, InstallmentPlan plan) {
    final statusColor = plan.status == 'completed' ? Colors.green : plan.isOverdue ? AppColors.error : AppColors.primary;
    final statusLabel = plan.status == 'active' ? 'active'.tr() : plan.status == 'completed' ? 'completed'.tr() : 'overdue'.tr();

    return [
      Text(
        '${'installment_plan'.tr()} #${plan.id}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text(
        '${plan.paidCount}/${plan.installmentCount} ${'installments'.tr()}',
        style: const TextStyle(fontSize: 12),
      ),
      Text(
        statusLabel,
        style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
      ),
      Text(
        formatter.format(plan.remaining),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
      ),
      Text(
        formatter.format(plan.totalAmount),
        style: const TextStyle(fontSize: 12),
      ),
      IconButton(
        tooltip: 'view'.tr(),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        onPressed: () => _showPlanDetail(plan),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ];
  }

  Widget _buildStatCard(IconData icon, double value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8.h),
            Text(
              CurrencyHelper.getFormatter('YER').format(value),
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.sp, color: isSelected ? Colors.white : Colors.grey[700])),
      ),
    );
  }

  Widget _buildPlanCard(InstallmentPlan plan) {
    final progress = plan.totalPaid / plan.totalAmount;
    final statusColor = plan.status == 'completed' ? Colors.green : plan.isOverdue ? AppColors.error : AppColors.primary;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showPlanDetail(plan),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                    child: Icon(plan.status == 'completed' ? Icons.check_circle : Icons.schedule, color: statusColor, size: 20),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${'installment_plan'.tr()} #${plan.id}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                        Text('${plan.paidCount}/${plan.installmentCount} ${'installments'.tr()}', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: plan.status == 'active' ? Colors.blue.withOpacity(0.1) : statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      plan.status == 'active' ? 'active'.tr() : plan.status == 'completed' ? 'completed'.tr() : 'overdue'.tr(),
                      style: TextStyle(fontSize: 11.sp, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: statusColor,
                  minHeight: 6.h,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${'remaining'.tr()}: ${CurrencyHelper.getFormatter('YER').format(plan.remaining)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  Text('${'total'.tr()}: ${CurrencyHelper.getFormatter('YER').format(plan.totalAmount)}', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanDetail(InstallmentPlan plan) async {
    final refreshed = await _service.getPlanById(plan.id!);
    if (refreshed == null) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        final schedule = refreshed.schedule;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (ctx, scrollCtrl) => Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.r)))),
                SizedBox(height: 16.h),
                Text('${'installment_plan'.tr()} #${refreshed.id}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 8.h),
                Text('${'total'.tr()}: ${CurrencyHelper.getFormatter('YER').format(refreshed.totalAmount)}', style: TextStyle(fontSize: 14.sp)),
                Text('${'remaining'.tr()}: ${CurrencyHelper.getFormatter('YER').format(refreshed.remaining)}', style: TextStyle(fontSize: 14.sp, color: AppColors.primary)),
                SizedBox(height: 16.h),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: schedule.length,
                    itemBuilder: (context, i) {
                      final p = schedule[i];
                      final isOverdue = p.isOverdue;
                      return ListTile(
                        leading: Icon(
                          p.status == 'paid' ? Icons.check_circle : isOverdue ? Icons.warning : Icons.pending,
                          color: p.status == 'paid' ? Colors.green : isOverdue ? AppColors.error : Colors.orange,
                        ),
                        title: Text('${'installment'.tr()} ${i + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${CurrencyHelper.getFormatter('YER').format(p.amount)} - ${DateFormat('yyyy-MM-dd').format(p.dueDate)}'),
                        trailing: p.status == 'paid'
                            ? Text('paid'.tr(), style: TextStyle(color: Colors.green))
                            : ElevatedButton(
                                onPressed: () async {
                                  await _service.markPaymentPaid(p.id!);
                                  Navigator.pop(ctx);
                                  _load();
                                },
                                child: Text('pay'.tr()),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            if (result == true) _load();
          });
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
}
