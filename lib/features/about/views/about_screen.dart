import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:rseed/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
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
                    child: _buildDescriptionCard(),
                  ),
                  SizedBox(height: 32.h),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
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
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'about'.tr(),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20.sp,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAppLogo() {
    return Center(
      child: Image.asset( 
        'assets/images/logo.png',
        width: 250.w,
        height: 120.w,
      )
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

  Widget _buildDescriptionCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              color: AppColors.textPrimary,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          const Divider(),
          SizedBox(height: 24.h),
          _buildFeatureRow(Icons.security_rounded, 'onboarding_feature_3'.tr()),
          SizedBox(height: 16.h),
          _buildFeatureRow(Icons.analytics_rounded, 'onboarding_feature_2'.tr()),
          SizedBox(height: 16.h),
          _buildFeatureRow(Icons.people_alt_rounded, 'onboarding_feature_1'.tr()),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
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
              color: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(Icons.language_rounded, 'Website', () async {
              final url = Uri.parse(AppConfig.developerGithub);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }),
            SizedBox(width: 20.w),
            _buildSocialButton(Icons.email_rounded, 'Email', () async {
              final url = Uri.parse('mailto:${AppConfig.developerEmail}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }),
            SizedBox(width: 20.w),
            _buildSocialButton(Icons.message_rounded, 'WhatsApp', () async {
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

  Widget _buildSocialButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
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

  Widget _buildCopyright() {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} Raseed Inc.',
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
}
