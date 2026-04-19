import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('about'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Icon(
                Icons.store_mall_directory,
                size: 60.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),

            // App Name
            Text(
              'app_name'.tr(),
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),

            // Version
            Text(
              'version'.tr() + ' 1.0.0',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 32.h),

            // Description
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
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
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),
                  _buildFeatureItem('onboarding_feature_1'.tr()),
                  _buildFeatureItem('onboarding_feature_2'.tr()),
                  _buildFeatureItem('onboarding_feature_3'.tr()),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Developer Info
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'crafted_by'.tr(),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Developer Name',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          // TODO: Open email
                        },
                        icon: Icon(Icons.email, color: AppColors.primary),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Open website
                        },
                        icon: Icon(Icons.language, color: AppColors.primary),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Open social media
                        },
                        icon: Icon(Icons.share, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Copyright
            Text(
              '© 2024 Raseed. All rights reserved.',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
