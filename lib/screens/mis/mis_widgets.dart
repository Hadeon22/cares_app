import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Shared building blocks for the MIS module pages — mobile versions
/// of the web's .page-header, .kpi-card, .card and .timeline styles.

/// Page title + description (web .page-header).
class MisPageHeader extends StatelessWidget {
  const MisPageHeader({super.key, required this.title, required this.desc});

  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: text.headlineSmall?.copyWith(color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(desc,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

enum KpiAccent { none, success, danger, warning, info }

/// KPI stat card (web .kpi-card, accent left border variants).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp,
    this.accent = KpiAccent.none,
  });

  final String label;
  final String value;

  /// Small line under the value, e.g. "+23 this month".
  final String? trend;

  /// True = green trend, false = red trend, null = muted.
  final bool? trendUp;
  final KpiAccent accent;

  static const _accentColors = {
    KpiAccent.none: AppColors.navy,
    KpiAccent.success: Color(0xFF22C55E),
    KpiAccent.danger: Color(0xFFEF4444),
    KpiAccent.warning: Color(0xFFF59E0B),
    KpiAccent.info: Color(0xFF3B82F6),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3.5,
            decoration: BoxDecoration(
              color: _accentColors[accent],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: text.titleLarge?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    trend!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      fontSize: 10,
                      color: trendUp == null
                          ? AppColors.inkMuted
                          : trendUp!
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column KPI grid used at the top of every module page.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.cards});
  final List<KpiCard> cards;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Fixed tile height (not aspect-ratio) so label + value + trend
      // always fit regardless of screen width.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 94,
      ),
      children: cards,
    );
  }
}

/// Content card with a header row and optional action (web .card).
class MisCard extends StatelessWidget {
  const MisCard({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    required this.child,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: text.titleSmall?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800),
                ),
              ),
              if (action != null)
                InkWell(
                  onTap: onAction,
                  child: Text(
                    action!,
                    style: text.labelMedium?.copyWith(
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          child,
        ],
      ),
    );
  }
}

/// Activity timeline row (web .timeline-item).
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.color,
    required this.title,
    required this.meta,
  });

  final Color color;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35)),
                const SizedBox(height: 1),
                Text(meta,
                    style: text.labelSmall
                        ?.copyWith(color: AppColors.inkMuted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One label/value line in a detail dialog. [value] wraps; a null/empty
/// value renders an em dash.
class MisDetailRow extends StatelessWidget {
  const MisDetailRow(this.label, this.value, {super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = (value == null || value!.isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// Read-only detail dialog for a record — the shared "tap a row to see the
/// full record" view used across the MIS module pages. [rows] are
/// (label, value) pairs; [extra] can add non-row content (e.g. a long
/// narration block); [actions] are the dialog's buttons (a Close is added).
void showMisDetailSheet(
  BuildContext context, {
  required String title,
  Widget? badge,
  required List<(String, String?)> rows,
  List<Widget> extra = const [],
  List<Widget> actions = const [],
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: badge == null
          ? Text(title)
          : Row(
              children: [
                Expanded(child: Text(title)),
                const SizedBox(width: 8),
                badge,
              ],
            ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows) MisDetailRow(label, value),
            ...extra,
          ],
        ),
      ),
      actions: [
        ...actions,
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Empty-state box (web .resident-empty).
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.inkMuted, height: 1.5),
      ),
    );
  }
}
