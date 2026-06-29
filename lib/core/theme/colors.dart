import 'package:flutter/material.dart';

/// Application Color Constants
///
/// Use [AppColors.of] to get theme-aware colors from a [BuildContext].
/// Static getters return light-mode values for backward compatibility.
class AppColors {
  AppColors._();

  // ── Primary Colors ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF667EEA);
  static const Color primaryDark = Color(0xFF5A67D8);
  static const Color primaryLight = Color(0xFF7C8FFF);

  // ── Secondary Colors ────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF764BA2);
  static const Color secondaryDark = Color(0xFF6B4190);
  static const Color secondaryLight = Color(0xFF8B5BB5);

  // ── Accent Colors ───────────────────────────────────────────────────────
  static const Color accent = Color(0xFFF093FB);
  static const Color accentDark = Color(0xFFE080E8);
  static const Color accentLight = Color(0xFFFFB3FF);

  // ── Background Colors (Light) ───────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  // ── Background Colors (Dark) ────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F0F1A);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceContainerDark = Color(0xFF232346);

  // ── Text Colors (Light) ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Text Colors (Dark) ──────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFE8E8F0);
  static const Color textSecondaryDark = Color(0xFFA0A0B8);
  static const Color textLightDark = Color(0xFF6C6C80);

  // ── Status Colors ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDAA5D);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF74B9FF);

  // ── Border & Divider Colors ─────────────────────────────────────────────
  static const Color border = Color(0xFFDFE6E9);
  static const Color divider = Color(0xFFECF0F1);
  static const Color borderDark = Color(0xFF2D2D44);
  static const Color dividerDark = Color(0xFF252538);

  // ── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFF5576C)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDark, Color(0xFF16213E)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  );

  // ── Context-aware color helper ──────────────────────────────────────────

  /// Returns the appropriate [AppColorSet] based on the current [BuildContext] brightness.
  static AppColorSet of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkSet : _lightSet;
  }

  static final _AppColorSet _lightSet = _AppColorSet._light();
  static final _AppColorSet _darkSet = _AppColorSet._dark();
}

/// A set of resolved colors for the current theme.
class AppColorSet {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color textOnPrimary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color border;
  final Color divider;
  final LinearGradient primaryGradient;
  final LinearGradient successGradient;
  final Color scaffoldBackground;
  final Color cardBackground;

  const AppColorSet({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.textOnPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.divider,
    required this.primaryGradient,
    required this.successGradient,
    required this.scaffoldBackground,
    required this.cardBackground,
  });
}

class _AppColorSet extends AppColorSet {
  _AppColorSet._light()
      : super(
          primary: AppColors.primary,
          primaryDark: AppColors.primaryDark,
          primaryLight: AppColors.primaryLight,
          secondary: AppColors.secondary,
          background: AppColors.background,
          surface: AppColors.surface,
          surfaceContainer: const Color(0xFFF0F0F5),
          textPrimary: AppColors.textPrimary,
          textSecondary: AppColors.textSecondary,
          textLight: AppColors.textLight,
          textOnPrimary: AppColors.textOnPrimary,
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
          info: AppColors.info,
          border: AppColors.border,
          divider: AppColors.divider,
          primaryGradient: AppColors.primaryGradient,
          successGradient: AppColors.successGradient,
          scaffoldBackground: AppColors.background,
          cardBackground: AppColors.surface,
        );

  _AppColorSet._dark()
      : super(
          primary: AppColors.primary,
          primaryDark: AppColors.primaryDark,
          primaryLight: AppColors.primaryLight,
          secondary: AppColors.secondary,
          background: AppColors.backgroundDark,
          surface: AppColors.surfaceDark,
          surfaceContainer: AppColors.surfaceContainerDark,
          textPrimary: AppColors.textPrimaryDark,
          textSecondary: AppColors.textSecondaryDark,
          textLight: AppColors.textLightDark,
          textOnPrimary: AppColors.textOnPrimary,
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
          info: AppColors.info,
          border: AppColors.borderDark,
          divider: AppColors.dividerDark,
          primaryGradient: AppColors.primaryGradient,
          successGradient: AppColors.successGradient,
          scaffoldBackground: AppColors.backgroundDark,
          cardBackground: AppColors.surfaceDark,
        );
}
