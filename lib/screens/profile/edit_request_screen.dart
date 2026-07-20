import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/resident_profile.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/photo_picker.dart';

/// "Request Profile Edit" — a resident proposes changes to their own
/// barangay record. Nothing is applied directly: the changed fields are
/// submitted as a resident_edit_request and reviewed by staff in
/// MIS → Barangay Residency → Edit Requests.
class EditRequestScreen extends StatefulWidget {
  const EditRequestScreen({super.key, required this.profile});

  /// The record being edited (prefills the form and is the diff baseline).
  final ResidentProfile profile;

  @override
  State<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<EditRequestScreen> {
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _middle =
      TextEditingController(text: widget.profile.middleName ?? '');
  late final _suffix =
      TextEditingController(text: widget.profile.suffix ?? '');
  late final _contact =
      TextEditingController(text: widget.profile.contactNo ?? '');
  late final _occupation =
      TextEditingController(text: widget.profile.occupation ?? '');

  late DateTime? _birthdate = widget.profile.birthdate;
  late String _civil = widget.profile.civilStatus ?? '';
  late String _voter = widget.profile.voterStatus ?? '';
  late String? _photo = widget.profile.photo;
  bool _photoDirty = false;

  bool _busy = false;

  static const _civilOptions = [
    '—', 'Single', 'Married', 'Widowed', 'Separated'
  ];
  static const _voterOptions = ['—', 'Registered', 'Not Registered'];

  @override
  void dispose() {
    for (final c in [_last, _first, _middle, _suffix, _contact, _occupation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  String _dateParam(DateTime d) {
    String p(int n) => '$n'.padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  /// Only the fields that differ from the record go into the request.
  Map<String, dynamic> _diff() {
    final p = widget.profile;
    final changes = <String, dynamic>{};
    void text(String key, TextEditingController c, String? old) {
      final v = c.text.trim();
      if (v != (old ?? '').trim()) changes[key] = v.isEmpty ? null : v;
    }

    text('last_name', _last, p.lastName);
    text('first_name', _first, p.firstName);
    text('middle_name', _middle, p.middleName);
    text('suffix', _suffix, p.suffix);
    text('contact_no', _contact, p.contactNo);
    text('occupation', _occupation, p.occupation);

    final oldBd = p.birthdate == null ? null : _dateParam(p.birthdate!);
    final newBd = _birthdate == null ? null : _dateParam(_birthdate!);
    if (newBd != oldBd) changes['birthdate'] = newBd;

    final civil = _civil == '—' ? '' : _civil;
    if (civil != (p.civilStatus ?? '')) {
      changes['civil_status'] = civil.isEmpty ? null : civil;
    }
    final voter = _voter == '—' ? '' : _voter;
    if (voter != (p.voterStatus ?? '')) {
      changes['voter_status'] = voter.isEmpty ? null : voter;
    }
    if (_photoDirty && _photo != p.photo) changes['photo'] = _photo;
    return changes;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_last.text.trim().isEmpty || _first.text.trim().isEmpty) {
      showAppToast(context, 'Last name and first name cannot be empty.',
          icon: Icons.error_outline);
      return;
    }
    final changes = _diff();
    if (changes.isEmpty) {
      showAppToast(context, 'Nothing changed — your record already matches.',
          icon: Icons.info_outline);
      return;
    }
    setState(() => _busy = true);
    try {
      await EditRequestStore.instance.submit(
        residentId: widget.profile.id,
        changes: changes,
        accountId: AppSession.instance.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not submit: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    if (!mounted) return;
    showAppToast(
        context,
        'Edit request submitted — the barangay office will review it.',
        icon: Icons.mark_email_read_outlined);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Profile Edit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const AlertBanner(
            kind: AlertKind.info,
            child: Text('Changes are not applied immediately. Your request '
                'is sent to the barangay office for approval, and you will '
                'be notified of the result.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ResidentPhotoPicker(
            photo: _photo,
            initials:
                '${widget.profile.firstName.isNotEmpty ? widget.profile.firstName[0] : '?'}'
                '${widget.profile.lastName.isNotEmpty ? widget.profile.lastName[0] : ''}',
            onChanged: (p) => setState(() {
              _photo = p;
              _photoDirty = true;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: AppTextField(label: 'Last Name', controller: _last)),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                  child:
                      AppTextField(label: 'First Name', controller: _first)),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: AppTextField(
                      label: 'Middle Name', controller: _middle,
                      hint: 'optional')),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                  child: AppTextField(
                      label: 'Suffix', controller: _suffix,
                      hint: 'e.g. Jr., III')),
            ],
          ),
          AppTextField(
            label: 'Birthdate',
            readOnly: true,
            hint: _birthdate == null
                ? 'Tap to select'
                : MaterialLocalizations.of(context)
                    .formatMediumDate(_birthdate!),
            onTap: _pickBirthdate,
          ),
          AppDropdown<String>(
            label: 'Civil Status',
            value: _civil.isEmpty ? '—' : _civil,
            items: _civilOptions,
            onChanged: (v) => setState(() => _civil = v ?? ''),
          ),
          AppDropdown<String>(
            label: 'Voter Status',
            value: _voter.isEmpty ? '—' : _voter,
            items: _voterOptions,
            onChanged: (v) => setState(() => _voter = v ?? ''),
          ),
          AppTextField(
            label: 'Contact No.',
            controller: _contact,
            keyboardType: TextInputType.phone,
            hint: 'e.g. 0917 123 4567',
          ),
          AppTextField(
            label: 'Occupation',
            controller: _occupation,
            hint: 'e.g. Farmer',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: const Text('Submit for Approval'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
