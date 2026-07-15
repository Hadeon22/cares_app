import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/service_router.dart';
import '../models/models.dart';

/// Tappable service tile used in the two-column grid.
/// Ripple via [InkWell]; a gentle scale-on-press via [AnimatedScale].
class ServiceCard extends StatefulWidget {
  const ServiceCard({super.key, required this.item, this.onTap});

  final ServiceItem item;
  final VoidCallback? onTap;

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    final accent = item.isEmergency ? AppColors.emergency : item.accent;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: AppDurations.fast,
      curve: Curves.easeOut,
      child: Material(
        color: item.isEmergency
            ? AppColors.emergency.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.05),
          onTap: widget.onTap ?? () => openService(context, item.action),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: item.isEmergency
                    ? AppColors.emergency.withValues(alpha: 0.35)
                    : AppColors.divider,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(item.icon, color: accent, size: 24),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                // Expanded + Flexible so long copy trims instead of
                // overflowing the grid tile.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
