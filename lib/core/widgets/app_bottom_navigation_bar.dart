import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigationBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 5 Tabs: Home, Customers, Sale, Reports, Store
    final List<IconData> icons = [
      Icons.home_rounded,
      Icons.people_rounded,
      Icons.add_circle_rounded, // Center highlighted button
      Icons.bar_chart_rounded,
      Icons.store_rounded,
    ];

    final List<String> labels = [
      'الرئيسية',
      'customers'.tr(),
      'new_sale'.tr(),
      'reports'.tr(),
      'store'.tr(),
    ];

    return Container(
      padding: EdgeInsets.only(bottom: 25.h, left: 16.w, right: 16.w),
      color: Colors.transparent, // Background of the Scaffold area
      child: Container(
        height: 75.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(40.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(icons.length, (index) {
            final isActive = activeIndex == index;
            final isCenter = index == 2;

            if (isCenter) {
              return _buildCenterAction(icons[index], onTap, index);
            }

            return _buildTabItem(
              icon: icons[index],
              label: labels[index],
              isActive: isActive,
              onTap: () => onTap(index),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? AppColors.primary : Colors.grey.withOpacity(0.6);
    
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isActive ? 1.2 : 1.0,
              child: Icon(
                icon,
                color: color,
                size: 26.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isActive)
              Container(
                margin: EdgeInsets.only(top: 4.h),
                width: 4.w,
                height: 4.w,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAction(IconData icon, ValueChanged<int> onTap, int index) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Transform.translate(
        offset: Offset(0, -5.h), // Light lift
        child: Container(
          width: 55.w,
          height: 55.w,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32.sp,
          ),
        ),
      ),
    );
  }
}
