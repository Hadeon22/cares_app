import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/fade_slide.dart';
import '../data/session.dart';
import '../widgets/common.dart';
import 'claim_account_screen.dart';

/// Sign-in screen — mobile version of system.html.
/// Role chips (Admin / Officer / Resident) + credentials.
/// Residents return to the portal; staff land on the MIS dashboard.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole _role = UserRole.admin;
  final _userCtrl =
      TextEditingController(text: 'admin@condelabac.gov.ph');
  final _passCtrl = TextEditingController(text: '••••••••');

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _signIn() {
    AppSession.instance.signIn(_role, _userCtrl.text);
    // main.dart listens to the session and swaps in the right shell.
    Navigator.of(context).popUntil((r) => r.isFirst);
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
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
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
                        style: text.headlineSmall?.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Integrated Barangay Management System · Batangas City',
                        textAlign: TextAlign.center,
                        style:
                            text.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Role chips ─────────────────────────────
                      Row(
                        children: [
                          for (final role in UserRole.values) ...[
                            Expanded(child: _roleChip(role)),
                            if (role != UserRole.values.last)
                              const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _label('Username / Email'),
                      TextField(
                        controller: _userCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'e.g. admin@condelabac.gov.ph',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _label('Password'),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration:
                            const InputDecoration(hintText: '••••••••'),
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      FilledButton(
                        onPressed: _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: AppColors.onNavy,
                        ),
                        child: const Text('Sign In to System'),
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
                          textStyle: text.labelSmall
                              ?.copyWith(letterSpacing: 0.4),
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

  Widget _roleChip(UserRole role) {
    final selected = _role == role;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.divider,
            width: 1.4,
          ),
        ),
        child: Text(
          role.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.gold : AppColors.inkMuted,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
