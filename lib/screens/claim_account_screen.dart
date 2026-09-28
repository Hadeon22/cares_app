import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/api_client.dart';
import '../widgets/app_toast.dart';
import '../widgets/common.dart';
import '../widgets/form_widgets.dart';

/// Apply for an Account — mobile version of claim-account.html
/// (js/account-application.js on the web).
///
/// A resident sends their details, a photo of a valid ID and a selfie holding
/// it; a barangay official approves it on the MIS Account Claiming page, and
/// only then does the account exist. It replaced the old claim, which needed
/// only a name and a birthdate — two facts anyone could know.
///
/// Nothing is sent until Submit: then the draft, the photos and the submit go
/// in one run (routes/account-applications.js). The screen never says whether
/// a barangay record was found — that is for the reviewer only.
class ClaimAccountScreen extends StatefulWidget {
  const ClaimAccountScreen({super.key});

  @override
  State<ClaimAccountScreen> createState() => _ClaimAccountScreenState();
}

class _ClaimAccountScreenState extends State<ClaimAccountScreen> {
  int _step = 1;
  bool _busy = false;
  String _busyLabel = '';

  final _fname = TextEditingController();
  final _mname = TextEditingController();
  final _lname = TextEditingController();
  final _suffix = TextEditingController();
  final _address = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  DateTime? _dob;
  String? _sex;
  int? _purokId;
  String? _idType;
  bool _consent = false;

  // The two lists the form needs, from the server.
  List<Map<String, dynamic>> _puroks = const [];
  List<String> _idTypes = const [];

  // kind → data URL
  final Map<String, String?> _photos = {
    'id_front': null,
    'id_back': null,
    'selfie': null,
  };

