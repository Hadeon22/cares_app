import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';
import '../core/utils/fade_slide.dart';
import 'common.dart';

/// Navy hero: badge, "C.A.R.E.S." display title, subtitle, description
/// and the two primary CTAs — a mobile-first take on the web hero.
class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.onExploreServices,
    required this.onViewGisMap,
  });

  final VoidCallback onExploreServices;
  final VoidCallback onViewGisMap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyDeep],
        ),
        border: Border(bottom: BorderSide(color: AppColors.gold, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeSlide(child: PortalBadge()),
          const SizedBox(height: AppSpacing.lg),
          FadeSlide(
            delay: const Duration(milliseconds: 90),
            child: Hero(
              tag: 'cares-wordmark',
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  AppStrings.appAcronym,
                  style: text.displaySmall?.copyWith(
                    color: AppColors.onNavy,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlide(
            delay: const Duration(milliseconds: 160),
            child: Text(
              AppStrings.appFullName.toUpperCase(),
              style: text.titleSmall?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlide(
            delay: const Duration(milliseconds: 230),
            child: Text(
              L.text.heroDescription,
              style: text.bodyMedium?.copyWith(color: AppColors.onNavyMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlide(
            delay: const Duration(milliseconds: 300),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onExploreServices,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Explore Services'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewGisMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('View GIS Map'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
