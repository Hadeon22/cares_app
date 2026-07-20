import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/stores.dart';
import 'photo_picker.dart';

/// Centered leadership card — the mobile twin of the landing page's
/// .official-card (avatar, name, role, description).
class OfficialCard extends StatelessWidget {
  const OfficialCard({super.key, required this.official});

  final Official official;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final o = official;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ResidentAvatar(initials: o.initials, photo: o.photo, radius: 34),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            o.displayName,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            o.role,
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(
              color: AppColors.goldDeep,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          if (o.desc.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              o.desc,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
