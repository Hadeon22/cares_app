import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/api_client.dart';
import '../data/session.dart';
import '../data/stores.dart';
import '../widgets/common.dart';
import '../widgets/offline_banner.dart';
import 'gis_map_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';

/// App shell: branded AppBar + NavigationBar with four destinations —
/// plus an MIS destination for signed-in Admin/Officer staff.
/// Tab content cross-fades via [AnimatedSwitcher].
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  /// Which tab to open on (the MIS navbar deep-links into specific tabs).
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  void _goTo(int index) {
    // The 5th destination (staff only) returns to the MIS shell, which
    // is the root route for Admin/Officer sessions.
    if (index == 4) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  Timer? _notifTimer;

  // Rebuild when the session changes (sign in / sign out) so the
  // AppBar actions and Home welcome reflect the current user.
  void _onSessionChanged() {
    setState(() {});
    _syncNotifications();
  }

  void _syncNotifications() {
    if (AppSession.instance.isSignedIn) {
      NotificationStore.instance.refresh();
      // Poll so request updates & messages land without a manual refresh.
      _notifTimer ??= Timer.periodic(const Duration(seconds: 60), (_) {
        if (AppSession.instance.isSignedIn &&
            !ApiClient.instance.offline.value) {
          NotificationStore.instance.refresh();
        }
      });
    } else {
      _notifTimer?.cancel();
      _notifTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    AppSession.instance.addListener(_onSessionChanged);
    _syncNotifications();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    AppSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    final screens = <Widget>[
      HomeScreen(
        onExploreServices: () => _goTo(1),
        onViewGisMap: () => _goTo(2),
      ),
      const ServicesScreen(),
      const GisMapScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        // The MIS tab in the bottom bar returns staff to the MIS, so the
        // implicit back arrow is redundant (and crowded the header).
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.md,
        // Tapping the Conde Labac seal / brand returns to the front page,
        // same as the web navbar's brand link.
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: () => _goTo(0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SealBadge(size: 34),
              const SizedBox(width: AppSpacing.sm + 4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.appAcronym,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.onNavy,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                    ),
                    Text(
                      'Barangay Conde Labac',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.gold,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (session.isSignedIn) ...[
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
            // Same account menu as the MIS topbar avatar, so the avatar
            // behaves identically everywhere in the app.
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 44),
                onSelected: (value) {
                  if (value == 'profile') {
                    _goTo(3);
                  } else if (value == 'signout') {
                    AppSession.instance.signOut();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(session.role?.title ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
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
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    session.initials,
                    style: const TextStyle(
                      color: AppColors.navyDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  textStyle: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Sign In'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.medium,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.015),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: screens[_index],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Services',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'GIS Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          if (session.role?.isStaff ?? false)
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'MIS',
            ),
        ],
      ),
    );
  }
}
