import 'package:flutter/material.dart';
import '../../theme/desktop_tokens.dart';

/// Returns true when the current layout is desktop-sized (>= 900px).
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

/// Returns true when the current layout is tablet-sized (600–899px).
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile &&
    MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;

/// Returns true when the current layout is phone-sized (< 600px).
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;

/// Lays [children] out in a responsive grid of equal-width cells.
///
/// Column count adapts to the available width: 1 on phones, 2 on small
/// tablets, 3 on tablets, 4 on desktops. Override with [columns].
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.spacing = AppSpace.md,
    this.runSpacing = AppSpace.md,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final cols = columns ?? _columnCount(maxWidth);
        final width = cols <= 1
            ? maxWidth
            : (maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }

  int _columnCount(double maxWidth) {
    if (maxWidth >= AppBreakpoints.desktop) return 4;
    if (maxWidth >= AppBreakpoints.tablet) return 3;
    if (maxWidth >= AppBreakpoints.mobile) return 2;
    return 1;
  }
}
