import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/api_client.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';

/// Add / Edit Resident — the mobile version of the web residency page's
/// modal-add-resident (js/pages/residency.js). One screen, two modes:
/// [residentId] null = add (POST /api/residents), set = edit
/// (PUT /api/residents/:id). Pops `true` after a successful save so the
/// caller can refresh the directory.
class ResidentFormScreen extends StatefulWidget {
  const ResidentFormScreen({super.key, this.residentId});

  final int? residentId;

  bool get isEditing => residentId != null;

  @override
  State<ResidentFormScreen> createState() => _ResidentFormScreenState();
}

/// Household row from GET /api/households, for the Household dropdown.
class _HouseholdOption {
  const _HouseholdOption(this.id, this.label);
  final int? id; // null = "— None —"
  final String label;
}

class _ResidentFormScreenState extends State<ResidentFormScreen> {
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _suffix = TextEditingController();
  final _contact = TextEditingController();
  final _occupation = TextEditingController();

  DateTime? _birthdate;
  String _sex = '';
  String _civil = '';
  String _voter = '';
  String _relationship = '';
  int? _householdId;
  final Set<String> _classifications = {};

  static const _none = _HouseholdOption(null, '— None —');
  List<_HouseholdOption> _households = const [_none];

  // Same option lists as the web modal's selects.
  static const _sexOptions = {'': '—', 'M': 'Male', 'F': 'Female'};
  static const _civilOptions = ['—', 'Single', 'Married', 'Widowed', 'Separated'];
  static const _voterOptions = ['—', 'Registered', 'Not Registered'];
  static const _relationshipOptions = [
    '—', 'Head', 'Spouse', 'Child', 'Parent', 'Sibling',
    'Other Relative', 'Non-relative',
  ];

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
    if (widget.isEditing) _loadRecord();
  }

  @override
  void dispose() {
    for (final c in [_last, _first, _middle, _suffix, _contact, _occupation]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Household dropdown options — "HH-0001 — Purok 1 (3)", like the web.
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
              (raw['household_id'] as num?)?.toInt(),
              '${raw['household_no'] ?? 'HH-${raw['household_id']}'}'
              '${raw['purok'] != null ? ' — ${raw['purok']}' : ''}'
              ' (${raw['members'] ?? 0})',
            ),
        ];
      });
    } catch (_) {
      /* dropdown just stays "— None —" */
    }
  }

  /// Edit mode: prefill from the same GET /api/residents/:id payload the
  /// web modal uses (raw JSON — we need household_id + classification slugs).
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
        _sex = (j['sex'] as String?) ?? '';
        _civil = (j['civil_status'] as String?) ?? '';
        _voter = (j['voter_status'] as String?) ?? '';
        _relationship = (j['relationship_to_head'] as String?) ?? '';
        _householdId = (j['household_id'] as num?)?.toInt();
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
      'relationship_to_head':
          _relationship.isEmpty || _relationship == '—' ? null : _relationship,
      'contact_no': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      'occupation':
          _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      'voter_status': _voter.isEmpty || _voter == '—' ? null : _voter,
      'household_id': _householdId,
      'classifications': _classifications.toList(),
    };

    setState(() => _busy = true);
    try {
      if (widget.isEditing) {
        await ApiClient.instance
            .put('/api/residents/${widget.residentId}', body);
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
      'Resident $last, $first $verb',
      category: AuditCategory.system,
    );
    if (!mounted) return;
    showAppToast(context, 'Resident $first $last $verb',
        icon: Icons.check_circle_outline);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit Resident' : 'Add Resident';
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
                AppDropdown<_HouseholdOption>(
                  // FormFields keep their first value across rebuilds, so
                  // recreate the field when the async option list lands.
                  key: ValueKey('household-${_households.length}'),
                  label: 'Household',
                  value: _households.firstWhere(
                      (h) => h.id == _householdId,
                      orElse: () => _none),
                  items: _households,
                  itemLabel: (h) => h.label,
                  onChanged: (v) => setState(() => _householdId = v?.id),
                ),
                AppDropdown<String>(
                  label: 'Relationship to Head',
                  value: _relationship.isEmpty ? '—' : _relationship,
                  items: _relationshipOptions,
                  onChanged: (v) => setState(() => _relationship = v ?? ''),
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
                  label: Text(
                      widget.isEditing ? 'Save Changes' : 'Save Resident'),
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
