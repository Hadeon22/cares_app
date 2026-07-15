import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import 'common.dart';

/// Elegant photo card of the Barangay Hall with the seal floating on the
/// corner and a caption ribbon — echoes the framed photo on the web hero.
class BarangayHallCard extends StatelessWidget {
  const BarangayHallCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                'assets/images/brgy_hall_img.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navyLight, AppColors.navy],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.account_balance,
                        size: 64, color: AppColors.navyBorder),
                  ),
                ),
              ),
            ),
            // Bottom scrim + caption
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.navyDeep.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(top: 12, right: 12, child: SealBadge(size: 52)),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppStrings.hallCaption.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: AppColors.onNavy,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
