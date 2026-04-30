import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/colors.dart';
import '../services/settings_service.dart';
import '../di/injection_container.dart';
import 'pin_auth_dialog.dart';

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
    final config = sl<SettingsService>().settings.moduleConfig;

    final List<_NavItem> allItems = [
      _NavItem(0, Icons.home_rounded, 'الرئيسية', true),
      _NavItem(1, Icons.people_rounded, 'customers'.tr(), config.showCustomers),
      _NavItem(2, Icons.add_circle_rounded, 'new_sale'.tr(), config.showSales && config.showCustomers),
      _NavItem(3, Icons.bar_chart_rounded, 'reports'.tr(), config.showReports),
      _NavItem(4, Icons.store_rounded, 'store'.tr(), config.showInventory),
    ];

    final visibleItems = allItems.where((i) => i.enabled).toList();

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
          children: visibleItems.map((item) {
            final isActive = activeIndex == item.index;
            final isCenter = item.index == 2;

            if (isCenter) {
              return _buildCenterAction(item.icon, onTap, item.index);
            }

            return _buildTabItem(
              icon: item.icon,
              label: item.label,
              isActive: isActive,
              onTap: () async {
                final settings = sl<SettingsService>().settings;
                // Restricted indices: 3 (Reports), 4 (Store)
                if (settings.staffConfig.isEnabled && (item.index == 3 || item.index == 4)) {
                  final verified = await showDialog<bool>(
                    context: context,
                    builder: (context) => PinAuthDialog(correctPin: settings.staffConfig.pinCode ?? '0000'),
                  );
                  if (verified == true) {
                    onTap(item.index);
                  }
                } else {
                  onTap(item.index);
                }
              },
            );
          }).toList(),
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
              child: Icon(icon, color: color, size: 26.sp),
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
          child: Icon(icon, color: Colors.white, size: 32.sp),
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  final bool enabled;
  _NavItem(this.index, this.icon, this.label, this.enabled);
}
