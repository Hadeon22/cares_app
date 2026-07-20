import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/paginator.dart';
import '../../widgets/pull_to_refresh.dart';
import 'mis_widgets.dart';

/// Archive module (js/pages/archive.js) — the system recycle bin. Records
/// deleted anywhere in the system (residents, certificate requests, blotter
/// reports, feedback, announcements, officials) are snapshotted server-side
/// and listed here for restore or permanent deletion. Below: backup status.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  static const _backups = [
    ('backup_2025-05-02_02-00.zip', '98.4 MB · Today, 02:00 AM', 'Verified'),
    ('backup_2025-05-01_02-00.zip', '97.1 MB · Yesterday, 02:00 AM',
        'Verified'),
    ('archive_Q1-2025_full.zip', '1.2 GB · Apr 1, 2025 · Quarterly',
        'Verified'),
  ];

  static const _moduleIcons = <String, IconData>{
    'residency': Icons.holiday_village_outlined,
    'certificates': Icons.description_outlined,
    'incidents': Icons.campaign_outlined,
    'feedback': Icons.chat_bubble_outline,
    'announcements': Icons.campaign_outlined,
    'officials': Icons.groups_outlined,
  };

  Future<void> _restore(BuildContext context, ArchiveEntry e) async {
    try {
      await ArchiveStore.instance
          .restore(e, accountId: AppSession.instance.accountId);
    } catch (err) {
      if (context.mounted) {
        showAppToast(context, 'Could not restore: $err',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'ARCHIVE_RESTORE',
      'Restored ${e.typeLabel} — ${e.title}',
      category: AuditCategory.archive,
    );
    if (context.mounted) {
      showAppToast(context, 'Record restored', icon: Icons.restore);
    }
  }

  Future<void> _purge(BuildContext context, ArchiveEntry e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('"${e.title}" will be permanently deleted and can no '
            'longer be restored. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ArchiveStore.instance
          .purge(e, accountId: AppSession.instance.accountId);
    } catch (err) {
      if (context.mounted) {
        showAppToast(context, 'Could not delete: $err',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'ARCHIVE_PURGE',
      'Permanently deleted ${e.typeLabel} — ${e.title}',
      level: AuditLevel.critical,
      category: AuditCategory.archive,
    );
    if (context.mounted) {
      showAppToast(context, 'Record permanently deleted',
          icon: Icons.delete_forever);
    }
  }

  Future<void> _restoreBuilding(BuildContext context, ArchivedBuilding b) async {
    try {
      await MapBuildingArchiveStore.instance
          .restore(b, accountId: AppSession.instance.accountId);
    } catch (err) {
      if (context.mounted) {
        showAppToast(context, 'Could not restore: $err',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'MAP_BUILDING_RESTORE',
      'Restored map building — ${b.name}',
      category: AuditCategory.map,
    );
    if (context.mounted) {
      showAppToast(context, 'Building restored', icon: Icons.restore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = ArchiveStore.instance..ensureLoaded();
    MapBuildingArchiveStore.instance.ensureLoaded();

    return PullToRefresh(
      onRefresh: () => Future.wait([
        ArchiveStore.instance.refresh(),
        MapBuildingArchiveStore.instance.refresh(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const MisPageHeader(
            title: 'Archive',
            desc: 'Recycle bin, records retention, and restore workflows',
          ),
          // ── Deleted records (the functional recycle bin) ──────────
          AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              return MisCard(
                title: 'Deleted Records',
                child: store.loading && store.all.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold)),
                      )
                    : store.error != null && store.all.isEmpty
                        ? EmptyState('Could not load the archive.\n'
                            '${store.error}')
                        : store.all.isEmpty
                            ? const EmptyState(
                                'Nothing in the recycle bin. Deleted records '
                                'across the system appear here and can be '
                                'restored.')
                            : PaginatedColumn<ArchiveEntry>(
                                items: store.all,
                                itemLabel: 'record',
                                itemBuilder: (context, e) =>
                                    _ArchiveRow(
                                      entry: e,
                                      icon: _moduleIcons[e.module] ??
                                          Icons.inventory_2_outlined,
                                      onRestore: () => _restore(context, e),
                                      onPurge: () => _purge(context, e),
                                    ),
                              ),
              );
            },
          ),
          // ── Deleted map buildings (own snapshot + restore path) ────
          AnimatedBuilder(
            animation: MapBuildingArchiveStore.instance,
            builder: (context, _) {
              final store = MapBuildingArchiveStore.instance;
              return MisCard(
                title: 'Deleted Map Buildings',
                child: store.loading && store.all.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold)),
                      )
                    : store.error != null && store.all.isEmpty
                        ? EmptyState('Could not load deleted buildings.\n'
                            '${store.error}')
                        : store.all.isEmpty
                            ? const EmptyState(
                                'No deleted map buildings to restore.')
                            : Column(
                                children: [
                                  for (final b in store.all)
                                    _BuildingRow(
                                      building: b,
                                      onRestore: () => _restoreBuilding(context, b),
                                    ),
                                ],
                              ),
              );
            },
          ),
          // ── Backup status (informational) ─────────────────────────
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
                          icon: Icon(Icons.download_outlined,
                              size: 18, color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One deleted-record row: type icon, title + context, restore & delete-forever.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.entry,
    required this.icon,
    required this.onRestore,
    required this.onPurge,
  });

  final ArchiveEntry entry;
  final IconData icon;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final meta = [
      entry.typeLabel,
      if (entry.subtitle.isNotEmpty) entry.subtitle,
      'by ${entry.archivedBy}',
      loc.formatShortDate(entry.archivedAt),
    ].join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 4, AppSpacing.sm, 4, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.navy),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? entry.typeLabel : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w700),
                ),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Restore'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.goldDeep,
                visualDensity: VisualDensity.compact),
          ),
          IconButton(
            tooltip: 'Delete permanently',
            visualDensity: VisualDensity.compact,
            onPressed: onPurge,
            icon: const Icon(Icons.delete_forever_outlined,
                size: 20, color: AppColors.flagRed),
          ),
        ],
      ),
    );
  }
}

/// One deleted-building row: name + when, with a restore action.
class _BuildingRow extends StatelessWidget {
  const _BuildingRow({required this.building, required this.onRestore});

  final ArchivedBuilding building;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 4, AppSpacing.sm, 4, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment_outlined, size: 22, color: AppColors.navy),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w700)),
                Text(
                  'Deleted ${loc.formatShortDate(building.archivedAt)}',
                  style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Restore'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.goldDeep,
                visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}
