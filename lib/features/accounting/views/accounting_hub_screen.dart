import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/colors.dart';

class AccountingHubScreen extends StatelessWidget {
  const AccountingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'accounting_hub'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
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
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 15.h),
            _buildGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStats(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.sp),
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
      ],
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
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
                color: color.withOpacity(0.1),
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
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
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
