import 'package:flutter/material.dart';

/// Desktop breakpoint constants (logical pixels).
class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 900;
  static const double desktop = 1280;
  static const double mobile = 600;
}

/// Desktop spacing scale (logical pixels, not screen-util scaled).
class AppSpace {
  AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Desktop radius scale.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Desktop layout metrics.
class DesktopMetrics {
  DesktopMetrics._();

  static const double sidebarWidth = 260;
  static const double sidebarCollapsedWidth = 76;
  static const double topBarHeight = 64;
  static const double contentMaxWidth = 1600;
}

/// A soft surface shadow used on desktop cards.
class AppShadow {
  AppShadow._();

  static List<BoxShadow> soft(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
