import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// "— CITIZEN SERVICES" style eyebrow + serif heading, mirroring the web portal.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.onNavy = false,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool onNavy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleColor = onNavy ? AppColors.onNavy : AppColors.ink;
    final subColor = onNavy ? AppColors.onNavyMuted : AppColors.inkMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: AppColors.gold),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: onNavy ? AppColors.gold : AppColors.goldDeep,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: text.headlineSmall?.copyWith(color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!, style: text.bodyMedium?.copyWith(color: subColor)),
        ],
      ],
    );
  }
}

/// Circular barangay seal. Falls back to a branded monogram when the
/// asset is not bundled yet.
class SealBadge extends StatelessWidget {
  const SealBadge({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyDeep,
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/conde labac logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'CL',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.32,
                ),
          ),
        ),
      ),
    );
  }
}

/// Pill badge: "🏛 OFFICIAL DIGITAL PORTAL · BATANGAS CITY"
class PortalBadge extends StatelessWidget {
  const PortalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_outlined,
              size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppStrings.portalBadge,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
