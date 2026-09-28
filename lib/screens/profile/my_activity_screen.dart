import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/offline_queue.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/certificate_fields_sheet.dart';
import '../../widgets/form_widgets.dart';
import '../services/certificate_request_screen.dart';

/// "My Activity" — everything this account has sent the barangay, newest
/// first.
///
/// This replaces the separate "My Requests" and "Activity History" screens.
/// They answered one question — *what did I send in, and what happened to it?*
/// — and splitting it across two menu entries meant checking both and
/// interleaving the dates by eye. Four sources feed one list:
///
///   • certificate requests   CertificateStore  (+ the offline queue)
///   • profile edit requests  /api/edit-requests?resident_id=
///   • incident reports       IncidentStore     (+ the offline queue)
///   • feedback given         FeedbackStore
///
/// The certificate rows keep their "Certificate details" action — it is the
/// only place a requester can fill in the blanks the printed form needs.
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

/// One timeline row, normalized from whichever store produced it.
class _Activity {
  const _Activity({
    required this.ts,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeKind,
    this.ref,
    this.action,
  });

  final DateTime ts;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final BadgeKind badgeKind;

  /// Case / request number, when the record has one.
  final String? ref;

  /// Optional row action (certificate rows use it for the fields sheet).
  final Widget? action;
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  static const _certBadges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.info,
    'issued': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  static const _editBadges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  static const _editFieldLabels = {
    'last_name': 'Last Name',
    'first_name': 'First Name',
    'middle_name': 'Middle Name',
    'suffix': 'Suffix',
    'birthdate': 'Birthdate',
    'sex': 'Sex',
    'civil_status': 'Civil Status',
    'contact_no': 'Contact No.',
    'occupation': 'Occupation',
    'voter_status': 'Voter Status',
    'photo': 'Profile Photo',
  };

  /// Profile edit requests are not in a long-lived store (the staff store
  /// holds everyone's), so this screen fetches its own and holds them here.
  List<ResidentEditRequest> _editRequests = const [];
  bool _editRequestsFailed = false;

  @override
  void initState() {
    super.initState();
    CertificateStore.instance.ensureLoaded();
    IncidentStore.instance.ensureLoaded();
    FeedbackStore.instance.ensureLoaded();
    _loadEditRequests();
  }

  Future<void> _loadEditRequests() async {
    final residentId = AppSession.instance.residentId;
    if (residentId == null) return;
    try {
      final rows = await EditRequestStore.instance.forResident(residentId);
      if (!mounted) return;
      setState(() {
        _editRequests = rows;
        _editRequestsFailed = false;
      });
    } catch (_) {
      // One source failing must not empty the whole list — the others still
      // render, and the row simply reports itself as unavailable.
      if (!mounted) return;
      setState(() => _editRequestsFailed = true);
    }
  }

  Future<void> _refresh() => Future.wait([
        CertificateStore.instance.refresh(),
        IncidentStore.instance.refresh(),
        FeedbackStore.instance.refresh(),
        _loadEditRequests(),
      ]);

