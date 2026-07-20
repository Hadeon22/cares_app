import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../screens/gis_map_screen.dart';
import '../../screens/services/incident_report_screen.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/paginator.dart';
import 'mis_widgets.dart';

/// Blotter / Incident Reports module (js/pages/incidents.js) — driven
/// by the shared IncidentStore, with resolve/reopen actions.
class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key});

  /// Permanently delete a blotter entry (gated by Delete Permissions).
  Future<void> _delete(BuildContext context, IncidentReport r) async {
    final ok = await confirmDelete(
      context,
      title: 'Delete ${r.caseNo}?',
      message: 'This permanently removes the ${r.typeLabel} report and its '
          'map pin. This cannot be undone.',
    );
    if (!ok || !context.mounted) return;
    try {
      await IncidentStore.instance
          .delete(r, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'INCIDENT_DELETE',
      '${r.typeLabel} (${r.caseNo}) deleted',
      level: AuditLevel.warning,
      category: AuditCategory.concern,
    );
    if (context.mounted) {
      showAppToast(context, '${r.caseNo} deleted', icon: Icons.delete_outline);
    }
  }

  /// Full blotter entry — the record + narration, opened by tapping a card.
  void _viewIncident(BuildContext context, IncidentReport r) {
    final loc = MaterialLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    showMisDetailSheet(
      context,
      title: r.caseNo,
      badge: StatusBadge(
        r.resolved ? 'Resolved' : 'Active',
        kind: r.resolved ? BadgeKind.success : BadgeKind.danger,
      ),
      rows: [
        ('Type', r.typeLabel),
        ('Complainant', r.complainant),
        ('Contact', r.contact),
        ('Respondent', r.respondent),
        ('Witnesses', r.witnesses),
        ('Location', r.location),
        ('Filed By', r.isOfficial ? 'Barangay Official' : 'Resident'),
        ('Filed', loc.formatMediumDate(r.createdAt)),
      ],
      extra: [
        const SizedBox(height: AppSpacing.sm),
        Text('Narration',
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 2),
        Text(r.narration.isEmpty ? '—' : r.narration,
            style: text.bodyMedium?.copyWith(color: AppColors.ink, height: 1.4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = IncidentStore.instance;
    store.ensureLoaded();
    DeletePermissions.instance.ensureLoaded();
    return AnimatedBuilder(
      animation: Listenable.merge([store, DeletePermissions.instance]),
      builder: (context, _) {
        final reports = store.all;
        final canDelete = canDeleteModule('incidents');
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
              child: store.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null
                      ? EmptyState('Could not load incidents.\n${store.error}')
                      : reports.isEmpty
                          ? const EmptyState(
                              'No incidents filed yet. Use File Incident to '
                              'log one — it appears here and in the GIS '
                              'Recent Community Reports feed.')
                  : PaginatedColumn<IncidentReport>(
                      items: reports,
                      itemLabel: 'entry',
                      itemBuilder: (context, r) =>
                          Container(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              // Tap to see the full blotter entry + narration.
                              onTap: () => _viewIncident(context, r),
                              child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm + 4),
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
                                    // Delete: icon-only, right of the status
                                    // badge and about its size (when allowed).
                                    if (canDelete)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4),
                                        child: DeleteIconButton(
                                          size: 18,
                                          onPressed: () => _delete(context, r),
                                        ),
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
                                          store.setResolved(r.caseNo, false,
                                              accountId: AppSession
                                                  .instance.accountId);
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
                                          store.setResolved(r.caseNo, true,
                                              accountId: AppSession
                                                  .instance.accountId);
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
                            ),
                          ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
