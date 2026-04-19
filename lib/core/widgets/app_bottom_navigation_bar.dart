import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
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
    final List<IconData> icons = [
      Icons.home_rounded,
      Icons.people_rounded,
      Icons.bar_chart_rounded,
      Icons.store_rounded,
    ];

    final List<String> labels = [
      'الرئيسية',
      'customers'.tr(),
      'reports'.tr(),
      'store'.tr(),
    ];

    return AnimatedBottomNavigationBar.builder(
      itemCount: icons.length,
      tabBuilder: (int index, bool isActive) {
        final color = isActive ? AppColors.primary : Colors.grey.shade400;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(isActive ? 6 : 0),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[index],
                size: isActive ? 26 : 24,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              labels[index],
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        );
      },
      activeIndex: activeIndex,
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.softEdge,
      leftCornerRadius: 32,
      rightCornerRadius: 32,
      elevation: 20,
      backgroundColor: AppColors.surface,
      onTap: onTap,
      splashSpeedInMilliseconds: 300,
    );
  }
}
