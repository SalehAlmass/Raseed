import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
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
    return AnimatedBottomNavigationBar(
      icons: const [
        Icons.people,
        Icons.account_balance_wallet,
        Icons.analytics_outlined,
        Icons.store_mall_directory,
      ],
      activeIndex: activeIndex,
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.softEdge,
      leftCornerRadius: 32,
      rightCornerRadius: 32,
      activeColor: AppColors.primary,
      inactiveColor: Colors.grey,
      splashColor: AppColors.primary.withOpacity(0.3),
      backgroundColor: AppColors.surface,
      onTap: onTap,
    );
  }
}
