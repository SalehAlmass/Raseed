import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'subscription'.tr(),
      extendBody: false,
      mobileLeading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
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

  Widget _buildMobileBody() {
    return CustomScrollView(
      slivers: [
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
    );
  }

  Widget _buildDesktopBody() {
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
              PageHeader(title: 'subscription'.tr()),
              const SizedBox(height: AppSpace.xl),
              Center(child: _buildDesktopHeader()),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopFeaturesList(),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopPricingCard(),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopSafeDataNote(),
            ],
          ),
        ),
      ),
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
          _subService.isClockTampered 
            ? 'clock_tampered'.tr() 
            : (isExpired ? 'trial_expired'.tr() : 'trial'.tr()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _subService.isClockTampered ? 20.sp : 28.sp, 
            fontWeight: FontWeight.bold, 
            color: _subService.isClockTampered ? AppColors.error : AppColors.textPrimary
          ),
        ),
        SizedBox(height: 8.h),
        if (!isExpired && !_subService.isSubscribed && !_subService.isClockTampered)
          Text(
            'trial_remaining'.tr(namedArgs: {'days': remaining.toString()}),
            style: TextStyle(fontSize: 16.sp, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    final remaining = _subService.remainingDays;
    final isExpired = remaining <= 0 && !_subService.isSubscribed;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: isExpired
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isExpired ? Icons.timer_off_rounded : Icons.workspace_premium_rounded,
            color: isExpired ? AppColors.error : AppColors.primary,
            size: 60,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          _subService.isClockTampered
            ? 'clock_tampered'.tr()
            : (isExpired ? 'trial_expired'.tr() : 'trial'.tr()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _subService.isClockTampered ? 20 : 28,
            fontWeight: FontWeight.bold,
            color: _subService.isClockTampered ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        if (!isExpired && !_subService.isSubscribed && !_subService.isClockTampered)
          Text(
            'trial_remaining'.tr(namedArgs: {'days': remaining.toString()}),
            style: TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w600),
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

  Widget _buildDesktopFeaturesList() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium_features'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpace.lg),
          _buildDesktopFeatureRow(Icons.people_alt_rounded, 'feature_unlimited_customers'.tr()),
          const SizedBox(height: AppSpace.md),
          _buildDesktopFeatureRow(Icons.point_of_sale_rounded, 'feature_unlimited_sales'.tr()),
          const SizedBox(height: AppSpace.md),
          _buildDesktopFeatureRow(Icons.inventory_2_rounded, 'feature_inventory_control'.tr()),
          const SizedBox(height: AppSpace.md),
          _buildDesktopFeatureRow(Icons.analytics_rounded, 'feature_advanced_reports'.tr()),
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

  Widget _buildDesktopFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: AppSpace.md),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
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

  Widget _buildDesktopPricingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.xxl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Column(
        children: [
          Text(
            'subscription_price'.tr(),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: AppSpace.lg),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text('activate_now'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildDesktopSafeDataNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Text(
        'restricted_msg'.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
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
