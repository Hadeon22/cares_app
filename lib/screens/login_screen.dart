import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/fade_slide.dart';
import '../data/api_client.dart';
import '../data/session.dart';
import '../widgets/app_toast.dart';
import '../widgets/common.dart';
import 'claim_account_screen.dart';

/// Sign-in screen — mobile version of system.html.
/// Signs in against POST /api/auth/login: the account's role (staff or
/// resident) comes from the database, same as the web system.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final email = _userCtrl.text.trim();
    if (email.isEmpty || _passCtrl.text.isEmpty) {
      showAppToast(context, 'Please enter your email and password.',
          icon: Icons.error_outline);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppSession.instance.signIn(email, _passCtrl.text);
      if (!mounted) return;
      // main.dart listens to the session and swaps in the right shell.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyDeep, AppColors.navy, AppColors.navyLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: FadeSlide(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SealBadge(size: 76)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Brgy. Conde Labac',
                        textAlign: TextAlign.center,
                        style:
                            text.headlineSmall?.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Integrated Barangay Management System · Batangas City',
                        textAlign: TextAlign.center,
                        style:
                            text.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _label('Username / Email'),
                      TextField(
                        controller: _userCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          hintText: 'e.g. admin@condelabac.gov.ph',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _label('Password'),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(hintText: '••••••••'),
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: AppColors.onNavy,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.gold),
                              )
                            : const Text('Sign In to System'),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Claim account ──────────────────────────
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('New resident? ',
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.inkMuted)),
                          InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ClaimAccountScreen()),
                            ),
                            child: Text(
                              'Claim your account →',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.goldDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, size: 15),
                        label: const Text('Back to C.A.R.E.S. Landing Page'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkMuted,
                          textStyle:
                              text.labelSmall?.copyWith(letterSpacing: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          value.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
      );
}
