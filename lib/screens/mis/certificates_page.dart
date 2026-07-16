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

  /// Move a request to [status] — used for Approve, Reject and Undo
  /// (undo = back to pending; the server allows it and re-notifies the
  /// requester that their request is under review again).
  Future<void> _setStatus(
      BuildContext context, CertificateRequest r, String status) async {
    try {
      await CertificateStore.instance.setStatus(r, status,
          accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    const actions = {
      'approved': 'CERT_APPROVE',
      'rejected': 'CERT_REJECT',
      'pending': 'CERT_UNDO',
      'issued': 'CERT_ISSUE',
    };
    AuditLog.instance.log(
      actions[status] ?? 'CERT_UPDATE',
      '${r.typeLabel} (${r.requestNo}) → $status for ${r.applicant}',
      category: AuditCategory.certificate,
    );
    if (context.mounted) {
      showAppToast(
          context,
          status == 'pending'
              ? '${r.requestNo} moved back to pending.'
              : '${r.requestNo} $status!');
    }
  }

  /// Send an in-app message to the requester — lands in their notification
  /// bell (only possible when the request is linked to a resident account).
  Future<void> _messageRequester(
      BuildContext context, CertificateRequest r) async {
    final ctrl = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message ${r.applicant.split(',').first}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'e.g. Please bring a valid ID when picking up '
                'your ${r.typeLabel}.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send'),
          ),
        ],
      ),
    );
    if (message == null || message.isEmpty || !context.mounted) return;
    try {
      await NotificationStore.send(
        residentId: r.residentId,
        title: 'Message from the Barangay Office',
        body: message,
        ref: r.requestNo,
      );
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'CERT_MESSAGE',
      'Message sent to ${r.applicant} re ${r.requestNo}',
      category: AuditCategory.certificate,
    );
    if (context.mounted) {
      showAppToast(context, 'Message sent to ${r.applicant.split(',').first}',
          icon: Icons.mark_email_read_outlined);
    }
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
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (r.status == 'pending') ...[
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: AppSpacing.md,
                                                      vertical: 8),
                                                ),
                                                onPressed: () => _setStatus(
                                                    context, r, 'approved'),
                                                child: const Text('Approve'),
                                              ),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.flagRed),
                                                onPressed: () => _setStatus(
                                                    context, r, 'rejected'),
                                                child: const Text('Reject'),
                                              ),
                                            ] else if (r.status == 'approved' ||
                                                r.status == 'rejected')
                                              TextButton.icon(
                                                onPressed: () => _setStatus(
                                                    context, r, 'pending'),
                                                icon: const Icon(Icons.undo,
                                                    size: 16),
                                                label: const Text('Undo'),
                                              ),
                                            if (r.residentId != null)
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _messageRequester(
                                                        context, r),
                                                icon: const Icon(
                                                    Icons.mail_outline,
                                                    size: 16),
                                                label: const Text('Message'),
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
