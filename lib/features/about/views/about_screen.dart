import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:rseed/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'about'.tr(),
      extendBody: false,
      mobileLeading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.of(context).textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      onNavigate: (index) => _onNavTap(context, index),
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  void _onNavTap(BuildContext context, int index) {
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

  Widget _buildMobileBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: _buildAppLogo(),
                ),
                SizedBox(height: 24.h),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildAppInfo(),
                ),
                SizedBox(height: 32.h),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildDescriptionCard(context),
                ),
                SizedBox(height: 32.h),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildContactSection(context),
                ),
                SizedBox(height: 40.h),
                _buildCopyright(),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ],
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
              PageHeader(title: 'about'.tr()),
              const SizedBox(height: AppSpace.xl),
              Center(child: _buildDesktopLogo()),
              const SizedBox(height: AppSpace.md),
              Center(child: _buildDesktopAppInfo()),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopDescriptionCard(context),
              const SizedBox(height: AppSpace.xl),
              _buildDesktopContactSection(context),
              const SizedBox(height: AppSpace.xxl),
              _buildDesktopCopyright(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 250.w,
        height: 120.w,
      ),
    );
  }

  Widget _buildDesktopLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 250,
      height: 120,
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            '${'version'.tr()} 1.0.0',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopAppInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${'version'.tr()} 1.0.0',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'about_description'.tr(),
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.of(context).textPrimary,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          const Divider(),
          SizedBox(height: 24.h),
          _buildFeatureRow(context, Icons.security_rounded, 'onboarding_feature_3'.tr()),
          SizedBox(height: 16.h),
          _buildFeatureRow(context, Icons.analytics_rounded, 'onboarding_feature_2'.tr()),
          SizedBox(height: 16.h),
          _buildFeatureRow(context, Icons.people_alt_rounded, 'onboarding_feature_1'.tr()),
        ],
      ),
    );
  }

  Widget _buildDesktopDescriptionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Column(
        children: [
          Text(
            'about_description'.tr(),
            style: TextStyle(
              fontSize: 15,
              color: AppColors.of(context).textPrimary,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.lg),
          const Divider(),
          const SizedBox(height: AppSpace.lg),
          _buildDesktopFeatureRow(context, Icons.security_rounded, 'onboarding_feature_3'.tr()),
          const SizedBox(height: AppSpace.md),
          _buildDesktopFeatureRow(context, Icons.analytics_rounded, 'onboarding_feature_2'.tr()),
          const SizedBox(height: AppSpace.md),
          _buildDesktopFeatureRow(context, Icons.people_alt_rounded, 'onboarding_feature_1'.tr()),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.success, size: 20.sp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.of(context).textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFeatureRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.success, size: 20),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.of(context).textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'crafted_by'.tr(),
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          AppConfig.developerName,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(context, Icons.language_rounded, 'Website', () async {
              final url = Uri.parse(AppConfig.developerGithub);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }),
            SizedBox(width: 20.w),
            _buildSocialButton(context, Icons.email_rounded, 'Email', () async {
              final url = Uri.parse('mailto:${AppConfig.developerEmail}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }),
            SizedBox(width: 20.w),
            _buildSocialButton(context, Icons.message_rounded, 'WhatsApp', () async {
              final url = Uri.parse(AppConfig.developerWhatsApp);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopContactSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'crafted_by'.tr(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          AppConfig.developerName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDesktopSocialButton(context, Icons.language_rounded, 'Website', () async {
              final url = Uri.parse(AppConfig.developerGithub);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }),
            const SizedBox(width: AppSpace.md),
            _buildDesktopSocialButton(context, Icons.email_rounded, 'Email', () async {
              final url = Uri.parse('mailto:${AppConfig.developerEmail}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }),
            const SizedBox(width: AppSpace.md),
            _buildDesktopSocialButton(context, Icons.message_rounded, 'WhatsApp', () async {
              final url = Uri.parse(AppConfig.developerWhatsApp);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 24.sp),
        ),
      ),
    );
  }

  Widget _buildDesktopSocialButton(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            shape: BoxShape.circle,
            boxShadow: AppShadow.soft(Colors.black),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
      ),
    );
  }

  Widget _buildCopyright() {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} تاجر ماس',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'All rights reserved',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopCopyright() {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} تاجر ماس',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpace.xxs),
        Text(
          'All rights reserved',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
