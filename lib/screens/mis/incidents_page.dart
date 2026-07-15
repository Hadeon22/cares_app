import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../screens/gis_map_screen.dart';
import '../../screens/services/incident_report_screen.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Blotter / Incident Reports module (js/pages/incidents.js) — driven
/// by the shared IncidentStore, with resolve/reopen actions.
class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = IncidentStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final reports = store.all;
        final text = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Blotter / Incident Reports',
              desc: 'Incidents and community concerns filed by residents — '
                  'logged, tracked, and resolved',
            ),
            KpiGrid(cards: [
              KpiCard(
                  label: 'Active',
                  value: '${store.activeCount}',
                  accent: KpiAccent.danger),
              KpiCard(
                  label: 'Resolved',
                  value: '${store.resolvedCount}',
                  accent: KpiAccent.success),
              KpiCard(label: 'Filed This Month', value: '${store.filedThisMonth}'),
              KpiCard(label: 'Total Blotter Entries', value: '${reports.length}'),
            ]),
            MisCard(
              title: 'Incident Blotter',
              action: '⊕ File Incident',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const IncidentReportScreen())),
              child: reports.isEmpty
                  ? const EmptyState(
                      'No incidents filed yet. Use File Incident to log one — '
                      'it appears here and in the GIS Recent Community '
                      'Reports feed.')
                  : Column(
                      children: [
                        for (final r in reports)
                          Container(
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(r.caseNo,
                                          style: text.labelSmall?.copyWith(
                                              color: AppColors.inkMuted,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4)),
                                    ),
                                    StatusBadge(
                                      r.resolved ? 'Resolved' : 'Active',
                                      kind: r.resolved
                                          ? BadgeKind.success
                                          : BadgeKind.danger,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(r.typeLabel,
                                    style: text.titleSmall?.copyWith(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  '${r.complainant} · '
                                  '${MaterialLocalizations.of(context).formatMediumDate(r.createdAt)}'
                                  '${r.location.isNotEmpty ? ' · ${r.location}' : ''}',
                                  style: text.bodySmall
                                      ?.copyWith(color: AppColors.inkMuted),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        if (r.mapPoint == null) {
                                          showAppToast(context,
                                              '${r.caseNo} has no map pin',
                                              icon: Icons.map_outlined);
                                          return;
                                        }
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => Scaffold(
                                              appBar: AppBar(
                                                  title:
                                                      Text('GIS Map · ${r.caseNo}')),
                                              body: GisMapScreen(
                                                  focusPoint: r.mapPoint),
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('View on Map'),
                                    ),
                                    if (r.resolved)
                                      TextButton(
                                        onPressed: () {
                                          store.setResolved(r.caseNo, false);
                                          showAppToast(
                                              context, 'Incident reopened',
                                              icon: Icons.refresh);
                                        },
                                        child: const Text('Reopen'),
                                      )
                                    else
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: 8),
                                        ),
                                        onPressed: () {
                                          store.setResolved(r.caseNo, true);
                                          showAppToast(context,
                                              'Incident marked as resolved');
                                        },
                                        child: const Text('Resolve'),
                                      ),
                                  ],
                                ),
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
