import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/resident_profile.dart';
import 'form_widgets.dart';
import 'photo_picker.dart';

/// Full resident profile — mobile twin of the web's View-Resident modal
/// (js/pages/residency.js renderResidentDetail): header with name + status
/// badges, then a label/value list of every field on record.
class ResidentDetailView extends StatelessWidget {
  const ResidentDetailView({super.key, required this.profile});

  final ResidentProfile profile;

  String _fmtDate(BuildContext context, DateTime? d) => d == null
      ? '—'
      : MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    final r = profile;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ResidentAvatar(
              radius: 24,
              photo: r.photo,
              initials: '${r.firstName.isNotEmpty ? r.firstName[0] : '?'}'
                  '${r.lastName.isNotEmpty ? r.lastName[0] : ''}',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.fullName,
                      style: text.titleMedium?.copyWith(
                          color: AppColors.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusBadge(
                        r.accountClaimed ? 'Active (claimed)' : 'Unclaimed',
                        kind: r.accountClaimed
                            ? BadgeKind.success
                            : BadgeKind.gray,
                      ),
                      StatusBadge('Record: ${r.lifecycleStatus}',
                          kind: BadgeKind.gray),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _row(context, 'Resident ID', '#${r.id}'),
        _row(context, 'Age', r.age == null ? '—' : '${r.age} yrs'),
        _row(context, 'Birthdate', _fmtDate(context, r.birthdate)),
        _row(context, 'Sex', r.sexLabel),
        _row(context, 'Civil Status', r.civilStatus ?? '—'),
        _row(context, 'Contact No.', r.contactNo ?? '—'),
        _row(context, 'Occupation', r.occupation ?? '—'),
        _row(context, 'Voter Status', r.voterStatus ?? '—'),
        _row(context, 'Purok', r.purok ?? '—'),
        _row(context, 'Household No.', r.householdNo ?? '—'),
        _row(context, 'Address', r.addressText ?? '—'),
        _row(context, 'Relationship to Head', r.relationshipToHead ?? '—'),
        _row(
            context,
            'Classifications',
            r.classifications.isEmpty
                ? '—'
                : r.classifications.join(', ')),
        _row(context, 'Date Registered', _fmtDate(context, r.dateRegistered)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
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

/// Bottom sheet wrapper: fetches the profile then shows [ResidentDetailView].
Future<void> showResidentDetailSheet(BuildContext context, int residentId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FutureBuilder<ResidentProfile>(
          future: ResidentProfile.fetch(residentId),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Could not load resident.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.flagRed),
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold)),
              );
            }
            return ResidentDetailView(profile: snap.data!);
          },
        ),
      ),
    ),
  );
}
