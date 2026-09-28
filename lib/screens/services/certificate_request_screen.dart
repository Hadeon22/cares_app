import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/resident_profile.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/certificate_requirements.dart';
import '../../widgets/form_widgets.dart';

/// Certificate Issuance — request form. Mobile version of the web's
/// modal-certificates: type picker grid, applicant details, purpose,
/// contact and pickup date.
class CertificateRequestScreen extends StatefulWidget {
  const CertificateRequestScreen({super.key});

  @override
  State<CertificateRequestScreen> createState() =>
      _CertificateRequestScreenState();
}

class _CertificateRequestScreenState extends State<CertificateRequestScreen> {
  CertificateType _selected = kCertificateTypes.first;
  final _fname = TextEditingController();
  final _lname = TextEditingController();
  final _purpose = TextEditingController();
  final _contact = TextEditingController();
  DateTime? _dob;
  DateTime? _pickup;
  String _purok = kPuroks.first;

  /// Requirement key → the photo chosen for it, held until the request is
  /// filed (an attachment needs a request to belong to).
  final Map<String, PendingRequirement> _docs = {};

  @override
  void initState() {
    super.initState();
    _prefillFromRecord();
  }

  /// Auto-fill the applicant details from the signed-in resident's record
  /// (same data the web View-Resident modal shows). Best-effort: the form
  /// still works untouched when offline or signed in as staff.
  Future<void> _prefillFromRecord() async {
    final residentId = AppSession.instance.residentId;
    if (residentId == null) return;
    final ResidentProfile r;
    try {
      r = await ResidentProfile.fetch(residentId);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_fname.text.isEmpty) _fname.text = r.firstName;
      if (_lname.text.isEmpty) _lname.text = r.lastName;
      _dob ??= r.birthdate;
      if (_contact.text.isEmpty && (r.contactNo ?? '').isNotEmpty) {
        _contact.text = r.contactNo!;
      }
      // DB purok is "Purok 1"; the dropdown entries are "Purok 1 – Sitio …".
      if (r.purok != null) {
        _purok = kPuroks.firstWhere((p) => p.startsWith(r.purok!),
            orElse: () => _purok);
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_fname, _lname, _purpose, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isDob) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? DateTime(2000) : now,
      firstDate: isDob ? DateTime(1920) : now,
      lastDate: isDob ? now : now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => isDob ? _dob = picked : _pickup = picked);
    }
  }

  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    if (_fname.text.trim().isEmpty || _lname.text.trim().isEmpty) {
      showAppToast(context, 'Please enter your first and last name.',
          icon: Icons.error_outline);
      return;
    }
    // Extra details ride along in `purpose` — the certificate table keeps a
    // single free-text purpose column (matches the web flow).
    final extras = [
      if (_purpose.text.trim().isNotEmpty) _purpose.text.trim(),
      if (_contact.text.trim().isNotEmpty) 'Contact: ${_contact.text.trim()}',
      if (_pickup != null)
        'Preferred pickup: '
            '${MaterialLocalizations.of(context).formatMediumDate(_pickup!)}',
      'Address: $_purok',
    ].join(' · ');

    // Missing requirements are a warning, not a wall: a walk-in can still
    // bring the paper to the hall, and the barangay would rather have the
    // request in the queue than turned away at the form.
    final missing = missingRequirements(_selected, _docs);
    if (missing.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit without these?'),
          content: Text(
            'These requirements have no photo attached:\n\n'
            '${missing.map((m) => "• $m").join("\n")}\n\n'
            'You can still submit and bring them to the barangay hall, but '
            'processing will be faster with them attached.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit anyway'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    setState(() => _busy = true);
    final session = AppSession.instance;
    final CertificateRequest req;
    try {
      req = await CertificateStore.instance.file(
        typeKey: _selected.key,
        applicantName: '${_lname.text.trim()}, ${_fname.text.trim()}',
        purpose: extras,
        residentId: session.residentId,
        accountId: session.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    // Documents can only be attached once the request exists to hold them. A
    // failed upload is reported but never undoes the filing.
    List<String> failedUploads = const [];
    if (req.id > 0 && _docs.isNotEmpty) {
      failedUploads = await uploadPending(req, _docs);
    }

    AuditLog.instance.log(
      'CERT_REQUEST',
      '${_selected.name} requested by ${_fname.text.trim()} '
          '${_lname.text.trim()} (Ref: ${req.requestNo})',
      category: AuditCategory.certificate,
    );
    if (!mounted) return;
    if (failedUploads.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Filed as ${req.requestNo}'),
          content: Text(
            'These documents did not upload:\n\n'
            '${failedUploads.map((m) => "• $m").join("\n")}\n\n'
            'You can bring them to the barangay hall instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop();
    if (req.requestNo == kPendingSyncRef) {
      showAppToast(
          context,
          "You're offline — request saved and will be submitted "
          'automatically once you reconnect.',
          icon: Icons.cloud_upload_outlined);
    } else {
      showAppToast(context,
          '${_selected.name} request submitted! Ref: ${req.requestNo}',
          icon: Icons.description_outlined);
    }
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Tap to select' : MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificate Issuance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const ServiceFlowHeader(
            icon: Icons.description_outlined,
            text: 'Select the certificate type, fill in the required '
                'information, and submit your request. Processing typically '
                'takes 1–3 working days.',
          ),
          AppDropdown<String>(
            label: 'Select Certificate Type',
            value: _selected.key,
            items: [for (final t in kCertificateTypes) t.key],
            itemLabel: (k) => certificateTypeByKey(k).name,
            onChanged: (k) => setState(() {
              if (k == null) return;
              _selected = certificateTypeByKey(k);
              // Each certificate asks for different documents.
              _docs.clear();
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          RequirementPicker(
            type: _selected,
            chosen: _docs,
            onChanged: () => setState(() {}),
          ),
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
            hint: _fmt(_dob),
            onTap: () => _pickDate(true),
          ),
          AppDropdown<String>(
            label: 'Purok / Address',
            value: _purok,
            items: kPuroks,
            onChanged: (v) => setState(() => _purok = v ?? _purok),
          ),
          AppTextField(
            label: 'Purpose / Reason for Request',
            controller: _purpose,
            maxLines: 3,
            hint: 'e.g. For employment purposes, scholarship application, etc.',
          ),
          AppTextField(
            label: 'Contact Number',
            controller: _contact,
            keyboardType: TextInputType.phone,
            hint: '09XXXXXXXXX',
          ),
          AppTextField(
            label: 'Preferred Pickup Date',
            readOnly: true,
            hint: _fmt(_pickup),
            onTap: () => _pickDate(false),
          ),
          const AlertBanner(
            kind: AlertKind.info,
            child: Text('You will receive a phone notification once your '
                'certificate is ready for pickup at the barangay hall.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, size: 18),
            label: const Text('Submit Request'),
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
