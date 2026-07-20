import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';
import '../core/utils/fade_slide.dart';
import '../data/session.dart';
import '../widgets/app_toast.dart';
import '../widgets/photo_picker.dart';
import '../widgets/pull_to_refresh.dart';
import 'login_screen.dart';
import 'profile/activity_history_screen.dart';
import 'profile/my_info_screen.dart';
import 'profile/my_requests_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/settings_screen.dart';

/// Profile tab: identity card + account actions, driven by the active
/// session (web: nav user pill + dropdown).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the session so signing out swaps to the signed-out view
    // immediately (not on the next tab switch).
    return ListenableBuilder(
      listenable: AppSession.instance,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final session = AppSession.instance;

    if (!session.isSignedIn) {
      return _SignedOutView(text: text);
    }

    void push(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));

    return PullToRefresh(
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        FadeSlide(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navy, AppColors.navyDeep],
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.navyBorder),
            ),
            child: Row(
              children: [
                const SessionAvatar(radius: 30),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName,
                          style: text.titleLarge
                              ?.copyWith(color: AppColors.onNavy)),
                      const SizedBox(height: 2),
                      Text(
                        session.role == UserRole.resident
                            ? 'Verified Resident · Purok 1'
                            : session.role!.title,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.onNavyMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified, color: AppColors.gold),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeSlide(
          delay: const Duration(milliseconds: 120),
          child: _ActionGroup(
            children: [
              _ProfileTile(
                icon: Icons.badge_outlined,
                title: L.text.myInformation,
                subtitle: L.text.myInformationSub,
                onTap: () => push(const MyInfoScreen()),
              ),
              _ProfileTile(
                icon: Icons.receipt_long_outlined,
                title: L.text.myRequests,
                subtitle: L.text.myRequestsSub,
                onTap: () => push(const MyRequestsScreen()),
              ),
              _ProfileTile(
                icon: Icons.history,
                title: L.text.activityHistory,
                subtitle: L.text.activityHistorySub,
                onTap: () => push(const ActivityHistoryScreen()),
              ),
              _ProfileTile(
                icon: Icons.notifications_outlined,
                title: L.text.notifications,
                subtitle: L.text.notificationsSub,
                onTap: () => push(const NotificationsScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlide(
          delay: const Duration(milliseconds: 220),
          child: _ActionGroup(
            children: [
              _ProfileTile(
                icon: Icons.settings_outlined,
                title: L.text.settings,
                subtitle: L.text.settingsSub,
                onTap: () => push(const SettingsScreen()),
              ),
              _ProfileTile(
                  icon: Icons.help_outline,
                  title: L.text.helpSupport,
                  subtitle: AppStrings.hotline),
              _ProfileTile(
                icon: Icons.logout,
                title: L.text.signOut,
                subtitle: '',
                destructive: true,
                onTap: () {
                  AppSession.instance.signOut();
                  showAppToast(context, 'Signed out. See you again!',
                      icon: Icons.waving_hand_outlined);
                },
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// Shown when nobody is signed in — mirrors the web landing's Sign In CTA.
class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.text});
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeSlide(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    size: 44, color: AppColors.gold),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Sign in to C.A.R.E.S.',
                  style: text.headlineSmall?.copyWith(color: AppColors.ink)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to access personalized services, track your '
                'requests, and stay connected with your barangay.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(indent: 60),
          ],
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Navy has no contrast left on a dark surface — gold carries the brand
    // there instead.
    final color = destructive
        ? AppColors.flagRed
        : (AppColors.isDark ? AppColors.gold : AppColors.navy);
    return ListTile(
      onTap: onTap ?? () {},
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: destructive ? AppColors.flagRed : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkMuted)),
      trailing:
          Icon(Icons.chevron_right, color: AppColors.inkMuted, size: 20),
    );
  }
}
