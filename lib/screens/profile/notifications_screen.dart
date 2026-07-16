import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';

/// Notification feed — request status updates and messages from the
/// barangay office. Opening the screen marks everything as read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kindIcons = {
    'certificate': Icons.description_outlined,
    'message': Icons.mail_outline,
    'system': Icons.info_outline,
  };

  @override
  void initState() {
    super.initState();
    final store = NotificationStore.instance;
    // Refresh, then clear the unread badge once the list is on screen.
    store.ensureLoaded().then((_) => store.markAllRead());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AnimatedBuilder(
        animation: NotificationStore.instance,
        builder: (context, _) {
          final store = NotificationStore.instance;
          if (store.loading && !store.loaded) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (store.error != null && store.all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 44, color: AppColors.inkMuted),
                    const SizedBox(height: AppSpacing.md),
                    Text('Could not load notifications',
                        style:
                            text.titleMedium?.copyWith(color: AppColors.ink)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(store.error!,
                        textAlign: TextAlign.center,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.inkMuted)),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                        onPressed: store.refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          if (store.all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none,
                        size: 44, color: AppColors.inkMuted),
                    const SizedBox(height: AppSpacing.md),
                    Text('Nothing here yet',
                        style:
                            text.titleMedium?.copyWith(color: AppColors.ink)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Updates on your requests and messages from the '
                      'barangay office will appear here.',
                      textAlign: TextAlign.center,
                      style:
                          text.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                store.refresh().then((_) => store.markAllRead()),
            color: AppColors.gold,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
              itemCount: store.all.length,
              itemBuilder: (context, i) {
                final n = store.all[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: n.read ? AppColors.surface : AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                        color: n.read ? AppColors.divider : AppColors.gold),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Icon(
                            _kindIcons[n.kind] ?? Icons.info_outline,
                            color: AppColors.navy,
                            size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: text.titleSmall?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700)),
                            if (n.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(n.body,
                                  style: text.bodySmall?.copyWith(
                                      color: AppColors.inkMuted,
                                      height: 1.4)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (n.ref.isNotEmpty) n.ref,
                                MaterialLocalizations.of(context)
                                    .formatMediumDate(n.createdAt),
                              ].join(' · '),
                              style: text.labelSmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
