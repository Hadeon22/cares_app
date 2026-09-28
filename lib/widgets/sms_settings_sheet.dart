import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';
import '../data/api_client.dart';
import '../data/resident_profile.dart';
import '../data/session.dart';
import '../screens/profile/edit_request_screen.dart';
import 'app_toast.dart';

/// A resident's two SMS settings — certificate updates and barangay
/// announcements. The app's twin of the web's js/sms-settings.js: asked once,
/// the first time a resident signs in ([maybePromptSmsSettings]), and
/// changeable afterwards from Profile → Settings ([showSmsSettingsSheet]).
///
/// Two switches, not one: turning off announcements must not also stop "your
/// certificate is ready". They start on because the barangay texts residents
/// as part of its public function (RA 10173 §12(e)) — this is the resident's
/// right to object, recorded with its date. Emergency announcements and
/// security codes ignore both, and the sheet says so. "Save" stamps the choice
/// (GET / PUT /api/residents/me/sms-settings); "Ask me later" leaves it unset,
/// so the prompt returns next sign-in.
Future<void> showSmsSettingsSheet(BuildContext context, {bool prompt = false}) async {
  final account = AppSession.instance.accountId;
  if (account == null) return;
  Map<String, dynamic> data;
  try {
    data = await ApiClient.instance
        .get('/api/residents/me/sms-settings', query: {'account_id': '$account'})
        as Map<String, dynamic>;
  } on ApiException catch (e) {
    if (context.mounted && !prompt) {
      showAppToast(context, e.message, icon: Icons.error_outline);
    }
    return;
  }
  if (!context.mounted) return;
  if (prompt && data['sms_pref_set_at'] != null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !prompt,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (_) => _SmsSettingsSheet(data: data, prompt: prompt),
  );
}

// Asked at most once per app run, so "Ask me later" means later.
bool _promptedThisRun = false;

/// The first sign-in prompt: residents only, until they choose.
Future<void> maybePromptSmsSettings(BuildContext context) async {
  final s = AppSession.instance;
  if (_promptedThisRun || !s.isSignedIn || s.serverRole != 'Resident') return;
  if (s.residentId == null || s.accountId == null) return;
  _promptedThisRun = true;
  await showSmsSettingsSheet(context, prompt: true);
}

class _SmsSettingsSheet extends StatefulWidget {
  const _SmsSettingsSheet({required this.data, required this.prompt});
  final Map<String, dynamic> data;
  final bool prompt;

  @override
  State<_SmsSettingsSheet> createState() => _SmsSettingsSheetState();
}

class _SmsSettingsSheetState extends State<_SmsSettingsSheet> {
  late bool _updates = widget.data['sms_updates'] != false;
  late bool _advisories = widget.data['sms_advisories'] != false;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ApiClient.instance.put('/api/residents/me/sms-settings', {
        'account_id': AppSession.instance.accountId,
        'sms_updates': _updates,
        'sms_advisories': _advisories,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(context, L.text.smsSaved, icon: Icons.sms_outlined);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(context, e.message, icon: Icons.error_outline);
    }
  }

  // A resident's number is part of the barangay record, so it is changed by
  // request — the same edit-request flow as every other field.
  Future<void> _changeNumber() async {
    final rid = AppSession.instance.residentId;
    if (rid == null) return;
    final nav = Navigator.of(context);
    try {
      final profile = await ResidentProfile.fetch(rid);
      nav.pop();
      await nav.push(MaterialPageRoute(
          builder: (_) => EditRequestScreen(profile: profile)));
    } catch (e) {
      if (mounted) showAppToast(context, '$e', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasMobile = widget.data['has_mobile'] == true;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.sms_outlined, color: AppColors.navy),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(L.text.smsTitle,
                    style: text.titleMedium?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(L.text.smsIntro,
                style: text.bodySmall
                    ?.copyWith(color: AppColors.inkMuted, height: 1.5)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasMobile
                        ? '${L.text.smsGoesTo} ${widget.data['number_masked']}'
                        : L.text.smsNoNumber,
                    style: text.bodyMedium?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.goldDeep),
                    onPressed: _busy ? null : _changeNumber,
                    child: Text(
                        hasMobile ? L.text.smsWrongNumber : L.text.smsAddNumber),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _updates,
              onChanged: _busy ? null : (v) => setState(() => _updates = v),
              title: Text(L.text.smsUpdates),
              subtitle: Text(L.text.smsUpdatesSub),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _advisories,
              onChanged: _busy ? null : (v) => setState(() => _advisories = v),
              title: Text(L.text.smsAdvisories),
              subtitle: Text(L.text.smsAdvisoriesSub),
            ),
            Text(L.text.smsAlways,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(widget.prompt
                      ? L.text.smsLater
                      : MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(L.text.smsSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
