import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../gis/gis_map_view.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';

/// File an Incident / Concern — mobile version of the unified blotter
/// flow (js/incident-report.js):
///   • No severity field.
///   • Date/time is always "now" — shown read-only.
///   • Complainant auto-fills (read-only) for a signed-in resident.
///   • Respondent / Witness fields appear only for interpersonal types.
///   • Location is picked by dropping a pin on the embedded GIS map,
///     exactly like the web modal's pin-picker.
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  IncidentType _type = kIncidentTypes.first;
  final _complainant = TextEditingController();
  final _contact = TextEditingController();
  final _respondent = TextEditingController();
  final _witnesses = TextEditingController();
  final _narration = TextEditingController();
  Offset? _pickedPoint; // normalized map position
  late final DateTime _now;
  late final bool _knownReporter;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final session = AppSession.instance;
    _knownReporter = session.isSignedIn;
    if (_knownReporter) _complainant.text = session.displayName;
  }

  @override
  void dispose() {
    for (final c in [
      _complainant,
      _contact,
      _respondent,
      _witnesses,
      _narration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    if (_complainant.text.trim().isEmpty) {
      showAppToast(context, "Please enter the complainant's full name.",
          icon: Icons.error_outline);
      return;
    }
    if (_pickedPoint == null) {
      showAppToast(context,
          'Please drop a pin on the map to mark where the incident happened.',
          icon: Icons.error_outline);
      return;
    }
    if (_narration.text.trim().isEmpty) {
      showAppToast(context, 'Please describe what happened.',
          icon: Icons.error_outline);
      return;
    }

    setState(() => _busy = true);
    final session = AppSession.instance;
    final IncidentReport report;
    try {
      report = await IncidentStore.instance.file(
        typeKey: _type.key,
        complainant: _complainant.text.trim(),
        narration: _narration.text.trim(),
        contact: _contact.text.trim(),
        respondent: _type.interpersonal ? _respondent.text.trim() : '',
        witnesses: _type.interpersonal ? _witnesses.text.trim() : '',
        location: 'Pinned on GIS map',
        mapPoint: _pickedPoint,
        complainantId: session.residentId,
        accountId: session.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'BLOTTER_SUBMIT',
      'Blotter/incident report filed (Case No: ${report.caseNo})',
      category: AuditCategory.concern,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppToast(context, 'Report filed — Case No. ${report.caseNo}',
        icon: Icons.campaign_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final dateTimeLabel =
        '${loc.formatMediumDate(_now)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(_now))}';

    return Scaffold(
      appBar: AppBar(title: const Text('File an Incident / Concern')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const AlertBanner(
            kind: AlertKind.warning,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'For life-threatening emergencies, call '),
              TextSpan(
                  text: '911',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' or the local police at '),
              TextSpan(
                  text: '(043) 702-4011',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' immediately.'),
            ])),
          ),
          AppDropdown<IncidentType>(
            label: 'Incident Type',
            value: _type,
            items: kIncidentTypes,
            itemLabel: (t) => t.label,
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          AppTextField(
            label: 'Date & Time of Incident',
            readOnly: true,
            hint: dateTimeLabel,
          ),
          const FieldLabel('Location of Incident'),
          Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: GisMapView(
              showReportPins: false,
              onPick: (p) => setState(() => _pickedPoint = p),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.md),
            child: Text(
              _pickedPoint == null
                  ? 'Tap the map to drop a pin where it happened.'
                  : 'Location pinned. Tap elsewhere on the map to move it.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _pickedPoint == null
                        ? AppColors.inkMuted
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          AppTextField(
            label: 'Complainant Full Name',
            controller: _complainant,
            readOnly: _knownReporter,
            hint: 'Your full name',
            helper:
                _knownReporter ? 'Auto-filled from your resident record' : null,
          ),
          AppTextField(
            label: 'Contact Number',
            controller: _contact,
            keyboardType: TextInputType.phone,
            hint: '09XXXXXXXXX',
          ),
          if (_type.interpersonal)
            AppTextField(
              label: 'Respondent / Subject (if known)',
              controller: _respondent,
              hint: 'Name or description of the other party (optional)',
            ),
          AppTextField(
            label: 'Detailed Narration of Incident',
            controller: _narration,
            maxLines: 5,
            hint: 'Describe what happened — sequence of events, persons '
                'involved, and any details...',
          ),
          if (_type.interpersonal)
            AppTextField(
              label: 'Witness Names (optional)',
              controller: _witnesses,
              hint: 'e.g. Maria Cruz, Jose Reyes',
            ),
          const AlertBanner(
            kind: AlertKind.info,
            child: Text('Your report will be assigned a case number and '
                'reviewed by a barangay official within 24 hours.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.flagRed,
              foregroundColor: Colors.white,
            ),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: const Text('Submit Report'),
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
