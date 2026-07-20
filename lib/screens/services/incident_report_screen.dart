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
        reporterRole: session.serverRole,
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
    if (report.caseNo == kPendingSyncRef) {
      showAppToast(
          context,
          "You're offline — report saved and will be filed automatically "
          'once you reconnect.',
          icon: Icons.cloud_upload_outlined);
    } else {
      showAppToast(context, 'Report filed — Case No. ${report.caseNo}',
          icon: Icons.campaign_outlined);
    }
  }

  /// Opens the full-screen location picker and, if the user confirms a spot,
  /// stores it. The picker fills the screen, so its map has no scroll to
  /// fight — panning and zooming are fully responsive there.
  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<Offset>(
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(initial: _pickedPoint),
      ),
    );
    if (result != null && mounted) setState(() => _pickedPoint = result);
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
          // A non-interactive PREVIEW of the chosen spot. Because it sits in
          // the middle of this scrolling form, letting its InteractiveViewer
          // grab drags would fight the form's own scroll (the pan-unresponsive
          // bug). So the preview ignores pointers — the form scrolls cleanly
          // over it — and a tap opens a full-screen picker where panning and
          // zooming have no scroll to compete with.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openLocationPicker,
            child: Container(
              height: 300,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.divider),
              ),
              child: Stack(
                children: [
                  // ValueKey re-seeds the preview whenever the pin moves so it
                  // always reflects the current choice.
                  IgnorePointer(
                    child: GisMapView(
                      key: ValueKey(_pickedPoint),
                      showReportPins: false,
                      initialPick: _pickedPoint,
                      focusPoint: _pickedPoint,
                    ),
                  ),
                  // "Tap to open" affordance so the preview reads as a button.
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Material(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_full,
                                size: 15, color: AppColors.navy),
                            const SizedBox(width: 5),
                            Text(
                              _pickedPoint == null
                                  ? 'Tap to set location'
                                  : 'Tap to adjust',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.md),
            child: Text(
              _pickedPoint == null
                  ? 'Tap the map to open it, then drop a pin where it happened.'
                  : 'Location pinned. Tap the map to pan, zoom, or move the pin.',
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
            child: Text('Your report will be reviewed by a barangay official '
                'within 24 hours. You will receive a phone notification '
                'with any updates.'),
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

/// Full-screen pin picker for the incident location. The map fills the page,
/// so its InteractiveViewer owns every gesture — panning and zooming are
/// reliable here in a way they can't be for a small map embedded in a form.
/// Returns the chosen normalized point via [Navigator.pop], or nothing on
/// cancel.
class _LocationPickerScreen extends StatefulWidget {
  const _LocationPickerScreen({this.initial});

  final Offset? initial;

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  late Offset? _point = widget.initial;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pin the Location')),
      body: Column(
        children: [
          Expanded(
            child: GisMapView(
              showReportPins: false,
              initialPick: widget.initial,
              focusPoint: widget.initial,
              onPick: (p) => setState(() => _point = p),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _point == null
                          ? 'Pinch to zoom, drag to pan, then tap to drop the '
                              'pin where it happened.'
                          : 'Location pinned. Tap elsewhere to move it.',
                      style: text.labelSmall?.copyWith(
                        color: _point == null
                            ? AppColors.inkMuted
                            : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _point == null
                        ? null
                        : () => Navigator.of(context).pop(_point),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Use location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
