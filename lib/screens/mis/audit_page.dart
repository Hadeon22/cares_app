import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Audit Logs module (js/pages/audit.js) — the real audit trail recorded
/// by AuditLog across the app, with search + category/level filters.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  String _search = '';
  AuditCategory? _category;
  AuditLevel? _level;

  static const _levelBadges = {
    AuditLevel.info: BadgeKind.info,
    AuditLevel.warning: BadgeKind.warning,
    AuditLevel.critical: BadgeKind.danger,
  };

  static const _categoryBadges = {
    AuditCategory.map: BadgeKind.info,
    AuditCategory.concern: BadgeKind.warning,
    AuditCategory.certificate: BadgeKind.gold,
    AuditCategory.feedback: BadgeKind.success,
    AuditCategory.auth: BadgeKind.gray,
    AuditCategory.archive: BadgeKind.gray,
    AuditCategory.settings: BadgeKind.info,
    AuditCategory.system: BadgeKind.gray,
  };

  List<AuditEntry> _filtered(List<AuditEntry> logs) {
    final q = _search.toLowerCase();
    return logs.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_level != null && e.level != _level) return false;
      if (q.isNotEmpty &&
          !'${e.user} ${e.role} ${e.action} ${e.details}'
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _fmtTs(DateTime d) {
    String p(int n) => '$n'.padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} '
        '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear audit logs?'),
        content: const Text(
            'Clear all audit log entries? This cannot be undone. The wipe '
            'itself is recorded and stays on the trail for 90 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear Logs')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AuditLog.instance.clear();
    // The wipe itself is an auditable event — first entry of the new trail.
    // AUDIT_CLEAR markers survive later clears and expire after 90 days.
    AuditLog.instance.log(
      AuditLog.clearAction,
      'Audit log cleared by administrator',
      level: AuditLevel.critical,
      category: AuditCategory.system,
    );
    showAppToast(context, 'Audit log cleared', icon: Icons.delete_outline);
  }

  @override
  Widget build(BuildContext context) {
    // Pulls the shared DB trail (web + app + trigger rows) on first open.
    AuditLog.instance.ensureLoaded();
    return AnimatedBuilder(
      animation: AuditLog.instance,
      builder: (context, _) {
        final logs = AuditLog.instance.entries;
        final dayStart = DateTime.now();
        final todayStart =
            DateTime(dayStart.year, dayStart.month, dayStart.day);
        final monthAgo =
            DateTime.now().subtract(const Duration(days: 30));
        final logsToday =
            logs.where((l) => !l.ts.isBefore(todayStart)).length;
        final critical30d = logs
            .where((l) =>
                !l.ts.isBefore(monthAgo) &&
                (l.level == AuditLevel.critical ||
                    l.level == AuditLevel.warning))
            .length;
        final filtered = _filtered(logs);
        final text = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Audit Logs',
              desc: 'System activity, compliance tracking, and data access '
                  'records',
            ),
            KpiGrid(cards: [
              KpiCard(label: 'Logs Today', value: '$logsToday'),
              KpiCard(
                  label: 'Warnings & Critical (30d)',
                  value: '$critical30d',
                  accent: KpiAccent.danger),
              KpiCard(label: 'Total Entries', value: '${logs.length}'),
              KpiCard(
                  label: 'Last Activity',
                  value: logs.isEmpty ? '—' : _timeAgo(logs.first.ts),
                  accent: KpiAccent.success),
            ]),
            MisCard(
              title: 'System Activity Log',
              action: '🗑 Clear Logs',
              onAction: _clearLogs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search user, action, or details...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AuditCategory?>(
                          initialValue: _category,
                          // Long labels ("Resident Concerns", …) must
                          // ellipsize inside the half-width field instead
                          // of overflowing it.
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All Categories')),
                            for (final c in AuditCategory.values)
                              DropdownMenuItem(
                                  value: c,
                                  child: Text(c.label,
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _category = v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<AuditLevel?>(
                          initialValue: _level,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All Levels')),
                            for (final l in AuditLevel.values)
                              DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                      l.name[0].toUpperCase() +
                                          l.name.substring(1),
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _level = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    EmptyState(logs.isEmpty
                        ? 'No activity recorded yet. Actions like certificate '
                            'requests, resident concerns, feedback, logins, '
                            'and archive operations will appear here.'
                        : 'No log entries match your filters.')
                  else
                    for (final e in filtered)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                StatusBadge(e.category.label,
                                    kind: _categoryBadges[e.category] ??
                                        BadgeKind.gray),
                                StatusBadge(e.level.name.toUpperCase(),
                                    kind: _levelBadges[e.level] ??
                                        BadgeKind.gray),
                                Text(_fmtTs(e.ts),
                                    style: text.labelSmall?.copyWith(
                                        color: AppColors.inkMuted)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(e.action,
                                style: text.labelSmall?.copyWith(
                                    color: AppColors.goldDeep,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4)),
                            const SizedBox(height: 2),
                            Text(e.details,
                                style: text.bodySmall?.copyWith(
                                    color: AppColors.ink, height: 1.4)),
                            const SizedBox(height: 2),
                            Text('${e.user} · ${e.role}',
                                style: text.labelSmall
                                    ?.copyWith(color: AppColors.inkMuted)),
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
