import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/paginator.dart';
import 'mis_widgets.dart';
import 'resident_form_screen.dart';

/// Account Claiming module (js/pages/accounts.js) — the review queue for
/// account applications.
///
/// A resident applies with their details, a valid ID and a selfie holding it
/// (claim_account_screen.dart); nothing is an account until someone here
/// approves it: Connect to an existing record, Add a resident record for an
/// applicant who is not on file, or Deny with a reason. The server
/// (routes/account-applications.js) checks the Role Access Matrix row
/// "Approve account applications" itself.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

String _accountQuery() => 'account_id=${AppSession.instance.accountId ?? ''}';

String _fmtDate(dynamic iso, {bool time = false}) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final base = '${months[d.month - 1]} ${d.day}, ${d.year}';
  if (!time) return base;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = '${d.minute}'.padLeft(2, '0');
  return '$base, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _age(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  if (d == null) return '—';
  final h = DateTime.now().difference(d).inHours;
  if (h < 1) return 'under an hour';
  if (h < 48) return '$h hour${h == 1 ? '' : 's'}';
  final days = h ~/ 24;
  return '$days day${days == 1 ? '' : 's'}';
}

class _AccountsPageState extends State<AccountsPage> {
  String _tab = 'pending'; // pending | decided
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _stats = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiClient.instance.get(
              '/api/account-applications?status=$_tab&${_accountQuery()}')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items = (r['items'] as List).cast<Map<String, dynamic>>();
        _stats = (r['stats'] as Map<String, dynamic>?) ?? const {};
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(String ref) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ApplicationReviewScreen(reference: ref)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final oldest = _stats['oldest_pending_at'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const MisPageHeader(
            title: 'Account Claiming',
            desc: 'Review account applications — check the ID, then connect '
                'the applicant to their barangay record',
          ),
          KpiGrid(cards: [
            KpiCard(
                label: 'Pending Review',
                value: '${_stats['pending'] ?? '—'}',
                trend: oldest == null
                    ? 'Nothing waiting'
                    : 'Oldest waiting ${_age(oldest)}',
                accent: KpiAccent.warning),
            KpiCard(
                label: 'Approved (30 days)',
                value: '${_stats['approved_30d'] ?? '—'}',
                accent: KpiAccent.success),
            KpiCard(
                label: 'Not Approved (30 days)',
                value: '${_stats['denied_30d'] ?? '—'}',
                accent: KpiAccent.danger),
            KpiCard(
                label: 'Resident Accounts',
                value: '${_stats['resident_accounts'] ?? '—'}'),
          ]),
          MisCard(
            title: 'Applications',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'decided', label: Text('Decided')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) {
                    setState(() => _tab = s.first);
                    _load();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold)),
                  )
                else if (_error != null)
                  AlertBanner(kind: AlertKind.danger, child: Text(_error!))
                else if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                        _tab == 'pending'
                            ? 'No applications are waiting for review.'
                            : 'No decided applications yet.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.inkMuted)),
                  )
                else
                  PaginatedColumn<Map<String, dynamic>>(
                    items: _items,
                    itemLabel: 'application',
                    itemBuilder: (context, a) => _row(context, a),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> a) {
    final text = Theme.of(context).textTheme;
    final status = a['status'] as String;
    final badge = status == 'pending'
        ? const StatusBadge('Pending', kind: BadgeKind.warning)
        : status == 'approved'
            ? StatusBadge(a['outcome'] == 'created' ? 'Approved · new record' : 'Approved',
                kind: BadgeKind.success)
            : const StatusBadge('Not approved', kind: BadgeKind.danger);
    return InkWell(
      onTap: () => _open(a['ref'] as String),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${a['ref']}',
                    style: text.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
              ),
              badge,
            ]),
            const SizedBox(height: 4),
            Text('${a['name']}',
                style: text.titleSmall?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w700)),
            Text(
                '${a['email']} · ${a['purok'] ?? 'no purok'} · ${a['id_type']}',
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
            Text(
                status == 'pending'
                    ? 'Submitted ${_fmtDate(a['submitted_at'], time: true)}'
                    : 'Decided ${_fmtDate(a['reviewed_at'], time: true)}'
                        '${a['reviewed_by_name'] != null ? ' by ${a['reviewed_by_name']}' : ''}',
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
            if (status == 'denied' && a['decision_reason'] != null)
              Text('Reason: ${a['decision_reason']}',
                  style: text.bodySmall?.copyWith(color: AppColors.flagRed)),
          ],
        ),
      ),
    );
  }
}

