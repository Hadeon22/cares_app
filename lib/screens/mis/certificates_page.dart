import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../screens/services/certificate_request_screen.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Certificate Processing module (js/pages/certificates.js) — request
/// queue with approve action.
class CertificatesPage extends StatefulWidget {
  const CertificatesPage({super.key});

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertRequest {
  _CertRequest(this.no, this.applicant, this.type, this.date, this.status);
  final String no;
  final String applicant;
  final String type;
  final String date;
  String status;
}

class _CertificatesPageState extends State<CertificatesPage> {
  // Seed queue from js/pages/certificates.js.
  final List<_CertRequest> _requests = [
    _CertRequest('CERT-2025-087', 'Santos, Pedro J.', 'Barangay Clearance',
        'May 2, 2025', 'pending'),
    _CertRequest('CERT-2025-086', 'dela Cruz, Maria L.',
        'Certificate of Indigency', 'May 1, 2025', 'approved'),
    _CertRequest('CERT-2025-085', 'Reyes, Jose B.', 'Certificate of Residency',
        'Apr 30, 2025', 'issued'),
    _CertRequest('CERT-2025-084', 'Aquino, Ana M.', 'Solo Parent Certificate',
        'Apr 30, 2025', 'pending'),
    _CertRequest('CERT-2025-083', 'Bautista, Carlos F.',
        'Good Moral Certificate', 'Apr 29, 2025', 'rejected'),
    _CertRequest('CERT-2025-082', 'Garcia, Luis N.', 'Barangay Clearance',
        'Apr 29, 2025', 'issued'),
    _CertRequest('CERT-2025-081', 'Mendoza, Elena P.', 'Business Clearance',
        'Apr 28, 2025', 'pending'),
  ];

  static const _badges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.info,
    'issued': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  void _approve(_CertRequest r) {
    setState(() => r.status = 'approved');
    AuditLog.instance.log(
      'CERT_APPROVE',
      '${r.type} (${r.no}) approved for ${r.applicant}',
      category: AuditCategory.certificate,
    );
    showAppToast(context, '${r.no} approved!');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'Certificate Processing',
          desc: 'Manage, approve, and issue barangay certificates',
        ),
        const KpiGrid(cards: [
          KpiCard(label: 'Pending Review', value: '7', accent: KpiAccent.warning),
          KpiCard(
              label: 'Issued This Month',
              value: '87',
              trend: '↑ +12%',
              trendUp: true,
              accent: KpiAccent.success),
          KpiCard(label: 'Total This Year', value: '412'),
          KpiCard(
              label: 'Rejected',
              value: '6',
              trend: 'Incomplete docs',
              accent: KpiAccent.danger),
        ]),
        MisCard(
          title: 'Certificate Requests',
          action: '⊕ New Request',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CertificateRequestScreen())),
          child: Column(
            children: [
              for (final r in _requests)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                            child: Text(r.no,
                                style: text.labelSmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4)),
                          ),
                          StatusBadge(
                            r.status[0].toUpperCase() + r.status.substring(1),
                            kind: _badges[r.status] ?? BadgeKind.gray,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r.applicant,
                          style: text.titleSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700)),
                      Text('${r.type} · Filed ${r.date}',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.inkMuted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                showAppToast(context, 'Viewing ${r.no}'),
                            child: const Text('View'),
                          ),
                          if (r.status == 'pending')
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md, vertical: 8),
                              ),
                              onPressed: () => _approve(r),
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
  }
}
