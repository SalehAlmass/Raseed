import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../di/injection_container.dart';
import '../../services/settings_service.dart';
import '../../services/theme_service.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';

/// Desktop top bar: page title/subtitle on the start side and global
/// (theme, language) plus screen-specific actions on the end side.
class DesktopTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onToggleSidebar;

  const DesktopTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: DesktopMetrics.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      color: colors.surface,
      child: Row(
        children: [
          if (onToggleSidebar != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.xs),
              child: IconButton(
                tooltip: 'more'.tr(),
                onPressed: onToggleSidebar,
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _GlobalAction(
            tooltip: 'language'.tr(),
            icon: Icons.language_rounded,
            child: _buildLanguageMenu(context),
          ),
          _buildThemeToggle(context),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  Widget _buildLanguageMenu(BuildContext context) {
    final settingsService = sl<SettingsService>();
    return PopupMenuButton<Locale>(
      tooltip: 'language'.tr(),
      initialValue: context.locale,
      onSelected: (locale) {
        if (locale != context.locale) {
          context.setLocale(locale);
          settingsService.updateSettings(
            settingsService.settings.copyWith(languageCode: locale.languageCode),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('ar'),
          child: Text('arabic'.tr()),
        ),
        PopupMenuItem(
          value: const Locale('en'),
          child: Text('english'.tr()),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              context.locale.languageCode.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeService = sl<ThemeService>();
    final icon = switch (themeService.themeModeIndex) {
      0 => Icons.light_mode_rounded,
      1 => Icons.dark_mode_rounded,
      _ => Icons.brightness_auto_rounded,
    };
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) => _GlobalAction(
        tooltip: 'theme'.tr(),
        icon: icon,
        onPressed: () {
          final next = (themeService.themeModeIndex + 1) % 3;
          themeService.setThemeModeByIndex(next);
        },
      ),
    );
  }
}

class _GlobalAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Widget? child;

  const _GlobalAction({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpace.xs),
      child: child ??
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: colors.textSecondary, size: 20),
          ),
    );
  }
}
