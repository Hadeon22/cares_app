import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_text.dart';
import '../../core/utils/fade_slide.dart';
import '../../data/session.dart';
import '../../data/theme_controller.dart';
import '../../widgets/app_toast.dart';
import 'change_password_screen.dart';

/// Settings — app-level preferences that belong to the device/account
/// rather than to a barangay record. Appearance is live; the rest are the
/// switches residents expect to find here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.text.settings)),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [ThemeController.instance, LocaleController.instance]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            FadeSlide(
              child: _Group(
                title: L.text.appearance,
                caption: L.text.appearanceCaption,
                children: [
                  for (final mode in ThemeMode.values)
                    _ThemeOption(
                      mode: mode,
                      selected: ThemeController.instance.mode == mode,
                      onTap: () => ThemeController.instance.setMode(mode),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlide(
              delay: const Duration(milliseconds: 60),
              child: _Group(
                title: L.text.languageSection,
                caption: L.text.languageCaption,
                children: [
                  for (final lang in AppLanguage.values)
                    _LanguageOption(
                      language: lang,
                      selected: LocaleController.instance.language == lang,
                      onTap: () async {
                        await LocaleController.instance.setLanguage(lang);
                        if (context.mounted) {
                          showAppToast(context, L.text.languageChanged,
                              icon: Icons.translate);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlide(
              delay: const Duration(milliseconds: 120),
              child: _Group(
                title: L.text.security,
                children: [
                  _NavRow(
                    icon: Icons.lock_reset,
                    title: L.text.changePassword,
                    subtitle: L.text.changePasswordSub,
                    enabled: AppSession.instance.isSignedIn,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlide(
              delay: const Duration(milliseconds: 180),
              child: _Group(
                title: L.text.notificationsGroup,
                children: [
                  _SwitchRow(
                    icon: Icons.campaign_outlined,
                    title: L.text.notifAdvisories,
                    subtitle: L.text.notifAdvisoriesSub,
                    value: _advisories,
                    onChanged: (v) => setState(() => _advisories = v),
                  ),
                  _SwitchRow(
                    icon: Icons.description_outlined,
                    title: L.text.notifRequests,
                    subtitle: L.text.notifRequestsSub,
                    value: _requestUpdates,
                    onChanged: (v) => setState(() => _requestUpdates = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlide(
              delay: const Duration(milliseconds: 240),
              child: _Group(
                title: L.text.about,
                children: [
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    title: L.text.version,
                    value: '1.0.0',
                  ),
                  _InfoRow(
                    icon: Icons.dns_outlined,
                    title: L.text.signedInAs,
                    value: AppSession.instance.isSignedIn
                        ? AppSession.instance.displayName
                        : L.text.guest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Local for now — wire to /api/notifications preferences when that
  // endpoint grows a per-account settings row.
  bool _advisories = true;
  bool _requestUpdates = true;
}

/// A titled card of rows, matching the Profile screen's grouped look.
class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.children,
    this.caption,
  });

  final String title;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
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
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: Text(
              caption!,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }
}

/// One appearance choice, with a live preview swatch of what it looks like.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = L.text;
    final (label, subtitle, icon) = switch (mode) {
      ThemeMode.system => (
          t.themeSystem,
          t.themeSystemSub,
          Icons.brightness_auto_outlined,
        ),
      ThemeMode.light => (
          t.themeLight,
          t.themeLightSub,
          Icons.light_mode_outlined,
        ),
      ThemeMode.dark => (
          t.themeDark,
          t.themeDarkSub,
          Icons.dark_mode_outlined,
        ),
    };

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (selected ? AppColors.gold : AppColors.inkMuted)
              .withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? AppColors.goldDeep : AppColors.inkMuted,
        ),
      ),
      title: Text(
        label,
        style: text.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.gold, size: 22)
          : Icon(Icons.circle_outlined, color: AppColors.divider, size: 22),
    );
  }
}

/// One language choice. Each option is labelled in its own language, so it
/// is recognisable even to someone who can't read the currently active one.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, subtitle) = switch (language) {
      AppLanguage.english => ('English', 'Default · barangay forms language'),
      AppLanguage.filipino => ('Filipino', 'Wikang ginagamit sa barangay'),
    };

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (selected ? AppColors.gold : AppColors.inkMuted)
              .withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(
          Icons.translate,
          size: 20,
          color: selected ? AppColors.goldDeep : AppColors.inkMuted,
        ),
      ),
      title: Text(
        label,
        style: text.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.gold, size: 22)
          : Icon(Icons.circle_outlined, color: AppColors.divider, size: 22),
    );
  }
}

/// A row that pushes another screen.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = AppColors.isDark ? AppColors.gold : AppColors.navy;
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, size: 20, color: accent),
      ),
      title: Text(
        title,
        style: text.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        // Signed-out residents have no password to rotate yet.
        enabled ? subtitle : L.text.signIn,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.inkMuted, size: 20),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SwitchListTile(
      value: value,
      onChanged: (v) {
        onChanged(v);
        showAppToast(
          context,
          v ? L.text.turnedOn(title) : L.text.turnedOff(title),
          icon: v
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
        );
      },
      activeThumbColor: AppColors.gold,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon,
            size: 20,
            color: AppColors.isDark ? AppColors.gold : AppColors.navy),
      ),
      title: Text(
        title,
        style: text.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon,
            size: 20,
            color: AppColors.isDark ? AppColors.gold : AppColors.navy),
      ),
      title: Text(
        title,
        style: text.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Text(
        value,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}
