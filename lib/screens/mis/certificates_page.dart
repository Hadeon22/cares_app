import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../screens/services/certificate_request_screen.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Certificate Processing module (js/pages/certificates.js) — the live
/// request queue from the certificate table, with approve action.
class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  static const _badges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.info,
    'issued': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  Future<void> _approve(BuildContext context, CertificateRequest r) async {
    try {
      await CertificateStore.instance.setStatus(r, 'approved',
          accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'CERT_APPROVE',
      '${r.typeLabel} (${r.requestNo}) approved for ${r.applicant}',
      category: AuditCategory.certificate,
    );
    if (context.mounted) showAppToast(context, '${r.requestNo} approved!');
  }

  @override
  Widget build(BuildContext context) {
    final store = CertificateStore.instance;
    store.ensureLoaded();
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final requests = store.all;
        final text = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Certificate Processing',
              desc: 'Manage, approve, and issue barangay certificates',
            ),
            KpiGrid(cards: [
              KpiCard(
                  label: 'Pending Review',
                  value: '${store.byStatus('pending')}',
                  accent: KpiAccent.warning),
              KpiCard(
                  label: 'Issued',
                  value: '${store.byStatus('issued')}',
                  accent: KpiAccent.success),
              KpiCard(label: 'Total This Year', value: '${store.filedThisYear}'),
              KpiCard(
                  label: 'Rejected',
                  value: '${store.byStatus('rejected')}',
                  accent: KpiAccent.danger),
            ]),
            MisCard(
              title: 'Certificate Requests',
              action: '⊕ New Request',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CertificateRequestScreen())),
              child: store.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null
                      ? EmptyState(
                          'Could not load certificate requests.\n${store.error}')
                      : requests.isEmpty
                          ? const EmptyState(
                              'No certificate requests yet. Requests filed '
                              'from the app or web portal appear here.')
                          : Column(
                              children: [
                                for (final r in requests)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    padding:
                                        const EdgeInsets.all(AppSpacing.sm + 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(r.requestNo,
                                                  style: text.labelSmall
                                                      ?.copyWith(
                                                          color: AppColors
                                                              .inkMuted,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.4)),
                                            ),
                                            StatusBadge(
                                              r.status[0].toUpperCase() +
                                                  r.status.substring(1),
                                              kind: _badges[r.status] ??
                                                  BadgeKind.gray,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(r.applicant,
                                            style: text.titleSmall?.copyWith(
                                                color: AppColors.ink,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                          '${r.typeLabel} · Filed '
                                          '${MaterialLocalizations.of(context).formatMediumDate(r.createdAt)}',
                                          style: text.bodySmall?.copyWith(
                                              color: AppColors.inkMuted),
                                        ),
                                        if (r.purpose.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(r.purpose,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: text.labelSmall?.copyWith(
                                                  color: AppColors.inkMuted)),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: () => showAppToast(
                                                  context,
                                                  'Viewing ${r.requestNo}'),
                                              child: const Text('View'),
                                            ),
                                            if (r.status == 'pending')
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: AppSpacing.md,
                                                      vertical: 8),
                                                ),
                                                onPressed: () =>
                                                    _approve(context, r),
                                                child: const Text('Approve'),
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