  // Set once the draft exists, so a retry after a failed upload reuses it.
  String? _ref;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final p = await ApiClient.instance.get('/api/puroks') as List;
      final t = await ApiClient.instance
          .get('/api/account-applications/id-types') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _puroks = p.cast<Map<String, dynamic>>();
        _idTypes = (t['id_types'] as List).cast<String>();
      });
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, icon: Icons.error_outline);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fname, _mname, _lname, _suffix, _address, _mobile, _email, _pass, _pass2
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _dobIso() {
    final d = _dob!;
    String p(int n) => '$n'.padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  void _say(String message) =>
      showAppToast(context, message, icon: Icons.error_outline);

  bool _checkDetails() {
    if (_fname.text.trim().isEmpty || _lname.text.trim().isEmpty) {
      _say('Please enter your first and last name.');
      return false;
    }
    if (_dob == null) {
      _say('Please enter your date of birth.');
      return false;
    }
    final digits = _mobile.text.replaceAll(RegExp(r'[^\d+]'), '');
    if (!RegExp(r'^(?:\+?63|0)?9\d{9}$').hasMatch(digits)) {
      _say('Enter a mobile number like 0917 123 4567.');
      return false;
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())) {
      _say('Enter a valid email address.');
      return false;
    }
    if (_pass.text.length < 8) {
      _say('Password must be at least 8 characters.');
      return false;
    }
    if (_pass.text != _pass2.text) {
      _say('Passwords do not match.');
      return false;
    }
    return true;
  }

  bool _checkId() {
    if (_idType == null) {
      _say('Choose the kind of ID you are using.');
      return false;
    }
    if (_photos['id_front'] == null) {
      _say('Add a photo of the front of your ID.');
      return false;
    }
    if (_photos['selfie'] == null) {
      _say('Add a selfie of you holding the same ID.');
      return false;
    }
    if (!_consent) {
      _say('Please agree to the ID check notice.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (_token == null) {
        setState(() => _busyLabel = 'Sending your details…');
        final res = await ApiClient.instance.post('/api/account-applications', {
          'email': _email.text.trim().toLowerCase(),
          'password': _pass.text,
          'first_name': _fname.text.trim(),
          'middle_name': _mname.text.trim().isEmpty ? null : _mname.text.trim(),
          'last_name': _lname.text.trim(),
          'suffix': _suffix.text.trim().isEmpty ? null : _suffix.text.trim(),
          'birthdate': _dobIso(),
          'sex': _sex,
          'purok_id': _purokId,
          'address_text':
              _address.text.trim().isEmpty ? null : _address.text.trim(),
          'mobile_no': _mobile.text.trim(),
          'id_type': _idType,
          'consent': true,
        }) as Map<String, dynamic>;
        _ref = res['ref'] as String;
        _token = res['token'] as String;
      }
      final kinds = _photos.keys.where((k) => _photos[k] != null).toList();
      for (var i = 0; i < kinds.length; i++) {
        setState(() => _busyLabel = 'Uploading photo ${i + 1} of ${kinds.length}…');
        await ApiClient.instance.post(
            '/api/account-applications/${Uri.encodeComponent(_ref!)}/files', {
          'token': _token,
          'kind': kinds[i],
          'data_url': _photos[kinds[i]],
        });
      }
      setState(() => _busyLabel = 'Submitting…');
      await ApiClient.instance.post(
          '/api/account-applications/${Uri.encodeComponent(_ref!)}/submit',
          {'token': _token});
      if (!mounted) return;
      setState(() => _step = 3);
      showAppToast(context, 'Application received — Ref $_ref',
          icon: Icons.check_circle_outline);
    } on ApiException catch (e) {
      // Details the server refused send the resident back to fix them; a
      // failed upload stays here so it can simply be retried.
      if (_token == null && !RegExp('ID|photo|consent').hasMatch(e.message)) {
        setState(() => _step = 1);
      }
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 1) {
      if (_checkDetails()) setState(() => _step = 2);
    } else if (_step == 2) {
      if (_checkId()) await _submit();
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // Large enough to read an ID number; a 12-MP photo comes down to a few
  // hundred KB, well under the server's 3 MB cap.
  Future<void> _pickPhoto(String kind, ImageSource source) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        preferredCameraDevice:
            kind == 'selfie' ? CameraDevice.front : CameraDevice.rear,
      );
    } catch (e) {
      if (mounted) _say('Could not open the camera or gallery: $e');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photos[kind] = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  void _photoOptions(String kind) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: AppColors.navy),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pickPhoto(kind, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.navy),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pickPhoto(kind, ImageSource.gallery);
              },
            ),
            if (_photos[kind] != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.flagRed),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppColors.flagRed)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  setState(() => _photos[kind] = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        title: const Text('Apply for an Account'),
        backgroundColor: AppColors.navyDeep,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyDeep, AppColors.navy, AppColors.navyLight],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SealBadge(size: 64)),
                const SizedBox(height: AppSpacing.md),
                Text('Apply for an Account',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  'Your C.A.R.E.S. resident account, checked against a valid '
                  'ID by a barangay official before it is opened.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                _stepIndicator(),
                const SizedBox(height: AppSpacing.lg),
                if (_step == 1) ..._buildDetails(),
                if (_step == 2) ..._buildId(),
                if (_step == 3) ..._buildDone(),
                const SizedBox(height: AppSpacing.md),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step indicator (1 ─ 2 ─ 3 with labels) ─────────────────
  Widget _stepIndicator() {
    const labels = ['Your Details', 'Valid ID', 'Submitted'];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              _stepDot(i),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 3,
                    color:
                        _step > i ? const Color(0xFF22C55E) : AppColors.divider,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 2
                          ? TextAlign.right
                          : TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            _step >= i + 1 ? AppColors.ink : AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepDot(int step) {
    final done = _step > step;
    final active = _step == step;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? const Color(0xFF22C55E)
            : active
                ? AppColors.navy
                : AppColors.divider,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.inkMuted,
                ),
              ),
      ),
    );
  }

  TextStyle? get _help => Theme.of(context)
      .textTheme
      .bodySmall
      ?.copyWith(color: AppColors.inkMuted, height: 1.5);

  // ── Step 1: details ───────────────────────────────────────
  List<Widget> _buildDetails() {
    return [
      Text(
        'A barangay official checks your ID and links the account to your '
        'barangay record — or makes one for you if you are not registered yet.',
        style: _help,
      ),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(
            child: AppTextField(
                label: 'First Name', controller: _fname, hint: 'Juan')),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
            child: AppTextField(
                label: 'Middle Name', controller: _mname, hint: 'Optional')),
      ]),
      Row(children: [
        Expanded(
            child: AppTextField(
                label: 'Last Name', controller: _lname, hint: 'Santos')),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
            child: AppTextField(
                label: 'Suffix', controller: _suffix, hint: 'Jr., III')),
      ]),
      AppTextField(
        label: 'Date of Birth',
        readOnly: true,
        hint: _dob == null
            ? 'Tap to select'
            : MaterialLocalizations.of(context).formatMediumDate(_dob!),
        onTap: _pickDob,
      ),
      AppDropdown<String>(
        label: 'Sex',
        value: _sex,
        items: const ['M', 'F'],
        itemLabel: (s) => s == 'M' ? 'Male' : 'Female',
        onChanged: (v) => setState(() => _sex = v),
      ),
      if (_puroks.isNotEmpty)
        AppDropdown<int>(
          label: 'Purok',
          value: _purokId,
          items: [for (final p in _puroks) p['purok_id'] as int],
          itemLabel: (id) =>
              '${_puroks.firstWhere((p) => p['purok_id'] == id)['name']}',
          onChanged: (v) => setState(() => _purokId = v),
        ),
      AppTextField(
          label: 'House No. / Street', controller: _address, hint: 'Optional'),
      AppTextField(
        label: 'Mobile Number',
        controller: _mobile,
        hint: '09XX XXX XXXX',
        keyboardType: TextInputType.phone,
        helper: 'The barangay contacts you on it about this application.',
      ),
      AppTextField(
        label: 'Email Address',
        controller: _email,
        hint: 'your@email.com',
        keyboardType: TextInputType.emailAddress,
        helper: 'You will sign in with this email.',
      ),
      AppTextField(
        label: 'Password',
        controller: _pass,
        hint: 'At least 8 characters',
        obscureText: true,
      ),
      AppTextField(
        label: 'Confirm Password',
        controller: _pass2,
        hint: 'Re-enter password',
        obscureText: true,
      ),
    ];
  }

  // ── Step 2: valid ID ──────────────────────────────────────
  List<Widget> _buildId() {
    return [
      Text(
        'Take clear photos in good light, with every corner of the ID in the '
        'picture. The selfie shows the official that the person holding the '
        'ID is the person on it.',
        style: _help,
      ),
      const SizedBox(height: AppSpacing.md),
      if (_idTypes.isNotEmpty)
        AppDropdown<String>(
          label: 'Kind of ID',
          value: _idType,
          items: _idTypes,
          onChanged: (v) => setState(() => _idType = v),
        ),
      _photoTile('id_front', 'Front of the ID', required: true),
      _photoTile('id_back', 'Back of the ID (if it has details)'),
      _photoTile('selfie', 'Selfie holding the ID', required: true),
      const SizedBox(height: AppSpacing.sm),
      InkWell(
        onTap: () => setState(() => _consent = !_consent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'I agree that Barangay Conde Labac may use these photos only '
                  'to confirm who I am for this application. They are seen only '
                  'by the officials who review it and are deleted 30 days after '
                  'the decision (Data Privacy Act of 2012, RA 10173).',
                  style: _help,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _photoTile(String kind, String label, {bool required = false}) {
    final bytes = _photos[kind] == null
        ? null
        : base64Decode(_photos[kind]!.substring(_photos[kind]!.indexOf(',') + 1));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: _busy ? null : () => _photoOptions(kind),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
                color: bytes == null ? AppColors.divider : AppColors.gold),
          ),
          child: Row(
            children: [
              Container(
                width: 120,
                height: 92,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadii.md)),
                  color: AppColors.divider.withValues(alpha: 0.4),
                ),
                child: bytes == null
                    ? Icon(Icons.photo_camera_outlined,
                        color: AppColors.inkMuted)
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        bytes != null
                            ? 'Tap to change'
                            : required
                                ? 'Required — tap to add'
                                : 'Optional — tap to add',
                        style: _help),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 3: submitted ─────────────────────────────────────
  List<Widget> _buildDone() {
    final text = Theme.of(context).textTheme;
    return [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 34),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Application Received',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(color: AppColors.ink)),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'A barangay official will check your ID. You can sign in with your '
        'email and password once your application is approved. If you are '
        'asked to visit the barangay hall, bring the same ID.',
        textAlign: TextAlign.center,
        style: _help,
      ),
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text('REFERENCE NUMBER',
                style: text.labelSmall?.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(_ref ?? '—',
                style: text.titleLarge?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ];
  }

  Widget _footer() {
    if (_step == 3) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Done'),
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        TextButton(
          onPressed: _busy
              ? null
              : () => _step == 2
                  ? setState(() => _step = 1)
                  : Navigator.of(context).pop(),
          child: Text(_step == 2 ? 'Back' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _next,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_step == 1 ? Icons.arrow_forward : Icons.check, size: 18),
          label: Text(_busy
              ? _busyLabel
              : _step == 1
                  ? 'Next'
                  : 'Submit Application'),
        ),
      ],
    );
  }
}
