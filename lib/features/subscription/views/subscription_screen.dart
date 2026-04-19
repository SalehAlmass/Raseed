import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _subService = sl<SubscriptionService>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  FadeInDown(child: _buildHeader()),
                  SizedBox(height: 32.h),
                  FadeInUp(child: _buildFeaturesList()),
                  SizedBox(height: 40.h),
                 // FadeInUp(delay: const Duration(milliseconds: 200), child: _buildPricingCard()),
                  SizedBox(height: 40.h),
                  _buildSafeDataNote(),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'subscription'.tr(),
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeader() {
    final remaining = _subService.remainingDays;
    final isExpired = remaining <= 0 && !_subService.isSubscribed;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: isExpired ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isExpired ? Icons.timer_off_rounded : Icons.workspace_premium_rounded,
            color: isExpired ? AppColors.error : AppColors.primary,
            size: 60.sp,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          isExpired ? 'trial_expired'.tr() : 'trial'.tr(),
          style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        SizedBox(height: 8.h),
        if (!isExpired && !_subService.isSubscribed)
          Text(
            'trial_remaining'.tr(namedArgs: {'days': remaining.toString()}),
            style: TextStyle(fontSize: 16.sp, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium_features'.tr(),
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 24.h),
          _buildFeatureRow(Icons.people_alt_rounded, 'feature_unlimited_customers'.tr()),
          _buildFeatureRow(Icons.point_of_sale_rounded, 'feature_unlimited_sales'.tr()),
          _buildFeatureRow(Icons.inventory_2_rounded, 'feature_inventory_control'.tr()),
          _buildFeatureRow(Icons.analytics_rounded, 'feature_advanced_reports'.tr()),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24.sp),
          SizedBox(width: 16.w),
          Text(text, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'subscription_price'.tr(),
            style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: Size(double.infinity, 60.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text('activate_now'.tr(), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeDataNote() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Text(
        'restricted_msg'.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, color: Colors.grey, height: 1.5),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate API/Payment
    await _subService.activateSubscription();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('subscription_success'.tr()), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    }
  }
}
