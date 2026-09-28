import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/api_client.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/photo_picker.dart';

/// Add / Edit Resident — the mobile version of the web residency page's
/// modal-add-resident (js/pages/residency.js). One screen, two modes:
/// [residentId] null = add (POST /api/residents), set = edit
/// (PUT /api/residents/:id). Pops `true` after a successful save so the
/// caller can refresh the directory.
///
/// A third use: Account Claiming's "Add resident record". The applicant is
/// not on file, so the record is made with this same form, [prefill]ed from
/// the application, and saving hands the body to [onSubmit] (which creates
/// the record and approves the account in one call) instead of POSTing it.
class ResidentFormScreen extends StatefulWidget {
  const ResidentFormScreen({
    super.key,
    this.residentId,
    this.prefill,
    this.onSubmit,
    this.title,
    this.submitLabel,
  });

  final int? residentId;
  final Map<String, dynamic>? prefill;
  final Future<void> Function(Map<String, dynamic> body)? onSubmit;
  final String? title;
  final String? submitLabel;

  bool get isEditing => residentId != null;

  @override
  State<ResidentFormScreen> createState() => _ResidentFormScreenState();
}

/// A household from GET /api/households, for the Household dropdown.
///
/// A household IS a building tagged as one on the GIS map, so [id] is a
/// building_id and the label is the tag's own name ("Bahay ni Shane"). A
/// barangay with nothing tagged yet yields an empty list, which is why the
/// field is optional.
///
/// A house made of several footprints that were group-tagged together arrives
/// as ONE row: [id] is the group's representative building and [memberIds]
/// holds every footprint, so a resident sitting on any of them still resolves
/// to this option instead of falling back to "— None —".
class _HouseholdOption {
  const _HouseholdOption(this.id, this.label, [this.memberIds = const []]);
  final int? id; // building_id; null = "— None —"
  final String label;
  final List<int> memberIds;

  bool owns(int? buildingId) =>
      buildingId != null &&
      (id == buildingId || memberIds.contains(buildingId));
}

/// A purok from GET /api/puroks. Purok sits on the resident record now that
/// there is no household table for it to be inherited from.
class _PurokOption {
  const _PurokOption(this.id, this.label);
  final int? id; // null = "—"
  final String label;
}

class _ResidentFormScreenState extends State<ResidentFormScreen> {
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _suffix = TextEditingController();
  final _contact = TextEditingController();
  final _occupation = TextEditingController();
  final _address = TextEditingController();

  DateTime? _birthdate;

  /// Profile photo as a base64 data URL; [_photoDirty] tracks whether the
  /// user changed it, so PUT only sends `photo` when it actually changed
  /// ('' = remove, per the server's clear semantics).
  String? _photo;
  bool _photoDirty = false;

  String _sex = '';
  String _civil = '';
  String _voter = '';
  int? _buildingId;
  int? _purokId;
  final Set<String> _classifications = {};

  /// The resident's two SMS settings. Staff ask at registration or at the
  /// counter; only a switch actually changed here is sent, so an ordinary
  /// edit never claims the resident was asked (resident.sms_pref_set_at).
  bool _smsUpdates = true;
  bool _smsAdvisories = true;
  bool _smsUpdatesLoaded = true;
  bool _smsAdvisoriesLoaded = true;
  String? _smsChosenAt;

  /// The record's lifecycle classification (resident.status). Edit mode only;
  /// a new resident takes the table's 'active' default. Setting it to
  /// 'deceased' suspends the login account this record belongs to — the server
  /// does it in the same transaction as the save (routes/residents.js).
  String _status = 'active';

  /// Whether this resident has a claimed account, which decides whether the
  /// deceased warning has anything to warn about.
  bool _claimed = false;

  static const _statusOptions = <String, String>{
    'active': 'Active resident',
    'deceased': 'Deceased',
    'moved': 'Moved out of the barangay',
  };

  static const _none = _HouseholdOption(null, '— None —');
  List<_HouseholdOption> _households = const [_none];

  static const _noPurok = _PurokOption(null, '—');
  List<_PurokOption> _puroks = const [_noPurok];

  /// Mirrors GIS_HOUSEHOLD_SUBCAT_META in the web's js/gis-map.js — the
  /// classification the map tag already carries.
  static const _householdClassLabels = {
    'seniors': 'Senior Citizen',
    'pwd': 'PWD',
    'solo-parent': 'Solo Parent',
    'indigent': 'Indigent Family',
  };

