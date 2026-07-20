import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/paginator.dart';
import 'mis_widgets.dart';

/// User Management module (js/pages/users.js) — the live account list with a
/// working change-role action, plus the Role Access Matrix. The matrix shows
/// a column per role (Admin locked, everyone else editable) and you tap a
/// ✓/✗ to switch that role's access; Admins can also add custom role columns.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  // Module keys match the MIS shell so a toggle actually gates the module.
  static const _modules = <(String, String)>[
    ('dashboard', 'Dashboard'),
    ('residency', 'Barangay Residency'),
    ('certificates', 'Certificate Processing'),
    ('incidents', 'Blotter / Incidents'),
    ('feedback', 'Feedback'),
    ('gis', 'GIS Mapping'),
    ('accounts', 'Account Claiming'),
    ('analytics', 'Analytics'),
    ('content', 'Site Content'),
    ('users', 'User Management'),
    ('audit', 'Audit Logs'),
    ('archive', 'Archive'),
  ];

  // Built-in module-access defaults per built-in role (custom roles start off),
  // mirroring the web matrix.
  static const _defaultModuleAccess = <String, Map<String, bool>>{
    'officer': {
      'dashboard': true, 'residency': true, 'certificates': true,
      'incidents': true, 'feedback': true, 'gis': true, 'accounts': true,
      'analytics': true, 'content': true, 'users': false, 'audit': false,
      'archive': false,
    },
    'resident': {
      'dashboard': false, 'residency': true, 'certificates': true,
      'incidents': true, 'feedback': true, 'gis': true, 'accounts': true,
      'analytics': false, 'content': false, 'users': false, 'audit': false,
      'archive': false,
    },
  };

  String _roleKey(String role) => role.toLowerCase();

  bool _moduleDefault(String roleKey, String moduleKey) =>
      _defaultModuleAccess[roleKey]?[moduleKey] ?? false;

  bool get _isAdmin => AppSession.instance.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    AccountStore.instance.ensureLoaded();
    DeletePermissions.instance.ensureLoaded();
    ModuleAccess.instance.ensureLoaded();
    MatrixRoles.instance.ensureLoaded();
  }

  // ── Role change ─────────────────────────────────────────────────
  Future<void> _changeRole(AccountRow a, String newRole) async {
    if (newRole == a.role) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change role?'),
        content: Text('Change ${a.name} (${a.email}) from ${a.role} to '
            '$newRole?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Change')),
        ],
      ),
    );
    if (confirmed != true) return;
    final oldRole = a.role;
    try {
      await AccountStore.instance.changeRole(
        a,
        newRole,
        actorAccountId: AppSession.instance.accountId,
        actorName: AppSession.instance.displayName,
        actorRole: AppSession.instance.role?.label,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not change role: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'ROLE_CHANGE',
      'Role of ${a.email} changed: $oldRole → $newRole',
      level: AuditLevel.warning,
      category: AuditCategory.auth,
    );
    if (mounted) showAppToast(context, '${a.name} is now $newRole');
  }

  // ── Matrix toggles (tap a ✓/✗ to flip a role's access) ──────────
  Future<void> _toggleModule(String roleKey, String moduleKey, bool current) async {
    try {
      await ModuleAccess.instance.setRole(roleKey, moduleKey, !current);
      AuditLog.instance.log(
        'MODULE_ACCESS_UPDATE',
        '$roleKey access to "$moduleKey" → ${!current ? 'granted' : 'revoked'}',
        level: AuditLevel.warning,
        category: AuditCategory.settings,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _toggleDelete(String roleKey, String moduleKey, bool current) async {
    try {
      await DeletePermissions.instance.setRolePerm(roleKey, moduleKey, !current);
      AuditLog.instance.log(
        'DELETE_PERM_UPDATE',
        '$roleKey delete permission for "$moduleKey" → '
            '${!current ? 'granted' : 'revoked'}',
        level: AuditLevel.warning,
        category: AuditCategory.settings,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _addRole() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'e.g. Barangay Secretary', isDense: true),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await MatrixRoles.instance.add(name);
      AuditLog.instance.log(
        'ROLE_ADD',
        'Role "${name.trim()}" added to the access matrix',
        level: AuditLevel.warning,
        category: AuditCategory.settings,
      );
    } catch (e) {
      if (mounted) {
        final msg = e is ArgumentError ? e.message : e;
        showAppToast(context, '$msg', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _removeRole(String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove role?'),
        content: Text('Remove the role "$role" from the matrix?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final rk = _roleKey(role);
    try {
      await MatrixRoles.instance.remove(role);
      await ModuleAccess.instance.removeRole(rk);
      await DeletePermissions.instance.removeRole(rk);
      AuditLog.instance.log(
        'ROLE_REMOVE',
        'Role "$role" removed from the access matrix',
        level: AuditLevel.warning,
        category: AuditCategory.settings,
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not remove: $e', icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'User Management',
          desc: 'Manage roles and system access',
        ),
        _accountsCard(context),
        _matrixCard(context),
      ],
    );
  }

  // ── Accounts + change role ──────────────────────────────────────
  Widget _accountsCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = AccountStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final accounts = store.all;
        return Column(
          children: [
            KpiGrid(cards: [
              KpiCard(label: 'Total Accounts', value: '${accounts.length}'),
              KpiCard(
                  label: 'Admins',
                  value: '${accounts.where((a) => a.role == 'Admin').length}',
                  accent: KpiAccent.danger),
              KpiCard(
                  label: 'Officers',
                  value:
                      '${accounts.where((a) => a.role == 'Officer').length}',
                  accent: KpiAccent.info),
              KpiCard(
                  label: 'Residents',
                  value:
                      '${accounts.where((a) => a.role == 'Resident').length}',
                  accent: KpiAccent.success),
            ]),
            const SizedBox(height: AppSpacing.md),
            MisCard(
              title: 'Accounts',
              child: store.loading && accounts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold)),
                    )
                  : store.error != null && accounts.isEmpty
                      ? EmptyState('Could not load accounts.\n${store.error}')
                      : accounts.isEmpty
                          ? const EmptyState('No accounts found.')
                          : PaginatedColumn<AccountRow>(
                              items: accounts,
                              itemLabel: 'account',
                              itemBuilder: (context, a) =>
                                  _accountTile(context, text, a),
                            ),
            ),
          ],
        );
      },
    );
  }

  Widget _accountTile(BuildContext context, TextTheme text, AccountRow a) {
    final session = AppSession.instance;
    final isSelf = session.accountId != null && session.accountId == a.accountId;
    final canChange = _isAdmin && !isSelf;
    // Resident can only be assigned to accounts already linked to a resident.
    final roleOptions = [
      'Admin',
      'Officer',
      if (a.residentId != null || a.role == 'Resident') 'Resident',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w700)),
                Text(a.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: AppColors.inkMuted)),
                if (a.residentId != null)
                  Text(
                    'Resident #${a.residentId}'
                    '${a.purok != null ? ' · ${a.purok}' : ''}',
                    style:
                        text.labelSmall?.copyWith(color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (canChange)
            DropdownButton<String>(
              value: roleOptions.contains(a.role) ? a.role : null,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: [
                for (final r in roleOptions)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) {
                if (v != null) _changeRole(a, v);
              },
            )
          else
            StatusBadge(a.role, kind: _roleBadge(a.role)),
        ],
      ),
    );
  }

  BadgeKind _roleBadge(String role) {
    switch (role) {
      case 'Admin':
        return BadgeKind.danger;
      case 'Officer':
        return BadgeKind.gold;
      case 'Resident':
        return BadgeKind.success;
      default:
        return BadgeKind.gray;
    }
  }

  // ── Role Access Matrix (dynamic roles, tap ✓/✗ to switch) ───────
  static const double _labelW = 168;
  static const double _colW = 78;

  Widget _matrixCard(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        DeletePermissions.instance,
        ModuleAccess.instance,
        MatrixRoles.instance,
      ]),
      builder: (context, _) {
        final roles = MatrixRoles.instance.roles;
        return MisCard(
          title: 'Role Access Matrix',
          action: _isAdmin ? '＋ Add Role' : null,
          onAction: _isAdmin ? _addRole : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAdmin
                    ? 'Admins always have full access. Tap a ✓ or ✗ to switch a '
                        "role's access to a module or delete action. Use “Add "
                        'Role” to create a new role column.'
                    : "Set by an Administrator. Each role's access is shown "
                        'below.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _matrixHeaderRow(context, roles),
                    for (final (key, label) in _modules)
                      _matrixRow(context, roles, label, (role) {
                        final rk = _roleKey(role);
                        final on = ModuleAccess.instance
                            .can(rk, key, fallback: _moduleDefault(rk, key));
                        return (on,
                            _isAdmin ? () => _toggleModule(rk, key, on) : null);
                      }),
                    // Delete is a single blanket permission per role (one row).
                    _matrixRow(context, roles, 'Delete Records', (role) {
                      final rk = _roleKey(role);
                      final on = DeletePermissions.instance
                          .roleCan(rk, DeletePermissions.recordsKey);
                      return (on,
                          _isAdmin
                              ? () => _toggleDelete(
                                  rk, DeletePermissions.recordsKey, on)
                              : null);
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _matrixHeaderRow(BuildContext context, List<String> roles) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.inkMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: _labelW, child: Text('MODULE / ACTION', style: style)),
          SizedBox(width: _colW, child: Center(child: Text('ADMIN', style: style))),
          for (final role in roles)
            SizedBox(
              width: _colW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(role.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style),
                  if (_isAdmin && !MatrixRoles.instance.isBuiltin(role))
                    InkWell(
                      onTap: () => _removeRole(role),
                      child: const Icon(Icons.close,
                          size: 13, color: AppColors.flagRed),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One matrix row. [cellFor] returns (isOn, onTap?) for a given role column.
  Widget _matrixRow(
    BuildContext context,
    List<String> roles,
    String label,
    (bool, VoidCallback?) Function(String role) cellFor,
  ) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _labelW,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(label,
                  style: text.labelSmall?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w600)),
            ),
          ),
          // Admin: always granted, locked.
          _tapCell(true, null),
          for (final role in roles)
            Builder(builder: (_) {
              final (on, onTap) = cellFor(role);
              return _tapCell(on, onTap);
            }),
        ],
      ),
    );
  }

  Widget _tapCell(bool on, VoidCallback? onTap) {
    final cell = SizedBox(
      width: _colW,
      height: 36,
      child: Center(child: _CheckIcon(on)),
    );
    return onTap == null
        ? cell
        : InkWell(onTap: onTap, child: cell);
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon(this.allowed);
  final bool allowed;
  @override
  Widget build(BuildContext context) => Icon(
        allowed ? Icons.check : Icons.close,
        size: 16,
        color: allowed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      );
}
