import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/fiscal_year_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';

class AccountingHubScreen extends StatefulWidget {
  const AccountingHubScreen({super.key});

  @override
  State<AccountingHubScreen> createState() => _AccountingHubScreenState();
}

class _AccountingHubScreenState extends State<AccountingHubScreen> {
  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'accounting_hub'.tr(),
      extendBody: false,
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainStats(context),
          SizedBox(height: 30.h),
          Text(
            'financial_management'.tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          SizedBox(height: 15.h),
          _buildGrid(context),
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
              PageHeader(title: 'accounting_hub'.tr()),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopHubGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHubGrid(BuildContext context) {
    return ResponsiveGrid(
      columns: 3,
      spacing: AppSpace.lg,
      runSpacing: AppSpace.lg,
      children: [
        _DesktopHubCard(
          title: 'daily_journal'.tr(),
          desc: 'track_entries'.tr(),
          icon: Icons.assignment_rounded,
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, Routes.journal),
        ),
        _DesktopHubCard(
          title: 'expenses'.tr(),
          desc: 'manage_spending'.tr(),
          icon: Icons.receipt_long_rounded,
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, Routes.expenses),
        ),
        _DesktopHubCard(
          title: 'purchase_orders'.tr(),
          desc: 'procurement_cycle'.tr(),
          icon: Icons.shopping_cart_checkout_rounded,
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, Routes.purchaseOrders),
        ),
        _DesktopHubCard(
          title: 'accounting_insights'.tr(),
          desc: 'profit_analysis'.tr(),
          icon: Icons.analytics_rounded,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, Routes.accountingInsights),
        ),
        _DesktopHubCard(
          title: 'chart_of_accounts'.tr(),
          desc: 'accounts_structure'.tr(),
          icon: Icons.account_tree_rounded,
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, Routes.chartOfAccounts),
        ),
        _DesktopHubCard(
          title: 'financial_reports'.tr(),
          desc: 'export_data'.tr(),
          icon: Icons.picture_as_pdf_rounded,
          color: Colors.teal,
          onTap: () => Navigator.pushNamed(context, Routes.reports),
        ),
        _DesktopHubCard(
          title: 'shift_management'.tr(),
          desc: 'manage_cash_drawer'.tr(),
          icon: Icons.lock_clock_rounded,
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, Routes.shifts),
        ),
        if (sl<AuthService>().isAdmin)
          _DesktopHubCard(
            title: 'employee_management'.tr(),
            desc: 'manage_staff_permissions'.tr(),
            icon: Icons.people_alt_rounded,
            color: Colors.brown,
            onTap: () => Navigator.pushNamed(context, Routes.employees),
          ),
        if (sl<AuthService>().isAdmin)
          _DesktopHubCard(
            title: 'annual_closing'.tr(),
            desc: 'perform_closing_desc'.tr(),
            icon: Icons.event_repeat_rounded,
            color: Colors.red.shade900,
            onTap: () => _showClosingDialog(context),
          ),
      ],
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

  Widget _buildMainStats(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'accounting_summary'.tr(),
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'manage_business_finances'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'hub_description'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16.w,
      crossAxisSpacing: 16.w,
      childAspectRatio: 0.9,
      children: [
        _HubCard(
          title: 'daily_journal'.tr(),
          desc: 'track_entries'.tr(),
          icon: Icons.assignment_rounded,
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, Routes.journal),
        ),
        _HubCard(
          title: 'expenses'.tr(),
          desc: 'manage_spending'.tr(),
          icon: Icons.receipt_long_rounded,
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, Routes.expenses),
        ),
        _HubCard(
          title: 'purchase_orders'.tr(),
          desc: 'procurement_cycle'.tr(),
          icon: Icons.shopping_cart_checkout_rounded,
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, Routes.purchaseOrders),
        ),
        _HubCard(
          title: 'accounting_insights'.tr(),
          desc: 'profit_analysis'.tr(),
          icon: Icons.analytics_rounded,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, Routes.accountingInsights),
        ),
        _HubCard(
          title: 'chart_of_accounts'.tr(),
          desc: 'accounts_structure'.tr(),
          icon: Icons.account_tree_rounded,
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, Routes.chartOfAccounts),
        ),
        _HubCard(
          title: 'financial_reports'.tr(),
          desc: 'export_data'.tr(),
          icon: Icons.picture_as_pdf_rounded,
          color: Colors.teal,
          onTap: () => Navigator.pushNamed(context, Routes.reports),
        ),
        _HubCard(
          title: 'shift_management'.tr(),
          desc: 'manage_cash_drawer'.tr(),
          icon: Icons.lock_clock_rounded,
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, Routes.shifts),
        ),
        if (sl<AuthService>().isAdmin)
          _HubCard(
            title: 'employee_management'.tr(),
            desc: 'manage_staff_permissions'.tr(),
            icon: Icons.people_alt_rounded,
            color: Colors.brown,
            onTap: () => Navigator.pushNamed(context, Routes.employees),
          ),
        if (sl<AuthService>().isAdmin)
          _HubCard(
            title: 'annual_closing'.tr(),
            desc: 'perform_closing_desc'.tr(),
            icon: Icons.event_repeat_rounded,
            color: Colors.red.shade900,
            onTap: () => _showClosingDialog(context),
          ),
      ],
    );
  }

  void _showClosingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_closing'.tr()),
        content: Text('perform_closing_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              await sl<FiscalYearService>().performAnnualClosing(DateTime.now().year.toString());
              
              if (context.mounted) {
                Navigator.pop(context); // Remove loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('closing_success'.tr()), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: AppColors.of(context).textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.of(context).textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHubCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DesktopHubCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: AppShadow.soft(Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
