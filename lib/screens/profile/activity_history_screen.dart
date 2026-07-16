import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/offline_queue.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/form_widgets.dart';

/// "Activity History" — everything this account has done: incident reports
/// filed and feedback given, merged into one newest-first timeline.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

/// One timeline row, normalized from either store.
class _Activity {
  const _Activity({
    required this.ts,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeKind,
  });

  final DateTime ts;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final BadgeKind badgeKind;
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  @override
  void initState() {
    super.initState();
    IncidentStore.instance.ensureLoaded();
    FeedbackStore.instance.ensureLoaded();
  }

  Future<void> _refresh() => Future.wait(
      [IncidentStore.instance.refresh(), FeedbackStore.instance.refresh()]);

  List<_Activity> _buildTimeline() {
    final session = AppSession.instance;
    final items = <_Activity>[];

    if (session.residentId != null) {
      for (final r in IncidentStore.instance.all) {
        if (r.complainantId != session.residentId) continue;
        items.add(_Activity(
          ts: r.createdAt,
          icon: Icons.report_outlined,
          title: 'Reported: ${r.typeLabel}',
          subtitle: '${r.caseNo} · ${r.narration}',
          badge: r.resolved ? 'Resolved' : 'Open',
          badgeKind: r.resolved ? BadgeKind.success : BadgeKind.warning,
        ));
      }
    }
    if (session.accountId != null) {
      for (final f in FeedbackStore.instance.all) {
        if (f.accountId != session.accountId) continue;
        items.add(_Activity(
          ts: f.ts,
          icon: Icons.rate_review_outlined,
          title: 'Feedback: ${f.category}',
          subtitle: f.comment.isEmpty ? '(no comment)' : f.comment,
          badge: '${f.rating}★ ${kRatingLabels[f.rating]}',
          badgeKind: BadgeKind.gold,
        ));
      }
    }
    // Incident reports filed while offline, still waiting to upload.
    for (final q in OfflineQueue.instance.ofKind('incident')) {
      if (session.residentId == null ||
          q.body['complainant_id'] != session.residentId) {
        continue;
      }
      items.add(_Activity(
        ts: q.createdAt,
        icon: Icons.cloud_upload_outlined,
        title:
            'Reported: ${incidentTypeByKey((q.body['report_type'] ?? '') as String).label}',
        subtitle: (q.body['narration'] ?? '') as String,
        badge: 'Waiting to sync',
        badgeKind: BadgeKind.gold,
      ));
    }
    items.sort((a, b) => b.ts.compareTo(a.ts));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          IncidentStore.instance,
          FeedbackStore.instance,
          OfflineQueue.instance,
        ]),
        builder: (context, _) {
          final incidents = IncidentStore.instance;
          final feedback = FeedbackStore.instance;
          final loading = (incidents.loading && !incidents.loaded) ||
              (feedback.loading && !feedback.loaded);
          if (loading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }

          final items = _buildTimeline();
          if (items.isEmpty) {
            final error = incidents.error ?? feedback.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history,
                        size: 44, color: AppColors.inkMuted),
                    const SizedBox(height: AppSpacing.md),
                    Text('No activity yet',
                        style:
                            text.titleMedium?.copyWith(color: AppColors.ink)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error ??
                          'Incident reports you file and feedback you send '
                              'will show up here.',
                      textAlign: TextAlign.center,
                      style:
                          text.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                          onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.gold,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.divider),
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
                        child:
                            Icon(a.icon, color: AppColors.navy, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                style: text.titleSmall?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              a.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                StatusBadge(a.badge, kind: a.badgeKind),
                                Text(
                                  MaterialLocalizations.of(context)
                                      .formatMediumDate(a.ts),
                                  style: text.labelSmall?.copyWith(
                                      color: AppColors.inkMuted),
                                ),
                              ],
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