  // Same option lists as the web modal's selects.
  static const _sexOptions = {'': '—', 'M': 'Male', 'F': 'Female'};
  static const _civilOptions = ['—', 'Single', 'Married', 'Widowed', 'Separated'];
  static const _voterOptions = ['—', 'Registered', 'Not Registered'];

  /// classification slug (DB) → checkbox label.
  static const _catOptions = {
    'senior': 'Senior Citizen',
    'pwd': 'PWD',
    'solo-parent': 'Solo Parent',
    'indigent': 'Indigent Family',
  };

  bool _busy = false;
  late bool _loadingRecord = widget.isEditing;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
    _loadPuroks();
    if (widget.isEditing) _loadRecord();
    final p = widget.prefill;
    if (p != null) {
      _last.text = (p['last_name'] ?? '').toString();
      _first.text = (p['first_name'] ?? '').toString();
      _middle.text = (p['middle_name'] ?? '').toString();
      _suffix.text = (p['suffix'] ?? '').toString();
      _contact.text = (p['contact_no'] ?? '').toString();
      _address.text = (p['address_text'] ?? '').toString();
      _birthdate = DateTime.tryParse(p['birthdate']?.toString() ?? '');
      _sex = (p['sex'] as String?) ?? '';
      _purokId = (p['purok_id'] as num?)?.toInt();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _last, _first, _middle, _suffix, _contact, _occupation, _address
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Household dropdown options — "Bahay ni Shane (3)", like the web. These
  /// are the buildings tagged as households on the GIS map.
  /// Non-fatal on failure: a resident can be saved without a household.
  Future<void> _loadHouseholds() async {
    try {
      final rows = await ApiClient.instance.get('/api/households') as List;
      if (!mounted) return;
      setState(() {
        _households = [
          _none,
          for (final raw in rows.cast<Map<String, dynamic>>())
            _HouseholdOption(
              (raw['building_id'] as num?)?.toInt(),
              _householdLabel(raw),
              [
                for (final id in (raw['member_ids'] as List?) ?? const [])
                  (id as num).toInt(),
              ],
            ),
        ];
      });
    } catch (_) {
      /* dropdown just stays "— None —" */
    }
  }

  static String _householdLabel(Map<String, dynamic> raw) {
    final name = (raw['name'] as String?)?.trim();
    final cls = _householdClassLabels[raw['subcat']];
    final base = (name == null || name.isEmpty)
        ? 'Untagged building #${raw['building_id']}'
        : name;
    // The footprint count is only worth saying when there is more than one —
    // it explains why the map highlights several buildings for this one entry.
    final buildings = (raw['buildings'] as num?)?.toInt() ?? 1;
    final spread = buildings > 1 ? ' · $buildings buildings' : '';
    return '$base${cls != null ? ' — $cls' : ''} (${raw['members'] ?? 0})$spread';
  }

  /// Purok dropdown options. Same non-fatal contract as the households above.
  Future<void> _loadPuroks() async {
    try {
      final rows = await ApiClient.instance.get('/api/puroks') as List;
      if (!mounted) return;
      setState(() {
        _puroks = [
          _noPurok,
          for (final raw in rows.cast<Map<String, dynamic>>())
            _PurokOption(
              (raw['purok_id'] as num?)?.toInt(),
              (raw['name'] ?? '') as String,
            ),
        ];
      });
    } catch (_) {
      /* dropdown just stays "—" */
    }
  }

  /// Edit mode: prefill from the same GET /api/residents/:id payload the
  /// web modal uses (raw JSON — we need building_id/purok_id + classification
  /// slugs, which the display-oriented ResidentProfile does not carry).
  Future<void> _loadRecord() async {
    try {
      final j = await ApiClient.instance
          .get('/api/residents/${widget.residentId}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _last.text = (j['last_name'] ?? '') as String;
        _first.text = (j['first_name'] ?? '') as String;
        _middle.text = (j['middle_name'] ?? '') as String? ?? '';
        _suffix.text = (j['suffix'] ?? '') as String? ?? '';
        _contact.text = (j['contact_no'] ?? '') as String? ?? '';
        _occupation.text = (j['occupation'] ?? '') as String? ?? '';
        _birthdate = DateTime.tryParse(j['birthdate']?.toString() ?? '');
        _photo = j['photo'] as String?;
        _sex = (j['sex'] as String?) ?? '';
        _civil = (j['civil_status'] as String?) ?? '';
        _voter = (j['voter_status'] as String?) ?? '';
        _address.text = (j['address_text'] ?? '') as String? ?? '';
        _buildingId = (j['building_id'] as num?)?.toInt();
        _purokId = (j['purok_id'] as num?)?.toInt();
        // 'archived' residents never reach this form (they are out of the
        // directory), so anything unexpected shows as Active rather than
        // silently rewriting the record's state on the next save.
        final s = (j['status'] as String?) ?? 'active';
        _status = _statusOptions.containsKey(s) ? s : 'active';
        _claimed = j['account_claimed'] == true;
        _smsUpdates = _smsUpdatesLoaded = j['sms_updates'] != false;
        _smsAdvisories = _smsAdvisoriesLoaded = j['sms_advisories'] != false;
        _smsChosenAt = j['sms_pref_set_at'] as String?;
        _classifications
          ..clear()
          ..addAll((j['classifications'] as List? ?? const [])
              .map((c) => c.toString()));
        _loadingRecord = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRecord = false;
        _loadError = 'Could not load resident: $e';
      });
    }
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

  Future<void> _save() async {
    if (_busy) return;
    final last = _last.text.trim();
    final first = _first.text.trim();
    if (last.isEmpty || first.isEmpty) {
      showAppToast(context, 'Last name and first name are required.',
          icon: Icons.error_outline);
      return;
    }

    // account_claimed is never sent — new residents always start Unclaimed;
    // only the Account Claiming flow activates them (same as the web).
    final body = <String, dynamic>{
      'last_name': last,
      'first_name': first,
      'middle_name': _middle.text.trim().isEmpty ? null : _middle.text.trim(),
      'suffix': _suffix.text.trim().isEmpty ? null : _suffix.text.trim(),
      'birthdate': _birthdate == null ? null : _dateParam(_birthdate!),
      'sex': _sex.isEmpty ? null : _sex,
      'civil_status': _civil.isEmpty || _civil == '—' ? null : _civil,
      'contact_no': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      'occupation':
          _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      'voter_status': _voter.isEmpty || _voter == '—' ? null : _voter,
      // '' rather than null: the server reads '' as "clear this field" and
      // null as "leave it alone", so clearing Household / Purok / Address on
      // the form actually detaches instead of silently keeping the old value.
      'building_id': _buildingId?.toString() ?? '',
      'purok_id': _purokId?.toString() ?? '',
      'address_text': _address.text.trim(),
      'classifications': _classifications.toList(),
      if (_smsUpdates != _smsUpdatesLoaded) 'sms_updates': _smsUpdates,
      if (_smsAdvisories != _smsAdvisoriesLoaded) 'sms_advisories': _smsAdvisories,
      // Record Classification only exists in edit mode.
      if (widget.isEditing) 'status': _status,
      // Only send the photo when it changed; '' clears it on the server.
      if (_photoDirty) 'photo': _photo ?? '',
    };

    setState(() => _busy = true);
    if (widget.onSubmit != null) {
      try {
        await widget.onSubmit!(body);
      } catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
        }
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    Map<String, dynamic>? result;
    try {
      if (widget.isEditing) {
        result = await ApiClient.instance
            .put('/api/residents/${widget.residentId}', body)
            as Map<String, dynamic>?;
      } else {
        await ApiClient.instance.post('/api/residents', body);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
      return;
    }

    final verb = widget.isEditing ? 'updated' : 'added';
    AuditLog.instance.log(
      widget.isEditing ? 'RESIDENT_EDIT' : 'RESIDENT_ADD',
      widget.isEditing && _status == 'deceased'
          ? 'Resident $last, $first classified as deceased'
          : 'Resident $last, $first $verb',
      level: widget.isEditing && _status == 'deceased'
          ? AuditLevel.warning
          : AuditLevel.info,
      category: AuditCategory.system,
    );
    if (!mounted) return;
    // The server reports whether saving this record also closed (or reopened)
    // the resident's login — the part of the save that happened somewhere the
    // person tapping Save was not looking.
    showAppToast(
        context,
        result?['account_suspended'] == true
            ? 'Resident $first $last recorded as deceased — their account is '
                'suspended'
            : result?['account_reactivated'] == true
                ? 'Resident $first $last updated — their account can sign in '
                    'again'
                : 'Resident $first $last $verb',
        icon: Icons.check_circle_outline);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title ?? (widget.isEditing ? 'Edit Resident' : 'Add Resident');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loadingRecord
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
              children: [
                if (_loadError != null)
                  AlertBanner(
                      kind: AlertKind.danger, child: Text(_loadError!)),
                ResidentPhotoPicker(
                  photo: _photo,
                  initials:
                      '${_first.text.isNotEmpty ? _first.text[0] : '?'}'
                      '${_last.text.isNotEmpty ? _last.text[0] : ''}',
                  onChanged: (p) => setState(() {
                    _photo = p;
                    _photoDirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: AppTextField(
                            label: 'Last Name *',
                            controller: _last,
                            hint: 'e.g. Santos')),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                        child: AppTextField(
                            label: 'First Name *',
                            controller: _first,
                            hint: 'e.g. Pedro')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: AppTextField(
                            label: 'Middle Name',
                            controller: _middle,
                            hint: 'optional')),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                        child: AppTextField(
                            label: 'Suffix',
                            controller: _suffix,
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
                  label: 'Sex',
                  value: _sex,
                  items: _sexOptions.keys.toList(),
                  itemLabel: (k) => _sexOptions[k]!,
                  onChanged: (v) => setState(() => _sex = v ?? ''),
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
                AppDropdown<_PurokOption>(
                  // FormFields keep their first value across rebuilds, so
                  // recreate the field when the async option list lands.
                  key: ValueKey('purok-${_puroks.length}'),
                  label: 'Purok',
                  value: _puroks.firstWhere((p) => p.id == _purokId,
                      orElse: () => _noPurok),
                  items: _puroks,
                  itemLabel: (p) => p.label,
                  onChanged: (v) => setState(() => _purokId = v?.id),
                ),
                AppTextField(
                  label: 'Address',
                  controller: _address,
                  hint: 'e.g. 49 Sitio Gitna',
                ),
                AppDropdown<_HouseholdOption>(
                  key: ValueKey('household-${_households.length}'),
                  label: 'Household',
                  value: _households.firstWhere(
                      (h) => h.owns(_buildingId),
                      orElse: () => _none),
                  items: _households,
                  itemLabel: (h) => h.label,
                  onChanged: (v) => setState(() => _buildingId = v?.id),
                ),
                const FieldLabel('Classifications'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    for (final e in _catOptions.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: _classifications.contains(e.key),
                        selectedColor: AppColors.goldSoft,
                        checkmarkColor: AppColors.goldDeep,
                        onSelected: (on) => setState(() {
                          on
                              ? _classifications.add(e.key)
                              : _classifications.remove(e.key);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const FieldLabel('Text Messages (SMS)'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _smsUpdates,
                  onChanged: (v) => setState(() => _smsUpdates = v),
                  title: const Text('Certificate updates'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _smsAdvisories,
                  onChanged: (v) => setState(() => _smsAdvisories = v),
                  title: const Text('Barangay announcements'),
                ),
                Text(
                  'Texted to the contact number above. Emergency announcements '
                  'and security codes are always sent.'
                  '${_smsChosenAt == null ? ' Not asked yet — ask the resident.' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
                // Record classification. Editing only — a resident being added
                // is alive and living here by definition, and offering
                // "Deceased" on a blank form is an invitation to a mis-click on
                // a record nobody has checked yet.
                if (widget.isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppDropdown<String>(
                    label: 'Record Classification',
                    value: _statusOptions.containsKey(_status)
                        ? _statusOptions[_status]!
                        : _statusOptions['active']!,
                    items: _statusOptions.values.toList(),
                    onChanged: (v) => setState(() {
                      _status = _statusOptions.entries
                          .firstWhere((e) => e.value == v,
                              orElse: () => const MapEntry('active', ''))
                          .key;
                    }),
                  ),
                  if (_status == 'deceased')
                    AlertBanner(
                      kind: AlertKind.warning,
                      child: Text(_claimed
                          ? 'Their account is suspended when you save: it can '
                              'no longer sign in, but nothing is deleted and it '
                              'stays in User Management. Setting this back to '
                              'Active lifts the suspension.'
                          : 'This resident has no claimed account, so there is '
                              'nothing to suspend. The record stays on file.'),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (!widget.isEditing)
                  const AlertBanner(
                    kind: AlertKind.info,
                    child: Text('New residents start as Unclaimed — the '
                        'status becomes Active only when the resident claims '
                        'their account via Account Claiming.'),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: Text(widget.submitLabel ??
                      (widget.isEditing ? 'Save Changes' : 'Save Resident')),
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
