import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Account Claiming module (js/pages/accounts.js) — pending resident
/// account claims with approve action.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _Claim {
  _Claim(this.ref, this.name, this.email, this.purok, this.date, this.status);
  final String ref;
  final String name;
  final String email;
  final String purok;
  final String date;
  String status;
}

class _AccountsPageState extends State<AccountsPage> {
  final List<_Claim> _claims = [
    _Claim('ACC-2025-0048', 'Santos, Pedro J.', 'pedro.santos@gmail.com',
        'Purok 1', 'May 2, 2025', 'Pending'),
    _Claim('ACC-2025-0047', 'Bautista, Liza M.', 'liza.b@yahoo.com', 'Purok 3',
        'May 1, 2025', 'Pending'),
    _Claim('ACC-2025-0046', 'Ramos, Antonio S.', 'antonio.ramos@gmail.com',
        'Purok 2', 'Apr 30, 2025', 'Pending'),
    _Claim('ACC-2025-0045', 'dela Cruz, Juana', 'juana.dc@gmail.com', 'Purok 4',
        'Apr 30, 2025', 'Under Review'),
    _Claim('ACC-2025-0044', 'Cruz, Mark L.', 'mark.cruz@outlook.com', 'Purok 5',
        'Apr 29, 2025', 'Approved'),
  ];

  static const _badges = {
    'Pending': BadgeKind.warning,
    'Under Review': BadgeKind.info,
    'Approved': BadgeKind.success,
  };

  void _approve(_Claim c) {
    setState(() => c.status = 'Approved');
    AuditLog.instance.log(
      'ACC_CLAIM_APPROVE',
      'Account claim ${c.ref} approved for ${c.name}',
      category: AuditCategory.auth,
    );
    showAppToast(context, '${c.ref} approved!');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'Account Claiming',
          desc: 'Review and approve resident account claim requests',
        ),
        const KpiGrid(cards: [
          KpiCard(
              label: 'Pending Review', value: '12', accent: KpiAccent.warning),
          KpiCard(
              label: 'Approved (30 days)',
              value: '34',
              accent: KpiAccent.success),
          KpiCard(label: 'Rejected', value: '3', accent: KpiAccent.danger),
          KpiCard(label: 'Total Accounts', value: '487'),
        ]),
        MisCard(
          title: 'Pending Account Claims',
          child: Column(
            children: [
              for (final c in _claims)
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
                            child: Text(c.ref,
                                style: text.labelSmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4)),
                          ),
                          StatusBadge(c.status,
                              kind: _badges[c.status] ?? BadgeKind.gray),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c.name,
                          style: text.titleSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700)),
                      Text('${c.email} · ${c.purok} · ${c.date}',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.inkMuted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                showAppToast(context, 'Viewing ${c.ref}'),
                            child: const Text('View'),
                          ),
                          if (c.status != 'Approved')
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md, vertical: 8),
                              ),
                              onPressed: () => _approve(c),
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
