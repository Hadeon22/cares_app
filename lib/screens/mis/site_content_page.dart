import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../models/models.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/paginator.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pull_to_refresh.dart';
import 'mis_widgets.dart';

/// Site Content module — manages the public landing page's editable
/// sections. One page, two sub-pages (tabs): the "Latest announcements"
/// bulletin and the "Barangay Officials" leadership cards. Everything here
/// writes straight to the shared DB, so the Home tab (and anything else
/// reading /api/announcements + /api/officials) updates immediately.
class SiteContentPage extends StatelessWidget {
  const SiteContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.gold,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(icon: Icon(Icons.campaign_outlined, size: 20),
                    text: 'Announcements'),
                Tab(icon: Icon(Icons.groups_outlined, size: 20),
                    text: 'Officials'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AnnouncementsTab(),
                _OfficialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Announcements tab
/// ─────────────────────────────────────────────────────────────
class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();

  void _openForm(BuildContext context, [Announcement? existing]) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _AnnouncementFormScreen(existing: existing)));
  }

  Future<void> _delete(BuildContext context, Announcement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"${a.title}" will be removed from the landing page. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AnnouncementStore.instance
          .remove(a, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, 'Could not delete: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'ANNOUNCEMENT_DELETE',
      'Announcement "${a.title}" deleted',
      level: AuditLevel.warning,
      category: AuditCategory.settings,
    );
    if (context.mounted) {
      showAppToast(context, 'Announcement deleted',
          icon: Icons.delete_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AnnouncementStore.instance..ensureLoaded();
    DeletePermissions.instance.ensureLoaded();
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([store, DeletePermissions.instance]),
      builder: (context, _) {
        final all = store.all;
        final canDelete = canDeleteModule('announcements');
        // The MIS shell's pull-to-refresh doesn't reach scrollables inside
        // the TabBarView, so each tab carries its own.
        return PullToRefresh(
          onRefresh: store.refresh,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Announcements',
              desc: 'The community bulletin shown on the app and web '
                  'landing pages',
            ),
            FilledButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Announcement'),
            ),
            MisCard(
              title: 'Published Announcements',
              child: store.loading && all.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null && all.isEmpty
                      ? EmptyState('Could not load announcements.\n'
                          '${store.error}')
                      : all.isEmpty
                          ? const EmptyState(
                              'Nothing published yet. Tap "New Announcement" '
                              'to post the first bulletin.')
                          : PaginatedColumn<Announcement>(
                              items: all,
                              itemLabel: 'announcement',
                              itemBuilder: (context, a) =>
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _openForm(context, a),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.sm + 4,
                                            AppSpacing.sm,
                                            4,
                                            AppSpacing.sm),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      _TagChip(
                                                          tag: a.tag,
                                                          color: a.tagColor),
                                                      Text(
                                                        loc.formatShortDate(
                                                            a.createdAt),
                                                        style: text.labelSmall
                                                            ?.copyWith(
                                                                color: AppColors
                                                                    .inkMuted),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    a.title,
                                                    style: text.bodyMedium
                                                        ?.copyWith(
                                                      color: AppColors.ink,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (a.body.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      a.body,
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: text.bodySmall
                                                          ?.copyWith(
                                                        color:
                                                            AppColors.inkMuted,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (canDelete)
                                              IconButton(
                                                tooltip: 'Delete',
                                                onPressed: () =>
                                                    _delete(context, a),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                    color: AppColors.flagRed),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
            ),
          ],
          ),
        );
      },
    );
  }
}

/// Small colored tag pill matching the landing page's announcement chips.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.color});
  final String tag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        tag.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Add / Edit Announcement — pushed on top of the MIS shell.
class _AnnouncementFormScreen extends StatefulWidget {
  const _AnnouncementFormScreen({this.existing});

  final Announcement? existing;
  bool get isEditing => existing != null;

