import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_text.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';

/// Settings → Change Password.
///
/// The current password is re-entered here and re-verified server-side by
/// POST /api/auth/change-password — being signed in is deliberately not
/// enough to rotate the credential.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _showCurrent = false;
  bool _showNext = false;

  @override
  void initState() {
    super.initState();
    // Live strength/match feedback as they type.
    for (final c in [_next, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 0–3. Length is the floor; variety lifts it from there.
  int get _strength {
    final p = _next.text;
    if (p.length < 8) return 0;
    var score = 1;
    if (p.length >= 12) score++;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
    final hasDigit = RegExp(r'\d').hasMatch(p);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(p);
    if (hasLetter && hasDigit && hasSymbol) score++;
    return score.clamp(0, 3);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final t = L.text;

    if (_current.text.isEmpty) {
      showAppToast(context, t.pwEnterCurrent, icon: Icons.error_outline);
      return;
    }
    if (_next.text.length < 8) {
      showAppToast(context, t.pwTooShort, icon: Icons.error_outline);
      return;
    }
    if (_next.text != _confirm.text) {
      showAppToast(context, t.pwNoMatch, icon: Icons.error_outline);
      return;
    }
    if (_next.text == _current.text) {
      showAppToast(context, t.pwSameAsOld, icon: Icons.error_outline);
      return;
    }

    setState(() => _busy = true);
    try {
      await ApiClient.instance.post('/api/auth/change-password', {
        'account_id': AppSession.instance.accountId,
        'current_password': _current.text,
        'new_password': _next.text,
      });
      AuditLog.instance.log(
        'PASSWORD_CHANGE',
        'Password changed from the mobile app',
        category: AuditCategory.auth,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(context, t.pwChanged, icon: Icons.check_circle_outline);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.text;
    final text = Theme.of(context).textTheme;
    final matches = _confirm.text.isNotEmpty && _next.text == _confirm.text;

    return Scaffold(
      appBar: AppBar(title: Text(t.changePassword)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          AlertBanner(
            kind: AlertKind.info,
            child: Text(t.pwIntro),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppTextField(
            label: t.pwCurrent,
            controller: _current,
            obscureText: !_showCurrent,
            hint: t.pwCurrentHint,
            suffix: IconButton(
              icon: Icon(
                _showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.inkMuted,
              ),
              onPressed: () => setState(() => _showCurrent = !_showCurrent),
            ),
          ),

          const Divider(height: AppSpacing.xl),

          AppTextField(
            label: t.pwNew,
            controller: _next,
            obscureText: !_showNext,
            hint: t.pwNewHint,
            suffix: IconButton(
              icon: Icon(
                _showNext ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.inkMuted,
              ),
              onPressed: () => setState(() => _showNext = !_showNext),
            ),
          ),
          if (_next.text.isNotEmpty) ...[
            _StrengthBar(strength: _strength),
            const SizedBox(height: AppSpacing.sm),
          ],

          AppTextField(
            label: t.pwConfirm,
            controller: _confirm,
            obscureText: !_showNext,
            hint: t.pwConfirmHint,
          ),
          if (_confirm.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Row(
                children: [
                  Icon(
                    matches ? Icons.check_circle : Icons.error_outline,
                    size: 14,
                    color: matches ? AppColors.success : AppColors.flagRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    matches ? t.pwMatches : t.pwNoMatch,
                    style: text.bodySmall?.copyWith(
                      color: matches ? AppColors.success : AppColors.flagRed,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: AppColors.navyDeep),
                  )
                : const Icon(Icons.lock_reset, size: 18),
            label: Text(_busy ? t.pwSaving : t.pwSubmit),
          ),
        ],
      ),
    );
  }
}

/// Three-segment strength meter — weak / fair / strong.
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});

  final int strength;

  @override
  Widget build(BuildContext context) {
    final t = L.text;
    final (color, label) = switch (strength) {
      >= 3 => (AppColors.success, t.pwStrong),
      2 => (AppColors.gold, t.pwFair),
      _ => (AppColors.flagRed, t.pwWeak),
    };

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? color : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != 2) const SizedBox(width: 4),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
