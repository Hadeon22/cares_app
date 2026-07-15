import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../screens/services/feedback_screen.dart';
import '../../widgets/charts.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Feedback Management module (js/pages/feedback.js) — sentiment KPIs,
/// category breakdown, and the recent feedback list from the shared store.
class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FeedbackStore.instance;
    store.ensureLoaded();
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final all = store.all;
        final total = all.length;
        final avg =
            total == 0 ? 0.0 : all.fold<int>(0, (s, f) => s + f.rating) / total;
        final now = DateTime.now();
        final thisMonth = all
            .where((f) => f.ts.year == now.year && f.ts.month == now.month)
            .length;

        // Sentiment split: 4–5 positive, 3 neutral, 1–2 negative.
        var pos = 0, neu = 0, neg = 0;
        for (final f in all) {
          if (f.rating >= 4) {
            pos++;
          } else if (f.rating == 3) {
            neu++;
          } else {
            neg++;
          }
        }

        final text = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Feedback Management',
              desc: 'Resident sentiment trends and submitted comments',
            ),
            KpiGrid(cards: [
              KpiCard(
                  label: 'Avg. Rating',
                  value: '${avg.toStringAsFixed(1)}★',
                  trend: '$total submission${total == 1 ? '' : 's'} total',
                  accent: KpiAccent.success),
              KpiCard(label: 'Total Submissions', value: '$total'),
              KpiCard(
                  label: 'This Month',
                  value: '$thisMonth',
                  accent: KpiAccent.info),
              KpiCard(
                  label: 'Unreviewed',
                  value: '${store.unreviewedCount}',
                  accent: KpiAccent.warning),
            ]),
            MisCard(
              title: 'Sentiment Breakdown',
              child: DonutChart(
                isPie: true,
                data: [
                  ChartSlice(
                      'Positive', pos.toDouble(), const Color(0xFF22C55E)),
                  ChartSlice(
                      'Neutral', neu.toDouble(), const Color(0xFF94A3B8)),
                  ChartSlice(
                      'Negative', neg.toDouble(), const Color(0xFFEF4444)),
                ],
              ),
            ),
            MisCard(
              title: 'By Category',
              child: HBarList(data: [
                for (final c in kFeedbackCategories)
                  ChartSlice(c, store.countInCategory(c).toDouble(),
                      AppColors.gold),
              ]),
            ),
            MisCard(
              title: 'Recent Feedback',
              action: '⊕ Submit Feedback',
              onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              child: store.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null
                      ? EmptyState('Could not load feedback.\n${store.error}')
                      : all.isEmpty
                          ? const EmptyState(
                              'No feedback submitted yet. Submissions from '
                              'residents will appear here.')
                  : Column(
                      children: [
                        for (final f in all)
                          Container(
                            width: double.infinity,
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.sm + 4),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 1; i <= 5; i++)
                                          Icon(
                                            i <= f.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 15,
                                            color: i <= f.rating
                                                ? AppColors.gold
                                                : AppColors.divider,
                                          ),
                                      ],
                                    ),
                                    StatusBadge(f.category,
                                        kind: BadgeKind.gray),
                                    Text(
                                      '${f.name} · '
                                      '${MaterialLocalizations.of(context).formatShortMonthDay(f.ts)}',
                                      style: text.labelSmall
                                          ?.copyWith(color: AppColors.inkMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(f.comment,
                                    style: text.bodySmall?.copyWith(
                                        color: AppColors.ink, height: 1.45)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
