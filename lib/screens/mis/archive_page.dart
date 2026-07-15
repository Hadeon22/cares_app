import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Archive module (js/pages/archive.js) — records retention, backup
/// status, and restore workflows.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  static const _backups = [
    ('backup_2025-05-02_02-00.zip', '98.4 MB · Today, 02:00 AM', 'Verified'),
    ('backup_2025-05-01_02-00.zip', '97.1 MB · Yesterday, 02:00 AM',
        'Verified'),
    ('backup_2025-04-30_02-00.zip', '96.8 MB · Apr 30, 02:00 AM', 'Verified'),
    ('archive_Q1-2025_full.zip', '1.2 GB · Apr 1, 2025 · Quarterly',
        'Verified'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'Archive',
          desc: 'Records retention, backup status, and restore workflows',
        ),
        const KpiGrid(cards: [
          KpiCard(
              label: 'Last Backup',
              value: '2h ago',
              trend: 'Auto-backup: Daily 2:00 AM',
              accent: KpiAccent.success),
          KpiCard(label: 'Total Archived Size', value: '14.8 GB'),
          KpiCard(label: 'Records Archived', value: '12,408'),
          KpiCard(
              label: 'Storage Used',
              value: '78%',
              trend: '19.0 GB of 25 GB',
              accent: KpiAccent.warning),
        ]),
        const SizedBox(height: AppSpacing.md),
        const AlertBanner(
          kind: AlertKind.warning,
          child: Text('Storage is at 78%. Consider upgrading storage or '
              'purging records older than 5 years.'),
        ),
        MisCard(
          title: 'Backup Archives',
          action: '⛁ Manual Backup',
          onAction: () {
            AuditLog.instance.log(
              'ARCHIVE_BACKUP',
              'Manual backup started from Archive module',
              category: AuditCategory.archive,
            );
            showAppToast(context, 'Backup started...',
                icon: Icons.storage_outlined);
          },
          child: Column(
            children: [
              for (final (name, info, status) in _backups)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storage_outlined,
                          size: 22, color: AppColors.navy),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelMedium?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('$info · $status',
                                style: text.labelSmall
                                    ?.copyWith(color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AuditLog.instance.log(
                            'ARCHIVE_RESTORE',
                            'Restore initiated from backup $name',
                            level: AuditLevel.warning,
                            category: AuditCategory.archive,
                          );
                          showAppToast(context, 'Restore initiated',
                              icon: Icons.refresh);
                        },
                        child: const Text('Restore'),
                      ),
                      IconButton(
                        onPressed: () {
                          AuditLog.instance.log(
                            'ARCHIVE_DOWNLOAD',
                            'Backup $name downloaded',
                            category: AuditCategory.archive,
                          );
                          showAppToast(context, 'Downloading...',
                              icon: Icons.download_outlined);
                        },
                        icon: const Icon(Icons.download_outlined,
                            size: 18, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const MisCard(
          title: 'Deleted Map Buildings',
          child: EmptyState('No deleted map buildings to restore.'),
        ),
      ],
    );
  }
}
