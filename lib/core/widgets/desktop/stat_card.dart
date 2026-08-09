import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/desktop_tokens.dart';

/// Desktop KPI / metric card.
class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final double? growth;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.growth,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final growth = widget.growth;
    final growthPositive = (growth ?? 0) >= 0;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      widget.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (growthPositive
                            ? colors.success
                            : colors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growthPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: growthPositive ? colors.success : colors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${growth.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              growthPositive ? colors.success : colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textLight),
            ),
          ],
        ],
      ),
    );

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _hovered
              ? widget.color.withValues(alpha: 0.5)
              : colors.border,
        ),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: content,
    );

    if (widget.onTap == null) return container;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: container,
        ),
      ),
    );
  }
}
