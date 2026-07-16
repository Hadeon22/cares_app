import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/offline_queue.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/form_widgets.dart';
import '../services/certificate_request_screen.dart';

/// "My Requests" — the certificate requests this account has filed, straight
/// from the shared certificate table (matched by the session's resident_id).
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  static const _statusBadges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.info,
    'issued': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  @override
  void initState() {
    super.initState();
    CertificateStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final residentId = AppSession.instance.residentId;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CertificateRequestScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [CertificateStore.instance, OfflineQueue.instance]),
        builder: (context, _) {
          final store = CertificateStore.instance;
          final mine = residentId == null
              ? <CertificateRequest>[]
              : store.all.where((r) => r.residentId == residentId).toList();
          // Requests filed while offline, still waiting to reach the server.
          final queued = OfflineQueue.instance
              .ofKind('certificate')
              .where((q) =>
                  residentId != null && q.body['resident_id'] == residentId)
              .toList();

          if (store.loading && !store.loaded) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (store.error != null && !store.loaded) {
            return _message(
              context,
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your requests',
              body: store.error!,
              action: TextButton(
                  onPressed: store.refresh, child: const Text('Retry')),
            );
          }
          if (residentId == null) {
            return _message(
              context,
              icon: Icons.badge_outlined,
              title: 'No linked resident record',
              body: 'Requests are tracked through your barangay record. '
                  'This account is not linked to one.',
            );
          }
          if (mine.isEmpty && queued.isEmpty) {
            return _message(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'No requests yet',
              body: 'Certificates and clearances you request will appear '
                  'here so you can track their status.',
            );
          }

          return RefreshIndicator(
            onRefresh: store.refresh,
            color: AppColors.gold,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl + 56),
              itemCount: queued.length + mine.length,
              itemBuilder: (context, i) {
                if (i < queued.length) return _queuedCard(context, queued[i]);
                final r = mine[i - queued.length];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                            child: Text(r.requestNo,
                                style: text.labelSmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4)),
                          ),
                          StatusBadge(
                            r.status[0].toUpperCase() + r.status.substring(1),
                            kind: _statusBadges[r.status] ?? BadgeKind.gray,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r.typeLabel,
                          style: text.titleSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'Filed ${MaterialLocalizations.of(context).formatMediumDate(r.createdAt)}',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                      if (r.purpose.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          r.purpose,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
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

  /// Card for a request still parked in the offline queue.
  Widget _queuedCard(BuildContext context, QueuedSubmission q) {
    final text = Theme.of(context).textTheme;
    final type = certificateTypeByKey((q.body['type'] ?? '') as String);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('WAITING TO SYNC',
                    style: text.labelSmall?.copyWith(
                        color: AppColors.goldDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
              ),
              const StatusBadge('Queued', kind: BadgeKind.gold),
            ],
          ),
          const SizedBox(height: 4),
          Text(type.name,
              style: text.titleSmall?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Saved ${MaterialLocalizations.of(context).formatMediumDate(q.createdAt)}'
            ' — will be submitted automatically when you\'re back online.',
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
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
