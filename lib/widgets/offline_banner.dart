import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/api_client.dart';
import '../data/offline_queue.dart';

/// Slim banner shown while the server is unreachable — used by both the
/// portal shell and the MIS shell. Mentions any queued submissions so the
/// user knows their request isn't lost; tapping retries the connection.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiClient.instance.offline,
      builder: (context, offline, _) {
        if (!offline) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: OfflineQueue.instance,
          builder: (context, _) {
            final queued = OfflineQueue.instance.items.length;
            return Material(
              color: AppColors.navyDeep,
              child: InkWell(
                onTap: () => ApiClient.instance.ping(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 16, color: AppColors.gold),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          queued > 0
                              ? 'Offline mode — $queued submission'
                                  '${queued == 1 ? '' : 's'} will sync when '
                                  'back online.'
                              : 'Offline mode — showing saved data. '
                                  'Tap to retry.',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.onNavy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