  @override
  State<_AnnouncementFormScreen> createState() =>
      _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<_AnnouncementFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late String _tag = widget.existing?.tag ?? 'Advisory';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      showAppToast(context, 'A title is required.', icon: Icons.error_outline);
      return;
    }

    setState(() => _busy = true);
    try {
      await AnnouncementStore.instance.save(
        id: widget.existing?.id,
        title: title,
        body: _body.text.trim(),
        tag: _tag,
        accountId: AppSession.instance.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
      return;
    }

    AuditLog.instance.log(
      widget.isEditing ? 'ANNOUNCEMENT_EDIT' : 'ANNOUNCEMENT_POST',
      'Announcement "$title" ${widget.isEditing ? 'updated' : 'published'}',
      category: AuditCategory.settings,
    );
    if (!mounted) return;
    showAppToast(
        context,
        widget.isEditing
            ? 'Announcement updated'
            : 'Announcement published');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.isEditing ? 'Edit Announcement' : 'New Announcement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const AlertBanner(
            kind: AlertKind.info,
            child: Text('Announcements appear on the app Home page and the '
                'public web landing page as soon as they are saved.'),
          ),
          AppTextField(
            label: 'Title',
            controller: _title,
            hint: 'e.g. Barangay Assembly — 3rd Quarter',
          ),
          AppDropdown<String>(
            label: 'Tag',
            value: _tag,
            items: kAnnouncementTagColors.keys.toList(),
            onChanged: (v) => setState(() => _tag = v ?? 'Advisory'),
          ),
          AppTextField(
            label: 'Details',
            controller: _body,
            maxLines: 6,
            hint: 'What residents need to know — schedule, venue, '
                'requirements…',
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.navyDeep),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(widget.isEditing ? 'Save Changes' : 'Publish'),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Officials tab
/// ─────────────────────────────────────────────────────────────
class _OfficialsTab extends StatelessWidget {
  const _OfficialsTab();

  void _openForm(BuildContext context, [Official? existing]) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _OfficialFormScreen(existing: existing)));
  }

  Future<void> _delete(BuildContext context, Official o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove official?'),
        content: Text('${o.displayName} will be removed from the landing '
            'page. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await OfficialStore.instance
          .remove(o, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, 'Could not remove: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'OFFICIAL_DELETE',
      'Official ${o.displayName} removed',
      level: AuditLevel.warning,
      category: AuditCategory.settings,
    );
    if (context.mounted) {
      showAppToast(context, 'Official removed', icon: Icons.delete_outline);
    }
  }

  Future<void> _move(BuildContext context, Official o, int delta) async {
    try {
      await OfficialStore.instance
          .move(o, delta, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, 'Could not reorder: $e',
            icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = OfficialStore.instance..ensureLoaded();
    DeletePermissions.instance.ensureLoaded();
    final text = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: Listenable.merge([store, DeletePermissions.instance]),
      builder: (context, _) {
        final all = store.all;
        final canDelete = canDeleteModule('officials');
        return PullToRefresh(
          onRefresh: store.refresh,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
              AppSpacing.gutter, AppSpacing.xxl),
          children: [
            const MisPageHeader(
              title: 'Barangay Officials',
              desc: 'The leadership cards shown on the app and web '
                  'landing pages, in display order',
            ),
            FilledButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.person_add_alt_outlined, size: 18),
              label: const Text('Add Official'),
            ),
            MisCard(
              title: 'Current Officials',
              child: store.loading && all.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null && all.isEmpty
                      ? EmptyState('Could not load officials.\n${store.error}')
                      : all.isEmpty
                          ? const EmptyState(
                              'No officials listed yet. Tap "Add Official" '
                              'to build the leadership section.')
                          : PaginatedColumn<Official>(
                              items: all,
                              itemLabel: 'official',
                              itemBuilder: (context, o) {
                                // True position in the full list, so the
                                // up/down disabling stays correct across pages.
                                final i = all.indexOf(o);
                                return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _openForm(context, all[i]),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.sm + 4,
                                            AppSpacing.sm,
                                            4,
                                            AppSpacing.sm),
                                        child: Row(
                                          children: [
                                            ResidentAvatar(
                                              initials: all[i].initials,
                                              photo: all[i].photo,
                                              radius: 20,
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.sm + 4),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    all[i].displayName,
                                                    style: text.bodyMedium
                                                        ?.copyWith(
                                                      color: AppColors.ink,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    all[i].role,
                                                    style: text.labelSmall
                                                        ?.copyWith(
                                                            color: AppColors
                                                                .goldDeep,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Move up',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: i == 0
                                                  ? null
                                                  : () => _move(
                                                      context, all[i], -1),
                                              icon: const Icon(
                                                  Icons.arrow_upward,
                                                  size: 18),
                                            ),
                                            IconButton(
                                              tooltip: 'Move down',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: i == all.length - 1
                                                  ? null
                                                  : () =>
                                                      _move(context, all[i], 1),
                                              icon: const Icon(
                                                  Icons.arrow_downward,
                                                  size: 18),
                                            ),
                                            if (canDelete)
                                              IconButton(
                                                tooltip: 'Remove',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _delete(context, all[i]),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                    color: AppColors.flagRed),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                              },
                            ),
            ),
          ],
          ),
        );
      },
    );
  }
}

