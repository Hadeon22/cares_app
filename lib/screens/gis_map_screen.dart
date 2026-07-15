import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/stores.dart';
import '../gis/gis_map_view.dart';
import '../widgets/form_widgets.dart';

/// Community GIS Map — the barangay's boundary, buildings, roads,
/// vegetation, and waterways rendered from the same GeoJSON data as the
/// web system. Below the map: the Recent Community Reports feed and the
/// AI Narrative Report panel (web pages/gis.html layout).
class GisMapScreen extends StatelessWidget {
  const GisMapScreen({super.key, this.focusPoint});

  /// Optional normalized point to center on (blotter "View on Map").
  final Offset? focusPoint;

  /// Centered dialog with the report's details (replaces the old
  /// bottom sheet).
  static void showReportDialog(BuildContext context, IncidentReport report) {
    final text = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Row(
          children: [
            Expanded(
              child: Text(report.typeLabel,
                  style: text.titleMedium?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
            StatusBadge(
              report.resolved ? 'Resolved' : 'Active',
              kind: report.resolved ? BadgeKind.success : BadgeKind.danger,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.caseNo} · ${report.complainant}\n'
              '${MaterialLocalizations.of(ctx).formatMediumDate(report.createdAt)}',
              style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(report.narration,
                style: text.bodySmall
                    ?.copyWith(color: AppColors.ink, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        // ── Map ─────────────────────────────────────────────────
        Container(
          height: 400,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: GisMapView(
            focusPoint: focusPoint,
            onPinTap: (r) => showReportDialog(context, r),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This map is for reference only. For precise coordinates, contact '
          'the barangay GIS officer. Tap a pin to view the report.',
          style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Recent community reports (web renderReportFeed) ─────
        _SectionCard(
          title: 'Recent Community Reports',
          child: AnimatedBuilder(
            animation: IncidentStore.instance,
            builder: (context, _) {
              final reports = IncidentStore.instance.all;
              if (reports.isEmpty) {
                return Text(
                  'No community reports yet. Reports filed through the '
                  'Blotter service appear here and as pins on the map.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.inkMuted, height: 1.5),
                );
              }
              return Column(
                children: [
                  for (final r in reports)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: () => showReportDialog(context, r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place,
                              size: 20,
                              color: r.resolved
                                  ? const Color(0xFF16A34A)
                                  : AppColors.flagRed,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.typeLabel,
                                      style: text.labelLarge?.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    '${r.caseNo} · ${r.complainant} · '
                                    '${MaterialLocalizations.of(context).formatShortMonthDay(r.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelSmall?.copyWith(
                                        color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              r.resolved ? 'Resolved' : 'Active',
                              kind: r.resolved
                                  ? BadgeKind.success
                                  : BadgeKind.danger,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── AI narrative report (placeholder container) ─────────
        _SectionCard(
          title: 'AI Narrative Report',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'No narrative report generated yet.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm + 4),
          child,
        ],
      ),
    );
  }
}
