import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/api_client.dart';
import '../data/stores.dart';
import '../widgets/app_toast.dart';
import '../widgets/common.dart';
import '../widgets/form_widgets.dart';

/// Account claiming — mobile version of claim-account.html.
/// 3-step wizard: Verify Identity → Set Credentials → Confirmation.
/// Steps hit the same endpoints the web uses: POST /api/residents/claim/verify
/// finds the record, POST /api/residents/claim creates the login.
class ClaimAccountScreen extends StatefulWidget {
  const ClaimAccountScreen({super.key});

  @override
  State<ClaimAccountScreen> createState() => _ClaimAccountScreenState();
}

class _ClaimAccountScreenState extends State<ClaimAccountScreen> {
  int _step = 1;
  bool _busy = false;

  final _fname = TextEditingController();
  final _lname = TextEditingController();
  final _mother = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  DateTime? _dob;
  String _purok = kPuroks.first;

  // Set by /claim/verify — the matched resident record.
  int? _residentId;
  String _matchedName = '';
  String? _matchedPurok;

  @override
  void dispose() {
    for (final c in [_fname, _lname, _mother, _email, _mobile, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  String _dobIso() {
    final d = _dob;
    if (d == null) return '';
    String p(int n) => '$n'.padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 1) {
      if (_fname.text.trim().isEmpty || _lname.text.trim().isEmpty) {
        showAppToast(context, 'Please fill in your name to continue.',
            icon: Icons.error_outline);
        return;
      }
      setState(() => _busy = true);
      try {
        final res = await ApiClient.instance
            .post('/api/residents/claim/verify', {
          'first_name': _fname.text.trim(),
          'last_name': _lname.text.trim(),
          if (_dob != null) 'birthdate': _dobIso(),
        }) as Map<String, dynamic>;
        _residentId = res['id'] as int?;
        _matchedName = (res['name'] ?? '') as String;
        _matchedPurok = res['purok'] as String?;
        setState(() => _step = 2);
      } on ApiException catch (e) {
        if (mounted) {
          showAppToast(context, e.message, icon: Icons.error_outline);
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else if (_step == 2) {
      if (_email.text.trim().isEmpty) {
        showAppToast(context, 'Please enter your email address.',
            icon: Icons.error_outline);
        return;
      }
      if (_pass.text != _pass2.text) {
        showAppToast(context, 'Passwords do not match.',
            icon: Icons.error_outline);
        return;
      }
      if (_pass.text.length < 8) {
        showAppToast(context, 'Password must be at least 8 characters.',
            icon: Icons.error_outline);
        return;
      }
      setState(() => _busy = true);
      try {
        await ApiClient.instance.post('/api/residents/claim', {
          'resident_id': _residentId,
          'email': _email.text.trim(),
          'password': _pass.text,
          if (_mobile.text.trim().isNotEmpty) 'mobile_no': _mobile.text.trim(),
        });
        AuditLog.instance.log(
          'ACC_CLAIM_SUBMIT',
          'Account claimed by $_matchedName <${_email.text.trim()}>',
          category: AuditCategory.auth,
        );
        setState(() => _step = 3);
        if (mounted) {
          showAppToast(context, 'Account created! You can now sign in.',
              icon: Icons.vpn_key_outlined);
        }
      } on ApiException catch (e) {
        if (mounted) {
          showAppToast(context, e.message, icon: Icons.error_outline);
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        title: const Text('Claim Your Account'),
        backgroundColor: AppColors.navyDeep,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyDeep, AppColors.navy, AppColors.navyLight],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SealBadge(size: 64)),
                const SizedBox(height: AppSpacing.md),
                Text('Claim Your Account',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  'Link your existing barangay record to a new C.A.R.E.S. '
                  'resident account.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                _stepIndicator(),
                const SizedBox(height: AppSpacing.lg),
                if (_step == 1) ..._buildStep1(),
                if (_step == 2) ..._buildStep2(),
                if (_step == 3) ..._buildStep3(),
                const SizedBox(height: AppSpacing.md),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step indicator (1 ─ 2 ─ 3 with labels) ─────────────────
  Widget _stepIndicator() {
    const labels = ['Verify Identity', 'Set Credentials', 'Confirmation'];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              _stepDot(i),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 3,
                    color:
                        _step > i ? const Color(0xFF22C55E) : AppColors.divider,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 2
                          ? TextAlign.right
                          : TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            _step >= i + 1 ? AppColors.ink : AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepDot(int step) {
    final done = _step > step;
    final active = _step == step;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? const Color(0xFF22C55E)
            : active
                ? AppColors.navy
                : AppColors.divider,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.inkMuted,
                ),
              ),
      ),
    );
  }

  // ── Step 1: Verify identity ────────────────────────────────
  List<Widget> _buildStep1() {
    return [
      Text(
        "We'll search for your pre-existing record in the barangay database "
        'to link your account. Your data must already be registered with '
        'the barangay.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.inkMuted, height: 1.5),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
              child: AppTextField(
                  label: 'First Name', controller: _fname, hint: 'Juan')),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
              child: AppTextField(
                  label: 'Last Name', controller: _lname, hint: 'Santos')),
        ],
      ),
      AppTextField(
        label: 'Date of Birth',
        readOnly: true,
        hint: _dob == null
            ? 'Tap to select'
            : MaterialLocalizations.of(context).formatMediumDate(_dob!),
        onTap: _pickDob,
      ),
      AppDropdown<String>(
        label: 'Purok / Zone',
        value: _purok,
        items: kPuroks,
        onChanged: (v) => setState(() => _purok = v ?? _purok),
      ),
      AppTextField(
        label: "Mother's Maiden Name",
        controller: _mother,
        hint: 'For identity verification',
      ),
    ];
  }

  // ── Step 2: Set credentials ────────────────────────────────
  List<Widget> _buildStep2() {
    return [
      AlertBanner(
        kind: AlertKind.success,
        child: Text.rich(TextSpan(children: [
          const TextSpan(
              text: 'Record found! ',
              style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(
              text: 'Matched: $_matchedName'
                  '${_matchedPurok != null ? ' ($_matchedPurok)' : ''}. '
                  'Please set your login credentials below.'),
        ])),
      ),
      AppTextField(
        label: 'Email Address',
        controller: _email,
        hint: 'your@email.com',
        keyboardType: TextInputType.emailAddress,
      ),
      AppTextField(
        label: 'Mobile Number',
        controller: _mobile,
        hint: '09XXXXXXXXX',
        keyboardType: TextInputType.phone,
      ),
      AppTextField(
        label: 'Password',
        controller: _pass,
        hint: 'Minimum 8 characters',
        obscureText: true,
      ),
      AppTextField(
        label: 'Confirm Password',
        controller: _pass2,
        hint: 'Re-enter password',
        obscureText: true,
      ),
      const AlertBanner(
        kind: AlertKind.info,
        child: Text('Your account will be linked to your existing barangay '
            'record and becomes active immediately after creation.'),
      ),
    ];
  }

  // ── Step 3: Confirmation ───────────────────────────────────
  List<Widget> _buildStep3() {
    final text = Theme.of(context).textTheme;
    return [
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF22C55E),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 34),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Account Created!',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(color: AppColors.ink)),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Your barangay record is now linked to your new C.A.R.E.S. account. '
        'You can sign in right away using the email and password you set.',
        textAlign: TextAlign.center,
        style: text.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.5),
      ),
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text('SIGN IN WITH',
                style: text.labelSmall?.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(_email.text.trim(),
                style: text.titleLarge?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ];
  }

  Widget _footer() {
    if (_step == 3) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Done — Go to Sign In'),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _busy ? null : _next,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward, size: 18),
          label: Text(_step == 1 ? 'Verify Identity' : 'Create Account'),
        ),
      ],
    );
  }
}
