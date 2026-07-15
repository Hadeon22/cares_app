import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'mis_widgets.dart';

/// User Management module (js/pages/users.js) — role access matrix.
class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  // (module, admin, officer, resident) — "✓", "✗", or literal text.
  static const _matrix = [
    ('Dashboard (Full)', true, true, false, ''),
    ('Residency — View All', true, true, false, 'Limited'),
    ('Certificate — Approve/Issue', true, true, false, ''),
    ('Certificate — Request', true, true, true, ''),
    ('Blotter — File Report', true, true, true, ''),
    ('Blotter — Investigate', true, true, false, ''),
    ('Feedback — Submit', true, true, true, ''),
    ('Feedback — Manage', true, true, false, ''),
    ('GIS Map — View', true, true, true, ''),
    ('Account Claiming', true, true, true, ''),
    ('User Management', true, false, false, ''),
    ('Audit Logs', true, false, false, ''),
    ('Archive', true, false, false, ''),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'User Management',
          desc: 'Manage roles and system access',
        ),
        const KpiGrid(cards: [
          KpiCard(label: 'Total Users', value: '487'),
          KpiCard(
              label: 'Active Accounts',
              value: '472',
              accent: KpiAccent.success),
          KpiCard(
              label: 'Pending Approval',
              value: '12',
              accent: KpiAccent.warning),
          KpiCard(label: 'Suspended', value: '3', accent: KpiAccent.danger),
        ]),
        MisCard(
          title: 'Role Access Matrix',
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                children: [
                  _headCell(context, 'Module', left: true),
                  _headCell(context, 'Admin'),
                  _headCell(context, 'Officer'),
                  _headCell(context, 'Resident'),
                ],
              ),
              for (final (module, admin, officer, resident, residentText)
                  in _matrix)
                TableRow(
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(module,
                          style: text.labelSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600)),
                    ),
                    _permCell(admin),
                    _permCell(officer),
                    residentText.isNotEmpty
                        ? Center(
                            child: Text(residentText,
                                style: text.labelSmall
                                    ?.copyWith(color: AppColors.inkMuted)))
                        : _permCell(resident),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headCell(BuildContext context, String label, {bool left = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        textAlign: left ? TextAlign.left : TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }

  Widget _permCell(bool allowed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Icon(
        allowed ? Icons.check : Icons.close,
        size: 16,
        color: allowed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
  }
}
