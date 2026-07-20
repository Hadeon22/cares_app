import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/models.dart';

/// Clean, informative announcement card with tag chip and date.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = announcement;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () {},
        child: Ink(
          decoration: BoxDecoration(
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: a.tagColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      a.tag.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: a.tagColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    MaterialLocalizations.of(context).formatShortDate(
                        a.createdAt),
                    style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(
                a.title,
                style: text.titleSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                a.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