/// Add / Edit Official — pushed on top of the MIS shell.
class _OfficialFormScreen extends StatefulWidget {
  const _OfficialFormScreen({this.existing});

  final Official? existing;
  bool get isEditing => existing != null;

  @override
  State<_OfficialFormScreen> createState() => _OfficialFormScreenState();
}

class _OfficialFormScreenState extends State<_OfficialFormScreen> {
  late final _honorific =
      TextEditingController(text: widget.existing?.honorific ?? 'Hon.');
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _role = TextEditingController(text: widget.existing?.role);
  late final _desc = TextEditingController(text: widget.existing?.desc);
  late String? _photo = widget.existing?.photo;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_honorific, _name, _role, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _initials {
    final parts =
        _name.text.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final role = _role.text.trim();
    if (name.isEmpty || role.isEmpty) {
      showAppToast(context, 'Name and position are required.',
          icon: Icons.error_outline);
      return;
    }

    setState(() => _busy = true);
    try {
      await OfficialStore.instance.save(
        id: widget.existing?.id,
        honorific: _honorific.text.trim(),
        name: name,
        role: role,
        desc: _desc.text.trim(),
        photo: _photo,
        accountId: AppSession.instance.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
      return;
    }

    AuditLog.instance.log(
      widget.isEditing ? 'OFFICIAL_EDIT' : 'OFFICIAL_ADD',
      'Official $name ${widget.isEditing ? 'updated' : 'added'}',
      category: AuditCategory.settings,
    );
    if (!mounted) return;
    showAppToast(context,
        widget.isEditing ? 'Official updated' : 'Official added');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Official' : 'Add Official')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          ResidentPhotoPicker(
            photo: _photo,
            initials: _initials,
            onChanged: (v) => setState(() => _photo = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Honorific',
            controller: _honorific,
            hint: 'Hon.',
            helper: 'Shown before the name, e.g. "Hon. Juan Dela Cruz". '
                'Leave blank for none.',
          ),
          AppTextField(
            label: 'Full Name',
            controller: _name,
            hint: 'e.g. Juan Dela Cruz',
            onChanged: (_) => setState(() {}),
          ),
          AppTextField(
            label: 'Position',
            controller: _role,
            hint: 'e.g. Punong Barangay, Kagawad — Public Safety',
          ),
          AppTextField(
            label: 'Short Description',
            controller: _desc,
            maxLines: 3,
            hint: 'One sentence about their responsibilities',
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.navyDeep),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(widget.isEditing ? 'Save Changes' : 'Add Official'),
          ),
        ],
      ),
    );
  }
}
