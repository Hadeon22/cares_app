import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/resident_profile.dart';
import '../../data/session.dart';
import '../../widgets/resident_detail.dart';
import 'edit_request_screen.dart';

/// "My Information" — the signed-in user's own record: account details plus,
/// for residents, the full barangay record (same fields as the web's
/// View-Resident modal).
class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  late Future<ResidentProfile>? _future = _load();

  Future<ResidentProfile>? _load() {
    final id = AppSession.instance.residentId;
    return id == null ? null : ResidentProfile.fetch(id);
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Information')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          // ── Account section ─────────────────────────────────
          _sectionCard(
            context,
            title: 'Account',
            child: Column(
              children: [
                _kv(context, 'Name', session.displayName),
                _kv(context, 'Email', session.user),
                _kv(context, 'Role', session.serverRole),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Barangay record section ─────────────────────────
          if (_future == null)
            _sectionCard(
              context,
              title: 'Barangay Record',
              child: Text(
                'This account is not linked to a resident record. Staff '
                'accounts only carry the account details above.',
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            FutureBuilder<ResidentProfile>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return _sectionCard(
                    context,
                    title: 'Barangay Record',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Could not load your record.\n${snap.error}',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.flagRed)),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          // Navy on light — the theme's outlined style is
                          // for navy backdrops and is invisible here.
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.navy),
                          ),
                          onPressed: () =>
                              setState(() => _future = _load()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.gold)),
                  );
                }
                return _sectionCard(
                  context,
                  title: 'Barangay Record',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResidentDetailView(profile: snap.data!),
                      const SizedBox(height: AppSpacing.md),
                      // Residents can't edit the record directly — changes
                      // go through an edit request that staff approve.
                      // Filled gold (the app's primary button) — the theme's
                      // OutlinedButton is styled for navy backdrops and
                      // disappears on this cream card.
                      FilledButton.icon(
                        onPressed: () async {
                          final submitted =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditRequestScreen(profile: snap.data!),
                            ),
                          );
                          if (submitted == true && mounted) {
                            setState(() => _future = _load());
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Request Profile Edit'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: text.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(label,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: text.bodySmall?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
