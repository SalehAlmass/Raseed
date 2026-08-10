import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';
import '../app_bottom_navigation_bar.dart';
import 'desktop_sidebar.dart';
import 'desktop_top_bar.dart';

/// Responsive application shell.
///
/// On desktop (>= 900px) renders a [DesktopSidebar], [DesktopTopBar] and the
/// provided [desktopBody] (or [body] as fallback). On smaller widths it falls
/// back to the original mobile scaffold (app bar + bottom navigation) so the
/// existing phone experience is preserved untouched.
class DesktopScaffold extends StatefulWidget {
  final int activeNavIndex;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? desktopBody;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onOpenSettings;
  final Widget? mobileLeading;
  final Widget? mobileTitle;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool showMobileBottomNav;

  const DesktopScaffold({
    super.key,
    required this.activeNavIndex,
    required this.title,
    required this.onNavigate,
    required this.body,
    this.subtitle,
    this.actions,
    this.desktopBody,
    this.onOpenSettings,
    this.mobileLeading,
    this.mobileTitle,
    this.floatingActionButton,
    this.extendBody = false,
    this.showMobileBottomNav = true,
  });

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.tablet;

        if (!isDesktop) {
          return Scaffold(
            extendBody: widget.extendBody,
            backgroundColor: colors.background,
            appBar: AppBar(
              title: widget.mobileTitle ??
                  Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: colors.textPrimary,
              leading: widget.mobileLeading,
              actions: widget.actions,
            ),
            body: widget.body,
             floatingActionButton: widget.floatingActionButton,
             bottomNavigationBar: widget.showMobileBottomNav
                 ? AppBottomNavigationBar(
                     activeIndex: widget.activeNavIndex,
                     onTap: widget.onNavigate,
                   )
                 : null,
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: Row(
            children: [
              DesktopSidebar(
                activeIndex: widget.activeNavIndex,
                onNavigate: widget.onNavigate,
                onOpenSettings: widget.onOpenSettings,
                collapsed: _sidebarCollapsed,
              ),
              VerticalDivider(width: 1, color: colors.divider),
              Expanded(
                child: Column(
                  children: [
                    DesktopTopBar(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      actions: widget.actions,
                      onToggleSidebar: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                    ),
                    Divider(height: 1, color: colors.divider),
                    Expanded(
                      child: widget.desktopBody ?? widget.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