/// One application: the applicant's details, their ID photos, and the
/// barangay records it could belong to — shown to the reviewer only.
/// Pops `true` when a decision was made.
class ApplicationReviewScreen extends StatefulWidget {
  const ApplicationReviewScreen({super.key, required this.reference});
  final String reference;

  @override
  State<ApplicationReviewScreen> createState() =>
      _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  Map<String, dynamic>? _app;
  List<Map<String, dynamic>> _files = const [];
  List<Map<String, dynamic>> _candidates = const [];
  final Map<String, String> _photos = {}; // kind → data URL
  String? _error;
  bool _busy = false;
  bool _replaceContact = false;

  static const _fileLabels = {
    'id_front': 'ID — front',
    'id_back': 'ID — back',
    'selfie': 'Selfie holding the ID',
  };

  String get _ref => Uri.encodeComponent(widget.reference);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.instance
              .get('/api/account-applications/$_ref?${_accountQuery()}')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _app = r['application'] as Map<String, dynamic>;
        _files = (r['files'] as List).cast<Map<String, dynamic>>();
        _candidates = (r['candidates'] as List).cast<Map<String, dynamic>>();
        _error = null;
      });
      for (final f in _files.where((f) => f['available'] == true)) {
        final kind = f['kind'] as String;
        try {
          final img = await ApiClient.instance.get(
                  '/api/account-applications/$_ref/files/$kind?${_accountQuery()}')
              as Map<String, dynamic>;
          if (mounted) setState(() => _photos[kind] = img['data_url'] as String);
        } catch (_) {/* the tile says it could not load */}
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _pending => _app?['status'] == 'pending';

  bool get _canCreateRecord {
    final role = AppSession.instance.serverRole;
    if (role == 'Admin') return true;
    return ModuleAccess.instance
        .can(role.toLowerCase(), 'residency', fallback: role == 'Officer');
  }

  Future<void> _decide(Future<void> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      showAppToast(context, done, icon: Icons.check_circle_outline);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, e.message, icon: Icons.error_outline);
      }
    }
  }

  Future<void> _connect(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Connect and approve?'),
        content: Text(
            '${_app!['email']} becomes the online account of ${c['full_name']} '
            '(#${c['resident_id']}) and can sign in straight away.\n\n'
            'Only do this if the ID and the selfie show the same person, and '
            'the ID matches this record.'
            '${_replaceContact ? '\n\nThe record\'s number becomes ${_app!['mobile_local']}.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Connect & Approve')),
        ],
      ),
    );
    if (ok != true) return;
    await _decide(
      () => ApiClient.instance.post('/api/account-applications/$_ref/connect', {
        'account_id': AppSession.instance.accountId,
        'resident_id': c['resident_id'],
        'replace_contact': _replaceContact,
      }),
      '${widget.reference} approved — account connected',
    );
  }

  Future<String?> _askReason(
      {required String title,
      required String message,
      required String hint,
      required String confirm}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: InputDecoration(hintText: hint, filled: true),
                onChanged: (_) => setD(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
                onPressed: ctrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(d, ctrl.text.trim()),
                child: Text(confirm)),
          ],
        ),
      ),
    );
  }

  Future<void> _deny() async {
    final reason = await _askReason(
      title: 'Deny this application?',
      message: 'The applicant is told this reason when they try to sign in, '
          'so write it for them.',
      hint: 'e.g. The ID photo is too blurry to read. Please apply again.',
      confirm: 'Deny',
    );
    if (reason == null) return;
    await _decide(
      () => ApiClient.instance.post('/api/account-applications/$_ref/deny', {
        'account_id': AppSession.instance.accountId,
        'reason': reason,
      }),
      '${widget.reference} not approved',
    );
  }

  // "Release claim": archive the account holding the record (the ordinary
  // account delete, with a reason). Its row and history stay; restoring it
  // is refused while the real owner's account is live.
  Future<void> _release(Map<String, dynamic> c) async {
    final reason = await _askReason(
      title: 'Release this claim?',
      message: '${c['claimed_email']} is archived: it can no longer sign in, '
          'and the record becomes free to connect to this application.',
      hint: 'e.g. The resident presented her PhilSys ID in person; the earlier '
          'account is not hers.',
      confirm: 'Release Claim',
    );
    if (reason == null) return;
    try {
      await ApiClient.instance.delete(
          '/api/accounts/${c['claimed_account_id']}?${_accountQuery()}'
          '&reason=${Uri.encodeComponent('Claim released: $reason')}');
      if (!mounted) return;
      showAppToast(context, 'Claim released — ${c['claimed_email']} archived',
          icon: Icons.lock_outline);
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, icon: Icons.error_outline);
    }
  }

  Future<void> _createRecord() async {
    final a = _app!;
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ResidentFormScreen(
        title: 'New Resident Record',
        submitLabel: 'Create Record & Approve',
        prefill: {
          'last_name': a['last_name'],
          'first_name': a['first_name'],
          'middle_name': a['middle_name'],
          'suffix': a['suffix'],
          'birthdate': a['birthdate'],
          'sex': a['sex'],
          'purok_id': a['purok_id'],
          'address_text': a['address_text'],
          'contact_no': a['mobile_local'],
        },
        onSubmit: (body) async {
          await ApiClient.instance
              .post('/api/account-applications/$_ref/create-resident', {
            'account_id': AppSession.instance.accountId,
            'resident': body,
          });
        },
      ),
    ));
    if (done == true && mounted) {
      showAppToast(context, '${widget.reference} approved — record created',
          icon: Icons.check_circle_outline);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = _app;
    return Scaffold(
      appBar: AppBar(title: Text(widget.reference)),
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: AlertBanner(kind: AlertKind.danger, child: Text(_error!)),
            )
          : a == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                      AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
                  children: [
                    if (!_pending)
                      AlertBanner(
                        kind: a['status'] == 'approved'
                            ? AlertKind.success
                            : AlertKind.warning,
                        child: Text(a['status'] == 'approved'
                            ? 'Approved — ${a['outcome'] == 'created' ? 'a new resident record was created' : 'connected to an existing record'} (resident #${a['resident_id']}). ${a['reviewed_by_name'] ?? ''} · ${_fmtDate(a['reviewed_at'], time: true)}'
                            : 'Not approved: ${a['decision_reason']}. ${a['reviewed_by_name'] ?? ''} · ${_fmtDate(a['reviewed_at'], time: true)}'),
                      ),
                    MisCard(
                      title: 'Applicant',
                      child: Column(children: [
                        _kv('Name', a['name']),
                        _kv('Date of birth', a['birthdate']),
                        _kv('Sex', a['sex'] == 'M' ? 'Male' : a['sex'] == 'F' ? 'Female' : null),
                        _kv('Purok', a['purok']),
                        _kv('Address', a['address_text']),
                        _kv('Mobile', '${a['mobile_local']}${a['mobile_confirmed_at'] != null ? ' (confirmed by code)' : ''}'),
                        _kv('Email', a['email']),
                        _kv('ID presented', a['id_type']),
                        _kv('Submitted', _fmtDate(a['submitted_at'], time: true)),
                      ]),
                    ),
                    MisCard(
                      title: 'ID and selfie',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final f in _files) _photoTile(f),
                          Text(
                            'Compare the face in the selfie with the ID photo, '
                            'and the name and birthdate on the ID with the form.',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    MisCard(
                      title: 'Barangay records this could be',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Shown to you only — the applicant is never told '
                            'whether a record was found. Nothing is linked '
                            'until you choose.',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                          if (_pending && _candidates.any((c) => c['claimed'] != true))
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _replaceContact,
                              onChanged: (v) =>
                                  setState(() => _replaceContact = v),
                              title: Text(
                                  'When connecting, replace the number on file '
                                  'with ${a['mobile_local']}',
                                  style: text.bodySmall),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_candidates.isEmpty)
                            Text(
                              'No barangay record matches this name and '
                              'birthdate.${_pending ? ' If the applicant lives in the barangay, add a record for them.' : ''}',
                              style: text.bodySmall,
                            ),
                          for (final c in _candidates) _candidate(c),
                        ],
                      ),
                    ),
                    if (_pending) ...[
                      if (_canCreateRecord)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              side: const BorderSide(color: AppColors.navy)),
                          onPressed: _busy ? null : _createRecord,
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Add resident record'),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.flagRed,
                            side: const BorderSide(color: AppColors.flagRed)),
                        onPressed: _busy ? null : _deny,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Deny'),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _kv(String label, dynamic value) {
    final text = Theme.of(context).textTheme;
    final v = value?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted))),
          Expanded(
              child: Text(v == null || v.isEmpty ? '—' : v,
                  style: text.bodyMedium?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _photoTile(Map<String, dynamic> f) {
    final text = Theme.of(context).textTheme;
    final kind = f['kind'] as String;
    final data = _photos[kind];
    final bytes = data == null ? null : base64Decode(data.substring(data.indexOf(',') + 1));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_fileLabels[kind] ?? kind,
              style: text.labelMedium?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: f['available'] != true
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: AppColors.cream,
                    child: Text(
                        'Deleted ${_fmtDate(f['purged_at'])} — kept 30 days after the decision',
                        style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
                  )
                : bytes == null
                    ? Container(
                        height: 160,
                        color: AppColors.cream,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold)),
                      )
                    : InteractiveViewer(
                        maxScale: 5,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _candidate(Map<String, dynamic> c) {
    final text = Theme.of(context).textTheme;
    final why = [
      c['same_birthdate'] == true ? 'same birthdate' : 'different birthdate',
      c['same_last'] == true ? 'same surname' : 'different surname',
      c['same_first'] == true ? 'same first name' : 'different first name',
    ].join(' · ');
    final claimed = c['claimed'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${c['full_name']}  #${c['resident_id']}',
              style: text.titleSmall?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w700)),
          Text(
              '${c['birthdate'] ?? 'no birthdate'} · ${c['purok'] ?? 'no purok'}'
              '${c['household'] != null ? ' · ${c['household']}' : ''}',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          Text(why, style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Number on file: ${c['contact_no'] ?? 'none'}',
                  style: text.bodySmall),
              if (c['mobile_matches'] == true)
                const StatusBadge('matches the applicant\'s mobile',
                    kind: BadgeKind.success)
              else if (c['contact_no'] != null)
                const StatusBadge('differs from the applicant\'s',
                    kind: BadgeKind.gray),
            ],
          ),
          if (claimed) ...[
            const SizedBox(height: AppSpacing.sm),
            AlertBanner(
              kind: AlertKind.warning,
              child: Text(
                  'Already claimed by ${c['claimed_email']} since '
                  '${_fmtDate(c['claimed_since'])}. Either this applicant or '
                  'that account holder is not who they say. Release the claim '
                  'only once you are sure it is not theirs.'),
            ),
          ],
          if (_pending) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: claimed
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.flagRed,
                          side: const BorderSide(color: AppColors.flagRed)),
                      onPressed: _busy ? null : () => _release(c),
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Release claim'),
                    )
                  : FilledButton.icon(
                      onPressed: _busy ? null : () => _connect(c),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Connect to this record'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
