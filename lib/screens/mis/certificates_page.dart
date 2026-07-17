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
      BuildContext context, CertificateRequest r, String status,
      {String? remarks}) async {
    try {
      await CertificateStore.instance.setStatus(r, status,
          remarks: remarks, accountId: AppSession.instance.accountId);
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

  /// Reject a request — a remark is required so the requester learns why.
  /// The remark is persisted via [setStatus]'s `remarks` (certificate table
  /// `remarks` column) alongside the rejected status.
  Future<void> _rejectWithRemark(
      BuildContext context, CertificateRequest r) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${r.requestNo}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a remark explaining why ${r.applicant.split(',').first}\'s '
                'request is being rejected. This is saved with the request.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Incomplete requirements — missing valid ID.',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'A remark is required to reject.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(ctrl.text.trim());
              }
            },
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
    if (remark == null || remark.isEmpty || !context.mounted) return;
    await _setStatus(context, r, 'rejected', remarks: remark);
  }

  /// Read-only detail sheet — the full request + requester information,
  /// mirroring the web map's View modal (openViewCert in certificates.js).
  void _viewRequest(BuildContext context, CertificateRequest r) {
    final loc = MaterialLocalizations.of(context);
    String date(DateTime? d) => d == null ? '—' : loc.formatMediumDate(d);
    showMisDetailSheet(
      context,
      title: r.requestNo,
      badge: StatusBadge(
        r.status[0].toUpperCase() + r.status.substring(1),
        kind: _badges[r.status] ?? BadgeKind.gray,
      ),
      rows: [
        ('Applicant', r.applicant),
        ('Type', r.typeLabel),
        ('Filed', date(r.createdAt)),
        ('Purpose / Details', r.purpose),
        ('Remarks', r.remarks),
        ('Processed By', r.processedByName),
        ('Processed At', date(r.processedAt)),
        ('Linked Resident', r.residentId == null ? null : '#${r.residentId}'),
      ],
      actions: [
        if (r.residentId != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _messageRequester(context, r);
            },
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('Message'),
          ),
      ],
    );
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
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      // Tap the card to see the full request +
                                      // requester detail (the old View button).
                                      onTap: () => _viewRequest(context, r),
                                      child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.sm + 4),
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
                                        const SizedBox(height: 8),
                                        // Actions on a single row — compact
                                        // buttons. Full detail is a card tap.
                                        Row(
                                          children: [
                                            if (r.status == 'pending') ...[
                                              _CertActionButton(
                                                icon: Icons.check,
                                                label: 'Approve',
                                                filled: true,
                                                onPressed: () => _setStatus(
                                                    context, r, 'approved'),
                                              ),
                                              const SizedBox(width: 6),
                                              _CertActionButton(
                                                icon: Icons.block,
                                                label: 'Reject',
                                                danger: true,
                                                onPressed: () =>
                                                    _rejectWithRemark(
                                                        context, r),
                                              ),
                                            ] else if (r.status == 'approved' ||
                                                r.status == 'rejected') ...[
                                              _CertActionButton(
                                                icon: Icons.undo,
                                                label: 'Undo',
                                                onPressed: () => _setStatus(
                                                    context, r, 'pending'),
                                              ),
                                            ],
                                            if (r.residentId != null) ...[
                                              if (r.status != 'issued')
                                                const SizedBox(width: 6),
                                              _CertActionButton(
                                                icon: Icons.mail_outline,
                                                label: 'Message',
                                                onPressed: () =>
                                                    _messageRequester(
                                                        context, r),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    ),
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

/// A compact, equal-width action button for the request card's single-row
/// action strip. Expands to share the row so up to four fit on a phone.
class _CertActionButton extends StatelessWidget {
  const _CertActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
    return Expanded(
      child: filled
          ? FilledButton(
              // Gold fill with navy text — the app's default primary button
              // style, matching the Approve/primary actions on other pages.
              style: FilledButton.styleFrom(
                padding: padding,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 34),
              ),
              onPressed: onPressed,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: padding,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 34),
                foregroundColor: danger ? AppColors.flagRed : AppColors.navy,
                side: BorderSide(
                    color: danger ? AppColors.flagRed : AppColors.divider),
              ),
              onPressed: onPressed,
              child: child,
            ),
    );
  }
}