  List<_Activity> _buildTimeline(BuildContext context) {
    final session = AppSession.instance;
    final items = <_Activity>[];

    if (session.residentId != null) {
      // ── Certificate requests ──
      for (final r in CertificateStore.instance.all) {
        if (r.residentId != session.residentId) continue;
        items.add(_Activity(
          ts: r.createdAt,
          icon: Icons.description_outlined,
          title: r.typeLabel,
          ref: r.requestNo,
          subtitle: [
            if (r.purpose.isNotEmpty) r.purpose,
            if (r.remarks != null && r.remarks!.isNotEmpty)
              'Barangay note: ${r.remarks}',
          ].join(' · '),
          badge: r.status[0].toUpperCase() + r.status.substring(1),
          badgeKind: _certBadges[r.status] ?? BadgeKind.gray,
          action: r.type.isPrintable && r.id > 0
              ? OutlinedButton.icon(
                  onPressed: () => showCertificateFieldsSheet(
                    context,
                    r,
                    readOnly: r.status == 'issued' || r.status == 'rejected',
                  ),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: Text(
                    r.status == 'issued' || r.status == 'rejected'
                        ? 'View certificate details'
                        : 'Certificate details',
                  ),
                )
              : null,
        ));
      }

      // ── Profile change requests ──
      for (final q in _editRequests) {
        final fields = q.changes.keys
            .map((k) => _editFieldLabels[k] ?? k)
            .join(', ');
        items.add(_Activity(
          ts: q.createdAt,
          icon: Icons.manage_accounts_outlined,
          title: 'Profile change: ${fields.isEmpty ? '—' : fields}',
          // The reason given is the useful line while it is being decided; a
          // rejection's remarks replace it, because that is the part that
          // says what to do next.
          subtitle: q.status == 'rejected' && (q.remarks ?? '').isNotEmpty
              ? 'Remarks: ${q.remarks}'
              : (q.reason ?? ''),
          badge: q.status[0].toUpperCase() + q.status.substring(1),
          badgeKind: _editBadges[q.status] ?? BadgeKind.gray,
        ));
      }

      // ── Incident reports ──
      for (final r in IncidentStore.instance.all) {
        if (r.complainantId != session.residentId) continue;
        items.add(_Activity(
          ts: r.createdAt,
          icon: Icons.report_outlined,
          title: 'Reported: ${r.typeLabel}',
          ref: r.caseNo,
          subtitle: r.narration,
          badge: r.resolved ? 'Resolved' : 'Open',
          badgeKind: r.resolved ? BadgeKind.success : BadgeKind.warning,
        ));
      }
    }

    // ── Feedback ──
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

    // ── Still in the offline queue ──
    // Both kinds, so "I filed that yesterday" is answered even when it never
    // reached the server.
    if (session.residentId != null) {
      for (final q in OfflineQueue.instance.ofKind('certificate')) {
        if (q.body['resident_id'] != session.residentId) continue;
        items.add(_Activity(
          ts: q.createdAt,
          icon: Icons.cloud_upload_outlined,
          title: certificateTypeByKey((q.body['type'] ?? '') as String).name,
          subtitle: 'Will be submitted automatically when you are back online.',
          badge: 'Waiting to sync',
          badgeKind: BadgeKind.gold,
        ));
      }
      for (final q in OfflineQueue.instance.ofKind('incident')) {
        if (q.body['complainant_id'] != session.residentId) continue;
        items.add(_Activity(
          ts: q.createdAt,
          icon: Icons.cloud_upload_outlined,
          title: 'Reported: '
              '${incidentTypeByKey((q.body['report_type'] ?? '') as String).label}',
          subtitle: (q.body['narration'] ?? '') as String,
          badge: 'Waiting to sync',
          badgeKind: BadgeKind.gold,
        ));
      }
    }

    items.sort((a, b) => b.ts.compareTo(a.ts));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Activity')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CertificateRequestScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          CertificateStore.instance,
          IncidentStore.instance,
          FeedbackStore.instance,
          OfflineQueue.instance,
        ]),
        builder: (context, _) {
          final certs = CertificateStore.instance;
          final incidents = IncidentStore.instance;
          final feedback = FeedbackStore.instance;
          final loading = (certs.loading && !certs.loaded) ||
              (incidents.loading && !incidents.loaded) ||
              (feedback.loading && !feedback.loaded);
          if (loading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }

          if (AppSession.instance.residentId == null &&
              AppSession.instance.accountId == null) {
            return _message(
              context,
              icon: Icons.badge_outlined,
              title: 'No linked resident record',
              body: 'Your activity is tracked through your barangay record. '
                  'This account is not linked to one.',
            );
          }

          final items = _buildTimeline(context);
          if (items.isEmpty) {
            final error = certs.error ?? incidents.error ?? feedback.error;
            return _message(
              context,
              icon: Icons.inbox_outlined,
              title: error == null ? 'Nothing yet' : 'Could not load your activity',
              body: error ??
                  'Certificates you request, changes you propose to your '
                      'details, incidents you report, and feedback you send '
                      'all appear here.',
              action: error == null
                  ? null
                  : TextButton(
                      onPressed: _refresh, child: const Text('Retry')),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.gold,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl + 56),
              // +1 for the "some of it didn't load" note, when there is one.
              itemCount: items.length + (_editRequestsFailed ? 1 : 0),
              itemBuilder: (context, i) {
                if (_editRequestsFailed && i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AlertBanner(
                      kind: AlertKind.warning,
                      child: Text('Could not load your profile change '
                          'requests. Everything else is up to date.'),
                    ),
                  );
                }
                final a = items[i - (_editRequestsFailed ? 1 : 0)];
                return _card(context, a, text);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, _Activity a, TextTheme text) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: a.badge == 'Waiting to sync'
            ? AppColors.goldSoft
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
            color: a.badge == 'Waiting to sync'
                ? AppColors.gold
                : AppColors.divider),
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
            child: Icon(a.icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: text.titleSmall?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w700)),
                if (a.ref != null) ...[
                  const SizedBox(height: 2),
                  Text(a.ref!,
                      style: text.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ],
                if (a.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    a.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(a.badge, kind: a.badgeKind),
                    Text(
                      MaterialLocalizations.of(context).formatMediumDate(a.ts),
                      style:
                          text.labelSmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
                if (a.action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  a.action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context,
      {required IconData icon,
      required String title,
      required String body,
      Widget? action}) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: AppColors.ink)),
            const SizedBox(height: AppSpacing.sm),
            Text(body,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
