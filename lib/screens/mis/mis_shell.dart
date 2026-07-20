import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pull_to_refresh.dart';
import '../gis_map_screen.dart';
import '../main_shell.dart';
import '../profile/notifications_screen.dart';
import 'accounts_page.dart';
import 'analytics_page.dart';
import 'archive_page.dart';
import 'audit_page.dart';
import 'certificates_page.dart';
import 'dashboard_page.dart';
import 'feedback_page.dart';
import 'incidents_page.dart';
import 'residency_page.dart';
import 'site_content_page.dart';
import 'users_page.dart';

/// One MIS module — mirrors moduleConfig + modulePermissions (js/shell.js).
class _MisModule {
  const _MisModule(this.key, this.title, this.sub, this.icon, this.roles);
  final String key;
  final String title;
  final String sub;
  final IconData icon;
  final List<UserRole> roles;
}

const _modules = <_MisModule>[
  _MisModule('dashboard', 'Dashboard', 'Overview & KPIs',
      Icons.space_dashboard_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('residency', 'Barangay Residency', 'Resident records & search',
      Icons.holiday_village_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('certificates', 'Certificate Processing', 'Request management',
      Icons.description_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('incidents', 'Blotter / Incidents', 'Emergency logging & tracking',
      Icons.campaign_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('feedback', 'Feedback', 'Resident sentiment & trends',
      Icons.chat_bubble_outline, [UserRole.admin, UserRole.officer]),
  _MisModule('gis', 'GIS Mapping', 'Interactive zone & hazard view',
      Icons.map_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule(
      'accounts',
      'Account Claiming',
      'Resident registration & verification',
      Icons.vpn_key_outlined,
      [UserRole.admin, UserRole.officer]),
  _MisModule('analytics', 'Analytics', 'Predictive insights & trend charts',
      Icons.insights_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('content', 'Site Content', 'Announcements & barangay officials',
      Icons.edit_note_outlined, [UserRole.admin, UserRole.officer]),
  _MisModule('users', 'User Management', 'Roles & access control',
      Icons.manage_accounts_outlined, [UserRole.admin]),
  _MisModule('audit', 'Audit Logs', 'System activity & compliance',
      Icons.fact_check_outlined, [UserRole.admin]),
  _MisModule('archive', 'Archive', 'Records retention & backup',
      Icons.inventory_2_outlined, [UserRole.admin]),
];

/// Staff shell — the mobile version of the MIS sidebar + topbar layout
/// used by pages/*.html. The sidebar becomes a navigation drawer.
class MisShell extends StatefulWidget {
  const MisShell({super.key});

  @override
  State<MisShell> createState() => _MisShellState();
}

/// Whether [role] may open module [m]. Officers additionally respect the
/// admin-set [ModuleAccess] overrides (a module's built-in default is used
/// until an override exists), so a toggle in User Management actually gates
/// the module. Admins/residents follow the module's static role list.
bool _moduleAllowed(_MisModule m, UserRole? role) {
  // Account Claiming review is hidden for now — gating it here keeps it out
  // of the sidebar and out of the routing switch in one place.
  if (m.key == 'accounts' && !AppFeatures.misAccountClaiming) return false;
  if (role == null || !m.roles.contains(role)) return false;
  if (role == UserRole.officer) {
    return ModuleAccess.instance.officerCan(m.key, fallback: true);
  }
  return true;
}

class _MisShellState extends State<MisShell> {
  String _module = 'dashboard';
  Timer? _notifTimer;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  _MisModule get _current => _modules.firstWhere((m) => m.key == _module);

  @override
  void initState() {
    super.initState();
    // Same polling as the portal shell: staff get request updates and
    // messages in their bell without a manual refresh.
    NotificationStore.instance.ensureLoaded();
    // Officer module-access overrides gate the drawer + navigation.
    ModuleAccess.instance.ensureLoaded();
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (AppSession.instance.isSignedIn &&
          !ApiClient.instance.offline.value) {
        NotificationStore.instance.refresh();
      }
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  void _navigate(String key) {
    final session = AppSession.instance;
    final module =
        _modules.firstWhere((m) => m.key == key, orElse: () => _modules.first);
    // Client-side RBAC, mirroring nav() in js/shell.js.
    if (!_moduleAllowed(module, session.role)) {
      showAppToast(context, 'Access denied: insufficient permissions',
          icon: Icons.flag_outlined);
      return;
    }
    setState(() => _module = key);
  }

  /// Opens the public resident portal on top of the MIS — the mobile
  /// version of the web navbar's landing-page link. The portal's MIS
  /// navbar tab (or system back) returns here.
  void _openPortal(BuildContext context, {int tab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MainShell(initialIndex: tab)),
    );
  }

  /// Adds swipe-down-to-reload to every MIS page. The GIS map manages its
  /// own pull-to-refresh (and its own scroll physics), so it's left as-is;
  /// every other page is a plain list, wrapped here so the gesture works
  /// even when the content fits the screen.
  Widget _wrapRefresh(Widget page) {
    if (_module == 'gis') return page;
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: refreshLoadedStores,
      child: ScrollConfiguration(
        behavior: const AlwaysScrollableBehavior(),
        child: page,
      ),
    );
  }

  Widget _buildPage() {
    switch (_module) {
      case 'dashboard':
        return DashboardPage(onNavigate: _navigate);
      case 'residency':
        return const ResidencyPage();
      case 'certificates':
        return const CertificatesPage();
      case 'incidents':
        return const IncidentsPage();
      case 'feedback':
        return const FeedbackPage();
      case 'gis':
        return const GisMapScreen();
      case 'accounts':
        return const AccountsPage();
      case 'analytics':
        return const AnalyticsPage();
      case 'content':
        return const SiteContentPage();
      case 'users':
        return const UsersPage();
      case 'audit':
        return const AuditPage();
      case 'archive':
        return const ArchivePage();
      default:
        return DashboardPage(onNavigate: _navigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final loc = MaterialLocalizations.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_current.title,
                style: text.titleSmall?.copyWith(
                    color: AppColors.onNavy, fontWeight: FontWeight.w800)),
            Text(
              '${_current.sub} · ${loc.formatShortDate(now)}',
              style: text.labelSmall?.copyWith(color: AppColors.onNavyMuted),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: NotificationStore.instance,
            builder: (context, _) {
              final unread = NotificationStore.instance.unreadCount;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.navyDeep,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 44),
              onSelected: (value) {
                if (value == 'signout') {
                  AppSession.instance.signOut();
                } else if (value == 'portal') {
                  _openPortal(context);
                } else if (value == 'profile') {
                  _openPortal(context, tab: 3);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName,
                          style: text.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(session.role?.title ?? '',
                          style: text.labelSmall
                              ?.copyWith(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 18, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'portal',
                  child: Row(
                    children: [
                      Icon(Icons.home_outlined,
                          size: 18, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text('C.A.R.E.S. Portal'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: AppColors.flagRed),
                      SizedBox(width: 8),
                      Text('Sign Out',
                          style: TextStyle(color: AppColors.flagRed)),
                    ],
                  ),
                ),
              ],
              child: const SessionAvatar(radius: 16),
            ),
          ),
        ],
      ),
      drawer: _MisDrawer(
        current: _module,
        onSelect: (key) {
          Navigator.of(context).pop();
          _navigate(key);
        },
        onOpenPortal: () {
          Navigator.of(context).pop();
          _openPortal(context);
        },
      ),
      // A rightward swipe anywhere on a page opens the sidebar drawer
      // (in addition to Scaffold's own left-edge drag). Most MIS pages
      // scroll vertically, so they don't claim the horizontal drag and the
      // swipe wins; horizontally-scrolling tables keep their own scroll.
      // Disabled on the GIS module — the swipe would fight map panning.
      // GisMapScreen provides its own drawer swipe for everything outside
      // the map canvas (filter row, reports feed, AI panel).
      body: GestureDetector(
        onHorizontalDragEnd: _module == 'gis'
            ? null
            : (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 250 &&
                    !(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.medium,
                child: KeyedSubtree(
                    key: ValueKey(_module), child: _wrapRefresh(_buildPage())),
              ),
            ),
          ],
        ),
      ),
      // Same bottom bar as the portal, with MIS active — tapping a
      // portal tab opens the landing pages on top of the MIS.
      bottomNavigationBar: NavigationBar(
        // MIS is the active destination (index 3); Profile stays rightmost.
        selectedIndex: 3,
        onDestinationSelected: (i) {
          if (i == 3) return; // MIS — already here
          // Profile is the last destination → portal tab 3.
          _openPortal(context, tab: i == 4 ? 3 : i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'GIS Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'MIS',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _MisDrawer extends StatelessWidget {
  const _MisDrawer({
    required this.current,
    required this.onSelect,
    required this.onOpenPortal,
  });

  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenPortal;

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    final text = Theme.of(context).textTheme;
    final visible =
        _modules.where((m) => _moduleAllowed(m, session.role)).toList();

    return Drawer(
      backgroundColor: AppColors.navyDeep,
      child: SafeArea(
        child: Column(
          children: [
            // Tapping the seal/brand opens the public front page, same as
            // the web navbar's logo link.
            InkWell(
              onTap: onOpenPortal,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const SealBadge(size: 42),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Brgy. Conde Labac',
                              style: text.titleSmall?.copyWith(
                                  color: AppColors.onNavy,
                                  fontWeight: FontWeight.w800)),
                          Text('Management Information System',
                              style: text.labelSmall
                                  ?.copyWith(color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.navyBorder),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const SessionAvatar(radius: 18),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge?.copyWith(
                                color: AppColors.onNavy,
                                fontWeight: FontWeight.w700)),
                        Text(session.role?.title ?? '',
                            style: text.labelSmall
                                ?.copyWith(color: AppColors.onNavyMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.navyBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  for (final m in visible)
                    ListTile(
                      dense: true,
                      selected: m.key == current,
                      selectedTileColor: AppColors.gold.withValues(alpha: 0.12),
                      leading: Icon(
                        m.icon,
                        size: 20,
                        color: m.key == current
                            ? AppColors.gold
                            : AppColors.onNavyMuted,
                      ),
                      title: Text(
                        m.title,
                        style: text.labelLarge?.copyWith(
                          color: m.key == current
                              ? AppColors.gold
                              : AppColors.onNavy,
                          fontWeight: m.key == current
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      onTap: () => onSelect(m.key),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.navyBorder),
            ListTile(
              dense: true,
              leading: const Icon(Icons.home_outlined,
                  size: 20, color: AppColors.gold),
              title: Text('C.A.R.E.S. Portal',
                  style: text.labelLarge?.copyWith(
                      color: AppColors.onNavy, fontWeight: FontWeight.w600)),
              subtitle: Text('Back to the public landing page',
                  style:
                      text.labelSmall?.copyWith(color: AppColors.onNavyMuted)),
              onTap: onOpenPortal,
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout,
                  size: 20, color: AppColors.onNavyMuted),
              title: Text('Sign Out',
                  style: text.labelLarge?.copyWith(
                      color: AppColors.onNavy, fontWeight: FontWeight.w600)),
              onTap: () => AppSession.instance.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
