import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../di/injection_container.dart';
import '../../routes/routes.dart';
import '../../services/settings_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';
import '../pin_auth_dialog.dart';

/// Desktop navigation sidebar.
///
/// Primary items mirror the mobile bottom navigation and delegate navigation
/// to the host screen through [onNavigate]. Secondary items navigate to their
/// routes directly and are gated by the active module configuration.
class DesktopSidebar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onOpenSettings;
  final bool collapsed;

  const DesktopSidebar({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
    this.onOpenSettings,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = sl<SettingsService>().settings.moduleConfig;
    final colors = AppColors.of(context);
    final width = collapsed
        ? DesktopMetrics.sidebarCollapsedWidth
        : DesktopMetrics.sidebarWidth;

    final primary = <_SidebarItemData>[
      _SidebarItemData(0, Icons.home_rounded, 'home'.tr(), true),
      _SidebarItemData(1, Icons.people_rounded, 'customers'.tr(),
          config.showCustomers),
      _SidebarItemData(
          2, Icons.point_of_sale_rounded, 'new_sale'.tr(), config.showSales),
      _SidebarItemData(
          3, Icons.bar_chart_rounded, 'reports'.tr(), config.showReports),
      _SidebarItemData(
          4, Icons.store_rounded, 'store'.tr(), config.showInventory),
    ];

    final secondary = <_SidebarLink>[
      _SidebarLink(
        Icons.business_rounded,
        'suppliers'.tr(),
        Routes.suppliers,
        config.showSuppliers,
      ),
      _SidebarLink(
        Icons.account_balance_rounded,
        'accounting'.tr(),
        Routes.accountingHub,
        config.showAccounting,
      ),
      _SidebarLink(
        Icons.receipt_long_rounded,
        'receivables'.tr(),
        Routes.receivables,
        config.showAccounting,
      ),
      _SidebarLink(
        Icons.cloud_upload_outlined,
        'backup'.tr(),
        Routes.backup,
        config.enableCloudBackup,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: width,
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, colors),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: AppSpace.md,
                horizontal: collapsed ? AppSpace.xs : AppSpace.sm,
              ),
              children: [
                for (final item in primary)
                  if (item.enabled)
                    _SidebarItem(
                      icon: item.icon,
                      label: item.label,
                      selected: activeIndex == item.index,
                      collapsed: collapsed,
                      onTap: () => _handlePrimaryTap(context, item.index),
                    ),
                if (!collapsed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.sm, AppSpace.lg, AppSpace.sm, AppSpace.xs),
                    child: Text(
                      'more'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: colors.textLight,
                      ),
                    ),
                  ),
                  for (final link in secondary)
                    if (link.enabled)
                      _SidebarItem(
                        icon: link.icon,
                        label: link.label,
                        selected: false,
                        collapsed: collapsed,
                        onTap: () => Navigator.pushNamed(context, link.route),
                      ),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'settings'.tr(),
                    selected: false,
                    collapsed: collapsed,
                    onTap: onOpenSettings ??
                        () => Navigator.pushNamed(context, Routes.settings),
                  ),
                ],
              ],
            ),
          ),
          _buildSubscriptionFooter(context, colors),
        ],
      ),
    );
  }

  void _handlePrimaryTap(BuildContext context, int index) {
    final settings = sl<SettingsService>().settings;
    if (settings.staffConfig.isEnabled && (index == 3 || index == 4)) {
      showDialog<bool>(
        context: context,
        builder: (context) => PinAuthDialog(
          correctPin: settings.staffConfig.pinCode ?? '0000',
        ),
      ).then((verified) {
        if (verified == true && context.mounted) {
          onNavigate(index);
        }
      });
    } else {
      onNavigate(index);
    }
  }

  Widget _buildHeader(BuildContext context, AppColorSet colors) {
    return Padding(
      padding: EdgeInsets.all(collapsed ? AppSpace.sm : AppSpace.md),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.asset(
              'assets/images/logo.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: colors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                'app_name'.tr(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionFooter(BuildContext context, AppColorSet colors) {
    final sub = sl<SubscriptionService>();
    if (sub.isPremiumActive) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: _SidebarFooterTile(
          icon: Icons.verified_user_outlined,
          label: 'premium_active'.tr(),
          color: colors.success,
          collapsed: collapsed,
          onTap: () => Navigator.pushNamed(context, Routes.subscription),
        ),
      );
    }
    final remaining = sub.remainingDays;
    final label = remaining > 0
        ? 'trial_remaining'.tr(namedArgs: {'days': remaining.toString()})
        : 'trial_expired_home'.tr();
    return Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: _SidebarFooterTile(
        icon: Icons.lock_clock_rounded,
        label: label,
        color: remaining > 0 ? colors.warning : colors.error,
        collapsed: collapsed,
        onTap: () => Navigator.pushNamed(context, Routes.subscription),
      ),
    );
  }
}

class _SidebarItemData {
  final int index;
  final IconData icon;
  final String label;
  final bool enabled;

  _SidebarItemData(this.index, this.icon, this.label, this.enabled);
}

class _SidebarLink {
  final IconData icon;
  final String label;
  final String route;
  final bool enabled;

  _SidebarLink(this.icon, this.label, this.route, this.enabled);
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground =
        widget.selected ? colors.primary : colors.textSecondary;

    final content = Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: widget.selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Icon(widget.icon, color: foreground, size: 20),
        if (!widget.collapsed) ...[
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    widget.selected ? FontWeight.w600 : FontWeight.normal,
                color: foreground,
              ),
            ),
          ),
        ],
      ],
    );

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: widget.selected
              ? colors.primary.withValues(alpha: 0.12)
              : _hovered
                  ? colors.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? AppSpace.xs : AppSpace.xs,
                vertical: AppSpace.sm,
              ),
              child: widget.collapsed
                  ? Center(child: content)
                  : content,
            ),
          ),
        ),
      ),
    );

    if (!widget.collapsed) return tile;
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 400),
      child: tile,
    );
  }
}

class _SidebarFooterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarFooterTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              if (!collapsed) ...[
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
