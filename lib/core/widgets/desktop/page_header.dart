import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';

/// Desktop page header: a bold title, optional subtitle and trailing actions.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final actions = this.actions ?? const [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AppSpace.md),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.sm),
            actions[i],
          ],
        ],
      ],
    );
  }
}
