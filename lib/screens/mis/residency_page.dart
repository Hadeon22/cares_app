import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/paginator.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/resident_detail.dart';
import 'mis_widgets.dart';
import 'resident_form_screen.dart';

/// Barangay Residency module (js/pages/residency.js) — KPIs + the
/// resident directory with name/purok filtering.
class ResidencyPage extends StatefulWidget {
  const ResidencyPage({super.key});

  @override
  State<ResidencyPage> createState() => _ResidencyPageState();
}

class _ResidencyPageState extends State<ResidencyPage> {
  String _query = '';
  String? _purok;

  /// Which sub-page shows: the resident directory or the resident-filed
  /// profile edit requests awaiting review.
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
    ResidentStore.instance.ensureLoaded();
    EditRequestStore.instance.ensureLoaded();
    DeletePermissions.instance.ensureLoaded();
  }

  /// Archive a resident (soft delete), gated by the Delete Permissions matrix.
  Future<void> _deleteResident(ResidentRecord r) async {
    final ok = await confirmDelete(
      context,
      title: 'Delete resident?',
      message: '${r.name} will be archived and removed from the directory. '
          'Records they are linked to are kept.',
      confirmLabel: 'Archive',
    );
    if (!ok || !mounted) return;
    try {
      await ResidentStore.instance
          .delete(r, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'RESIDENT_DELETE',
      'Resident ${r.name} (#${r.id}) archived',
      level: AuditLevel.warning,
      category: AuditCategory.system,
    );
    if (mounted) {
      showAppToast(context, '${r.name.split(',').first} archived',
          icon: Icons.delete_outline);
    }
  }

  /// Opens the Add/Edit Resident form (null id = add); refreshes the
  /// directory when the form saved something.
  Future<void> _openForm({int? residentId}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => ResidentFormScreen(residentId: residentId)),
    );
    if (saved == true) ResidentStore.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ResidentStore.instance,
        EditRequestStore.instance,
        DeletePermissions.instance,
      ]),
      builder: (context, _) => _buildBody(context),
    );
  }

  /// The Directory / Edit Requests switch under the page header.
  Widget _viewSwitch() {
    final pending = EditRequestStore.instance.pendingCount;
    return SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: AppColors.navy,
        selectedForegroundColor: AppColors.onNavy,
        foregroundColor: AppColors.navy,
        side: BorderSide(color: AppColors.divider),
      ),
      segments: [
        const ButtonSegment(
          value: false,
          icon: Icon(Icons.holiday_village_outlined, size: 16),
          label: Text('Resident Directory'),
        ),
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.rule_outlined, size: 16),
          label: Text(
              'Edit Requests${pending > 0 ? ' ($pending)' : ''}'),
        ),
      ],
      selected: {_showRequests},
      onSelectionChanged: (s) => setState(() => _showRequests = s.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildBody(BuildContext context) {
    final store = ResidentStore.instance;
    final rows = store.all.where((r) {
      if (_query.isNotEmpty &&
          !r.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_purok != null && r.purok != _purok) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'Barangay Residency',
          desc: 'Full resident database — search, view, and manage resident '
              'profiles',
        ),
        KpiGrid(cards: [
          KpiCard(
              label: 'Total Residents',
              value: '${store.all.length}',
              trend: store.loading ? 'Loading…' : 'Live from database'),
          KpiCard(
              label: 'Accounts Claimed',
              value: '${store.claimedCount}',
              accent: KpiAccent.success),
          KpiCard(
              label: 'Senior Citizens',
              value: '${store.countWithCategory('Senior Citizen')}',
              accent: KpiAccent.info),
          KpiCard(
              label: 'PWD Residents',
              value: '${store.countWithCategory('PWD')}',
              accent: KpiAccent.warning),
        ]),
        const SizedBox(height: AppSpacing.md),
        Center(child: _viewSwitch()),
        if (_showRequests) _requestsCard(context) else
        MisCard(
          title: 'Resident Directory',
          action: '+ Add Resident',
          onAction: () => _openForm(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                initialValue: _purok,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All Puroks')),
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(
                        value: 'Purok $i', child: Text('Purok $i')),
                ],
                onChanged: (v) => setState(() => _purok = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (store.loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
                )
              else if (store.error != null)
                EmptyState('Could not load residents.\n${store.error}')
              else if (rows.isEmpty)
                const EmptyState(
                    'No residents found matching your search criteria.')
              else
                PaginatedColumn<ResidentRecord>(
                  items: rows,
                  itemLabel: 'resident',
                  itemBuilder: (context, r) => _directoryRow(context, r),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Edit Requests (resident-filed profile changes) ───────────

  static const _statusBadges = {
    'pending': BadgeKind.warning,
    'approved': BadgeKind.success,
    'rejected': BadgeKind.danger,
  };

  /// Display value for a requested/current field value ('—' for empty,
  /// a placeholder for photos so base64 never renders as text).
  static String _fieldValue(String key, dynamic v) {
    if (v == null || '$v'.isEmpty) return '—';
    if (key == 'photo') return '(photo)';
    if (key == 'sex') return v == 'M' ? 'Male' : v == 'F' ? 'Female' : '$v';
    return '$v';
  }

  Future<void> _setRequestStatus(ResidentEditRequest r, String status,
      {String? remarks}) async {
    try {
      await EditRequestStore.instance.setStatus(r, status,
          remarks: remarks, accountId: AppSession.instance.accountId);
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      status == 'approved' ? 'EDIT_REQUEST_APPROVE' : 'EDIT_REQUEST_REJECT',
      'Profile edit request #${r.id} (${r.residentName}) → $status',
      category: AuditCategory.system,
    );
    if (mounted) {
      showAppToast(
          context,
          status == 'approved'
              ? 'Changes applied to ${r.residentName.split(',').first}\'s record.'
              : 'Request rejected.');
    }
  }

  /// Reject with a required remark, same pattern as certificate rejection —
  /// the resident sees the reason in their notification.
  Future<void> _rejectRequest(ResidentEditRequest r) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject edit request'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Reason — e.g. Please submit a valid ID at the '
                  'barangay office first.',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'A remark is required to reject.'
                : null,
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
    if (remark == null || remark.isEmpty || !mounted) return;
    await _setRequestStatus(r, 'rejected', remarks: remark);
  }

  /// Full request detail — every requested field as current → requested,
  /// with a thumbnail when the request includes a new photo.
  void _viewRequest(BuildContext context, ResidentEditRequest r) {
    final loc = MaterialLocalizations.of(context);
    final newPhoto = r.changes.containsKey('photo')
        ? photoBytesFromDataUrl(r.changes['photo'] as String?)
        : null;
    showMisDetailSheet(
      context,
      title: r.residentName,
      badge: StatusBadge(
        r.status[0].toUpperCase() + r.status.substring(1),
        kind: _statusBadges[r.status] ?? BadgeKind.gray,
      ),
      rows: [
        ('Resident', '#${r.residentId}'),
        ('Filed', loc.formatMediumDate(r.createdAt)),
        for (final e in r.changes.entries)
          (
            kEditableFieldLabels[e.key] ?? e.key,
            '${_fieldValue(e.key, r.current[e.key])} → '
                '${_fieldValue(e.key, e.value)}',
          ),
        if (r.remarks?.isNotEmpty ?? false) ('Remarks', r.remarks),
        if (r.processedByName != null) ('Processed By', r.processedByName),
        if (r.processedAt != null)
          ('Processed At', loc.formatMediumDate(r.processedAt!)),
      ],
      extra: [
        if (newPhoto != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('New photo:',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted)),
              const SizedBox(width: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Image.memory(newPhoto,
                    width: 72, height: 72, fit: BoxFit.cover),
              ),
            ],
          ),
        ],
      ],
      actions: [
        if (r.status == 'pending') ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.flagRed),
            onPressed: () {
              Navigator.of(context).pop();
              _rejectRequest(r);
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setRequestStatus(r, 'approved');
            },
            child: const Text('Approve'),
          ),
        ],
      ],
    );
  }

  Widget _requestsCard(BuildContext context) {
    final store = EditRequestStore.instance;
    final text = Theme.of(context).textTheme;
    final requests = store.all;
    return MisCard(
      title: 'Profile Edit Requests',
      child: store.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
            )
          : store.error != null
              ? EmptyState('Could not load edit requests.\n${store.error}')
              : requests.isEmpty
                  ? const EmptyState(
                      'No edit requests yet. Residents can propose changes '
                      'to their record from Profile → My Information → '
                      'Request Profile Edit.')
                  : Column(
                      children: [
                        for (final r in requests)
                          Container(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
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
                                          child: Text(r.residentName,
                                              style: text.titleSmall
                                                  ?.copyWith(
                                                      color: AppColors.ink,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                        ),
                                        StatusBadge(
                                          r.status[0].toUpperCase() +
                                              r.status.substring(1),
                                          kind: _statusBadges[r.status] ??
                                              BadgeKind.gray,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Changes: ${r.changes.keys.map((k) => kEditableFieldLabels[k] ?? k).join(', ')}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodySmall?.copyWith(
                                          color: AppColors.inkMuted),
                                    ),
                                    Text(
                                      'Filed ${MaterialLocalizations.of(context).formatMediumDate(r.createdAt)}',
                                      style: text.labelSmall?.copyWith(
                                          color: AppColors.inkMuted),
                                    ),
                                    if (r.status == 'pending') ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                minimumSize:
                                                    const Size(0, 34),
                                              ),
                                              onPressed: () =>
                                                  _setRequestStatus(
                                                      r, 'approved'),
                                              child: const Text('Approve'),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                minimumSize:
                                                    const Size(0, 34),
                                                foregroundColor:
                                                    AppColors.flagRed,
                                                side: const BorderSide(
                                                    color:
                                                        AppColors.flagRed),
                                              ),
                                              onPressed: () =>
                                                  _rejectRequest(r),
                                              child: const Text('Reject'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _directoryRow(BuildContext context, ResidentRecord r) {
    final text = Theme.of(context).textTheme;
    return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      // Tap the row to open the full resident profile.
                      onTap: r.id == null
                          ? null
                          : () {
                              showResidentDetailSheet(context, r.id!);
                              AuditLog.instance.log(
                                'RESIDENT_VIEW',
                                'Viewed resident profile: ${r.name} (#${r.id})',
                                category: AuditCategory.system,
                              );
                            },
                      child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: text.titleSmall?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${r.ageLabel} yrs',
                                      style: text.labelSmall?.copyWith(
                                          color: AppColors.inkMuted)),
                                  StatusBadge(r.purok, kind: BadgeKind.gray),
                                  if (r.category.isNotEmpty)
                                    StatusBadge(r.category,
                                        kind: BadgeKind.gold),
                                  StatusBadge(r.status,
                                      kind: r.status == 'Active'
                                          ? BadgeKind.success
                                          : BadgeKind.gray),
                                ],
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: r.id == null
                              ? null
                              : () => _openForm(residentId: r.id),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.goldDeep),
                          child: const Text('Edit'),
                        ),
                        if (r.id != null && canDeleteModule('residency'))
                          DeleteIconButton(
                            onPressed: () => _deleteResident(r),
                          ),
                      ],
                    ),
                      ),
                    ),
                  );
  }
}
