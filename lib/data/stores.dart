import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gis/gis_data.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'offline_queue.dart';

/// Sentinel reference number for submissions parked in the [OfflineQueue] —
/// screens show a friendly "will sync later" message when they see it.
const String kPendingSyncRef = 'PENDING-SYNC';

/// ─────────────────────────────────────────────────────────────
/// Shared app stores, backed by the Conde Labac MIS API (the same
/// PostgreSQL database the web system uses). Each store lazy-loads
/// on first use via [ensureLoaded] and exposes loading/error state;
/// widgets listen through ChangeNotifier as before.
/// ─────────────────────────────────────────────────────────────

/// Purok list used across every form (index.html selects).
const List<String> kPuroks = [
  'Purok 1 – Sitio Maliwanag',
  'Purok 2 – Sitio Masagana',
  'Purok 3 – Sitio Malinis',
  'Purok 4 – Sitio Mapayapa',
  'Purok 5 – Sitio Bagong Pag-Asa',
];

const List<String> kResidentCategories = [
  'Senior Citizen',
  'PWD',
  'Solo Parent',
  'Indigent Family',
];

/// The residency UI's "Status" column shows whether the online account has
/// been claimed (same as the web's residency table).
const List<String> kResidentStatuses = ['Active', 'Unclaimed'];

/// classification slugs (DB) → display labels.
const Map<String, String> kClassificationLabels = {
  'senior': 'Senior Citizen',
  'pwd': 'PWD',
  'solo-parent': 'Solo Parent',
  'indigent': 'Indigent Family',
};

/// Shared load-once-then-refresh plumbing for the API-backed stores.
mixin ApiStore on ChangeNotifier {
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  Future<void>? _inflight;

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  @protected
  Future<void> fetch();

  /// Idempotent: triggers the first fetch, no-op afterwards. Safe to call
  /// from build().
  Future<void> ensureLoaded() {
    if (_loaded || _inflight != null) return _inflight ?? Future.value();
    return refresh();
  }

  Future<void> refresh() {
    final task = () async {
      _loading = true;
      _error = null;
      // Schedule instead of notifying inline — refresh() is often kicked
      // off from build(), where a synchronous notify would throw.
      scheduleMicrotask(notifyListeners);
      try {
        await fetch();
        _loaded = true;
      } catch (e) {
        _error = e.toString();
      } finally {
        _loading = false;
        _inflight = null;
        notifyListeners();
      }
    }();
    _inflight = task;
    return task;
  }
}

DateTime _parseTs(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

/// ── Resident directory (GET /api/residents) ─────────────────
class ResidentRecord {
  const ResidentRecord({
    this.id,
    required this.name,
    required this.age,
    required this.purok,
    this.category = '',
    this.cats = const [],
    this.status = 'Active',
  });

  factory ResidentRecord.fromJson(Map<String, dynamic> j) {
    final cats = [
      for (final c in (j['cats'] as List? ?? const []))
        kClassificationLabels[c] ?? c.toString(),
    ];
    return ResidentRecord(
      id: j['id'] as int?,
      name: (j['name'] ?? '') as String,
      age: j['age'] as int?,
      purok: (j['purok'] ?? '—') as String? ?? '—',
      category: cats.isNotEmpty ? cats.first : '',
      cats: cats,
      status: (j['status'] ?? 'Unclaimed') as String,
    );
  }

  final int? id;
  final String name; // "Santos, Pedro J."
  final int? age; // null when no birthdate on file
  final String purok; // "Purok 1"
  final String category; // "" | Senior Citizen | PWD | ...
  final List<String> cats; // all classifications
  final String status; // Active (claimed) | Unclaimed

  String get ageLabel => age == null ? '—' : '$age';

  /// Two-letter avatar initials: first name initial + surname initial.
  String get initials {
    final parts = name.split(',');
    final surname = parts[0].trim();
    final first = parts.length > 1 ? parts[1].trim() : '';
    return '${first.isNotEmpty ? first[0] : '?'}${surname.isNotEmpty ? surname[0] : ''}';
  }
}

class ResidentStore extends ChangeNotifier with ApiStore {
  ResidentStore._();
  static final ResidentStore instance = ResidentStore._();

  final List<ResidentRecord> _records = [];
  List<ResidentRecord> get all => List.unmodifiable(_records);

  int get claimedCount =>
      _records.where((r) => r.status == 'Active').length;
  int countWithCategory(String label) =>
      _records.where((r) => r.cats.contains(label)).length;

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/residents') as List;
    _records
      ..clear()
      ..addAll(rows.map(
          (r) => ResidentRecord.fromJson(r as Map<String, dynamic>)));
  }

  /// Archive a resident (soft delete on the server) and drop it locally.
  Future<void> delete(ResidentRecord r, {int? accountId}) async {
    if (r.id == null) return;
    final path = '/api/residents/${r.id}';
    await ApiClient.instance
        .delete(accountId == null ? path : '$path?account_id=$accountId');
    _records.removeWhere((x) => x.id == r.id);
    notifyListeners();
  }
}

/// ── Certificate types (index.html cert-type-grid) ───────────
class CertificateType {
  const CertificateType(this.key, this.name, this.shortName);

  /// DB slug (certificate.type CHECK constraint).
  final String key;
  final String name;
  final String shortName;
}

const List<CertificateType> kCertificateTypes = [
  CertificateType('barangay-clearance', 'Barangay Clearance',
      'Barangay Clearance'),
  CertificateType('indigency', 'Certificate of Indigency',
      'Certificate of Indigency'),
  CertificateType('residency', 'Certificate of Residency',
      'Certificate of Residency'),
  CertificateType('business-clearance', 'Business Clearance',
      'Business Clearance'),
  CertificateType('good-moral', 'Certificate of Good Moral',
      'Good Moral Certificate'),
  CertificateType('solo-parent', 'Certificate of Solo Parent',
      'Solo Parent Certificate'),
];

CertificateType certificateTypeByKey(String key) =>
    kCertificateTypes.firstWhere((t) => t.key == key,
        orElse: () => kCertificateTypes.first);

/// One certificate request row (certificate table).
class CertificateRequest {
  CertificateRequest({
    required this.id,
    required this.requestNo,
    required this.applicant,
    required this.typeKey,
    required this.createdAt,
    this.purpose = '',
    this.status = 'pending',
    this.residentId,
    this.remarks,
    this.processedByName,
    this.processedAt,
  });

  factory CertificateRequest.fromJson(Map<String, dynamic> j) =>
      CertificateRequest(
        id: j['id'] as int,
        requestNo: (j['request_no'] ?? '') as String,
        applicant: (j['applicant_name'] ?? '') as String,
        typeKey: (j['type'] ?? 'barangay-clearance') as String,
        purpose: (j['purpose'] ?? '') as String? ?? '',
        status: (j['status'] ?? 'pending') as String,
        residentId: j['resident_id'] as int?,
        remarks: j['remarks'] as String?,
        processedByName: j['processed_by_name'] as String?,
        processedAt: j['processed_at'] == null
            ? null
            : _parseTs(j['processed_at']),
        createdAt: _parseTs(j['created_at']),
      );

  final int id;
  final String requestNo;
  final String applicant;
  final String typeKey;
  final String purpose;
  String status; // pending | approved | issued | rejected

  /// Staff note attached when processing (e.g. the reason for a rejection).
  String? remarks;

  /// Who processed it and when — filled in by the server on status changes.
  String? processedByName;
  DateTime? processedAt;

  /// Who filed it — links the row back to a resident's account ("My Requests").
  final int? residentId;
  final DateTime createdAt;

  String get typeLabel => certificateTypeByKey(typeKey).name;
}

class CertificateStore extends ChangeNotifier with ApiStore {
  CertificateStore._();
  static final CertificateStore instance = CertificateStore._();

  final List<CertificateRequest> _requests = [];
  List<CertificateRequest> get all => List.unmodifiable(_requests);

  int byStatus(String status) =>
      _requests.where((r) => r.status == status).length;

  int get filedThisYear {
    final year = DateTime.now().year;
    return _requests.where((r) => r.createdAt.year == year).length;
  }

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/certificates') as List;
    _requests
      ..clear()
      ..addAll(rows.map(
          (r) => CertificateRequest.fromJson(r as Map<String, dynamic>)));
  }

  /// File a new request; returns the created row (with its CERT-… number).
  /// When the server is unreachable the request is parked in the
  /// [OfflineQueue] instead and a [kPendingSyncRef] placeholder comes back —
  /// it will be submitted automatically once the app is back online.
  Future<CertificateRequest> file({
    required String typeKey,
    required String applicantName,
    String purpose = '',
    int? residentId,
    int? accountId,
  }) async {
    final body = {
      'type': typeKey,
      'applicant_name': applicantName,
      if (purpose.isNotEmpty) 'purpose': purpose,
      if (residentId != null) 'resident_id': residentId,
      if (accountId != null) 'account_id': accountId,
    };
    final Map<String, dynamic> res;
    try {
      res = await ApiClient.instance.post('/api/certificates', body)
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode != 0) rethrow; // real server rejection
      await OfflineQueue.instance.enqueue('certificate', '/api/certificates',
          body);
      return CertificateRequest(
        id: -1,
        requestNo: kPendingSyncRef,
        applicant: applicantName,
        typeKey: typeKey,
        purpose: purpose,
        residentId: residentId,
        createdAt: DateTime.now(),
      );
    }
    final req = CertificateRequest(
      id: res['id'] as int,
      requestNo: res['request_no'] as String,
      applicant: applicantName,
      typeKey: typeKey,
      purpose: purpose,
      residentId: residentId,
      createdAt: _parseTs(res['created_at']),
    );
    _requests.insert(0, req);
    notifyListeners();
    return req;
  }

  /// Permanently remove a request row and drop it locally.
  Future<void> delete(CertificateRequest r, {int? accountId}) async {
    final path = '/api/certificates/${r.id}';
    await ApiClient.instance
        .delete(accountId == null ? path : '$path?account_id=$accountId');
    _requests.removeWhere((x) => x.id == r.id);
    notifyListeners();
  }

  /// Move a request through the pipeline (approve / issue / reject).
  Future<void> setStatus(CertificateRequest r, String status,
      {String? remarks, int? accountId}) async {
    final prev = r.status;
    final prevRemarks = r.remarks;
    r.status = status; // optimistic — revert on failure
    if (remarks != null) r.remarks = remarks;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/api/certificates/${r.id}', {
        'status': status,
        if (remarks != null) 'remarks': remarks,
        if (accountId != null) 'account_id': accountId,
      });
    } catch (_) {
      r.status = prev;
      r.remarks = prevRemarks;
      notifyListeners();
      rethrow;
    }
  }
}

/// ── Resident profile edit requests (/api/edit-requests) ─────
/// Residents propose changes to their own record from the app; staff
/// review them in MIS → Barangay Residency → Edit Requests.

/// Field slug → display label for the review UI (matches the server's
/// EDITABLE list in routes/edit-requests.js).
const Map<String, String> kEditableFieldLabels = {
  'last_name': 'Last Name',
  'first_name': 'First Name',
  'middle_name': 'Middle Name',
  'suffix': 'Suffix',
  'birthdate': 'Birthdate',
  'sex': 'Sex',
  'civil_status': 'Civil Status',
  'contact_no': 'Contact No.',
  'occupation': 'Occupation',
  'voter_status': 'Voter Status',
  'photo': 'Profile Photo',
};

class ResidentEditRequest {
  ResidentEditRequest({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.changes,
    required this.current,
    required this.createdAt,
    this.status = 'pending',
    this.remarks,
    this.processedAt,
    this.processedByName,
  });

  factory ResidentEditRequest.fromJson(Map<String, dynamic> j) =>
      ResidentEditRequest(
        id: j['id'] as int,
        residentId: j['resident_id'] as int,
        residentName: (j['resident_name'] ?? '') as String,
        changes: (j['changes'] as Map? ?? const {}).cast<String, dynamic>(),
        current: (j['current'] as Map? ?? const {}).cast<String, dynamic>(),
        status: (j['status'] ?? 'pending') as String,
        remarks: j['remarks'] as String?,
        processedByName: j['processed_by_name'] as String?,
        processedAt: j['processed_at'] == null
            ? null
            : _parseTs(j['processed_at']),
        createdAt: _parseTs(j['created_at']),
      );

  final int id;
  final int residentId;
  final String residentName;

  /// Requested new values, keyed by resident column name.
  final Map<String, dynamic> changes;

  /// The record's values (at fetch time) for the same keys — old → new.
  final Map<String, dynamic> current;

  String status; // pending | approved | rejected
  String? remarks;
  final String? processedByName;
  final DateTime? processedAt;
  final DateTime createdAt;
}

class EditRequestStore extends ChangeNotifier with ApiStore {
  EditRequestStore._();
  static final EditRequestStore instance = EditRequestStore._();

  final List<ResidentEditRequest> _requests = [];
  List<ResidentEditRequest> get all => List.unmodifiable(_requests);

  int get pendingCount =>
      _requests.where((r) => r.status == 'pending').length;

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/edit-requests') as List;
    _requests
      ..clear()
      ..addAll(rows.map(
          (r) => ResidentEditRequest.fromJson(r as Map<String, dynamic>)));
  }

  /// Resident-side: file a request. [changes] holds only the fields being
  /// changed, keyed by resident column name.
  Future<void> submit({
    required int residentId,
    required Map<String, dynamic> changes,
    int? accountId,
  }) async {
    await ApiClient.instance.post('/api/edit-requests', {
      'resident_id': residentId,
      'changes': changes,
      if (accountId != null) 'account_id': accountId,
    });
    // Staff lists refresh on next load; no local insert needed since the
    // submitting resident doesn't see this store.
  }

  /// Staff-side: approve / reject (approve applies the changes server-side).
  Future<void> setStatus(ResidentEditRequest r, String status,
      {String? remarks, int? accountId}) async {
    final prev = r.status;
    final prevRemarks = r.remarks;
    r.status = status; // optimistic — revert on failure
    if (remarks != null) r.remarks = remarks;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/api/edit-requests/${r.id}', {
        'status': status,
        if (remarks != null) 'remarks': remarks,
        if (accountId != null) 'account_id': accountId,
      });
    } catch (_) {
      r.status = prev;
      r.remarks = prevRemarks;
      notifyListeners();
      rethrow;
    }
    // An approval changed the resident record — refresh the directory.
    if (status == 'approved') ResidentStore.instance.refresh();
  }
}

/// ── Incident / concern types (GIS_REPORT_TYPE_META) ─────────
class IncidentType {
  const IncidentType(this.key, this.label, {this.interpersonal = false});
  final String key;
  final String label;

  /// Interpersonal types show the Respondent + Witness fields.
  final bool interpersonal;
}

// Includes the former staff-only "accident marker" types (vehicular / fire /
// medical) — accident pings and community reports are one report type now.
const List<IncidentType> kIncidentTypes = [
  IncidentType('noise', 'Noise Complaint'),
  IncidentType('dispute', 'Property Dispute', interpersonal: true),
  IncidentType('altercation', 'Physical Altercation', interpersonal: true),
  IncidentType('theft', 'Theft / Robbery', interpersonal: true),
  IncidentType('vandalism', 'Vandalism'),
  IncidentType('domestic', 'Domestic Disturbance', interpersonal: true),
  IncidentType('flooding', 'Flooding / Natural Hazard'),
  IncidentType('vehicular', 'Vehicular Accident'),
  IncidentType('fire', 'Fire Incident'),
  IncidentType('medical', 'Medical Emergency'),
  IncidentType('other', 'Other'),
];

IncidentType incidentTypeByKey(String key) =>
    kIncidentTypes.firstWhere((t) => t.key == key,
        orElse: () => kIncidentTypes.last);

/// ── Audit log (audit_log table + local session entries) ──────
enum AuditCategory { map, concern, certificate, feedback, auth, archive, settings, system }

extension AuditCategoryMeta on AuditCategory {
  String get label {
    switch (this) {
      case AuditCategory.map:
        return 'Map Editing';
      case AuditCategory.concern:
        return 'Resident Concerns';
      case AuditCategory.certificate:
        return 'Certificates';
      case AuditCategory.feedback:
        return 'Feedback';
      case AuditCategory.auth:
        return 'Login & Accounts';
      case AuditCategory.archive:
        return 'Archive';
      case AuditCategory.settings:
        return 'Site Settings';
      case AuditCategory.system:
        return 'System';
    }
  }
}

AuditCategory _auditCategoryFrom(String? name) =>
    AuditCategory.values.asNameMap()[name] ?? AuditCategory.system;

enum AuditLevel { info, warning, critical }

class AuditEntry {
  AuditEntry({
    required this.ts,
    required this.user,
    required this.role,
    required this.action,
    required this.details,
    this.level = AuditLevel.info,
    this.category = AuditCategory.system,
    this.table,
    this.recordId,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        ts: _parseTs(j['created_at']),
        user: (j['actor'] ?? 'System') as String,
        role: (j['role'] ?? 'System') as String,
        action: (j['action'] ?? '') as String,
        details: (j['details'] ?? '') as String? ?? '',
        level: AuditLevel.values.asNameMap()[j['level']] ?? AuditLevel.info,
        category: _auditCategoryFrom(j['category'] as String?),
        table: j['table_name'] as String?,
        recordId: j['record_id'] == null ? null : '${j['record_id']}',
      );

  final DateTime ts;
  final String user;
  final String role;
  final String action;
  final String details;
  final AuditLevel level;
  final AuditCategory category;

  /// The row an entry touched — DB-trigger entries carry these; app-level
  /// entries leave them null. Shown as an "Item" reference in the UI.
  final String? table;
  final String? recordId;

  /// "<table> #<id>" (or "#<id>") when known, else empty.
  String get itemLabel {
    if (recordId == null || recordId!.isEmpty) return '';
    return '${table != null ? '$table ' : ''}#$recordId';
  }
}

/// Mirrors js/audit-log.js. log() records locally right away (so the UI is
/// instant) AND pushes the entry to POST /api/audit so the shared DB trail
/// gets it too; ensureLoaded()/refresh() pull the full server-side trail
/// (which also contains the web system's entries + DB trigger rows).
class AuditLog extends ChangeNotifier with ApiStore {
  AuditLog._();
  static final AuditLog instance = AuditLog._();
  static const int _max = 500;

  /// Entries with this action are the "logs were cleared" markers. They are
  /// immune to clearing (every wipe must stay on record) and only drop off
  /// the trail after [_clearRetention].
  static const String clearAction = 'AUDIT_CLEAR';
  static const Duration _clearRetention = Duration(days: 90);
  static const String _clearedAtKey = 'cares.audit.cleared_at';

  /// Everything at or before this instant is hidden by a previous
  /// "Clear Logs" (persisted so a clear survives app restarts). The DB
  /// trail itself stays append-only.
  DateTime? _clearedAt;
  bool _clearedAtLoaded = false;

  /// Latest AUDIT_CLEAR marker seen on the shared trail — a clear performed
  /// on the web (or another device) shows up here after a fetch and hides
  /// older entries, mirroring how the web honors this app's clears.
  DateTime? _serverClearedAt;

  final List<AuditEntry> _entries = [];
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Session lookups are injected lazily to avoid a circular import.
  String Function()? currentUser;
  String Function()? currentRole;
  int? Function()? currentAccountId;

  Future<void> _loadClearedAt() async {
    if (_clearedAtLoaded) return;
    _clearedAtLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_clearedAtKey);
      if (ms != null) _clearedAt = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      /* best-effort — worst case old entries reappear */
    }
  }

  /// The later of this device's own clear and any clear recorded on the
  /// shared trail — everything at or before it is hidden.
  DateTime? get _effectiveClearedAt {
    final a = _clearedAt, b = _serverClearedAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Clear markers show as long as they haven't expired (90 days); every
  /// other entry is hidden once a clear cutoff covers it.
  bool _visible(AuditEntry e) {
    if (e.action == clearAction) {
      return DateTime.now().difference(e.ts) <= _clearRetention;
    }
    final cutoff = _effectiveClearedAt;
    return cutoff == null || e.ts.isAfter(cutoff);
  }

  @override
  Future<void> fetch() async {
    await _loadClearedAt();
    final rows =
        await ApiClient.instance.get('/api/audit', query: {'limit': '200'})
            as List;
    final entries = rows
        .map((r) => AuditEntry.fromJson(r as Map<String, dynamic>))
        .toList();
    // The latest clear marker on the shared trail becomes a cutoff, so a
    // clear done on the web (or another device) hides older entries here.
    DateTime? serverCleared;
    for (final e in entries) {
      if (e.action == clearAction &&
          (serverCleared == null || e.ts.isAfter(serverCleared))) {
        serverCleared = e.ts;
      }
    }
    _serverClearedAt = serverCleared;
    _entries
      ..clear()
      ..addAll(entries.where(_visible));
  }

  void log(String action, String details,
      {AuditLevel level = AuditLevel.info,
      AuditCategory category = AuditCategory.system}) {
    final user = currentUser?.call() ?? 'Guest';
    final role = currentRole?.call() ?? 'Visitor';
    _entries.insert(
      0,
      AuditEntry(
        ts: DateTime.now(),
        user: user,
        role: role,
        action: action,
        details: details,
        level: level,
        category: category,
      ),
    );
    if (_entries.length > _max) _entries.removeRange(_max, _entries.length);
    notifyListeners();

    // Fire-and-forget to the shared trail; a failed push only means the
    // entry stays local for this session.
    unawaited(ApiClient.instance.post('/api/audit', {
      'action': action,
      'details': details,
      'level': level.name,
      'category': category.name,
      'actor_name': user,
      'actor_role': role,
      'account_id': currentAccountId?.call(),
    }).catchError((_) => null));
  }

  /// Clears the visible trail (the DB stays append-only): everything up to
  /// now is hidden — persistently, so it survives restarts/refreshes — but
  /// existing AUDIT_CLEAR markers are kept until their 90-day expiry.
  void clear() {
    _clearedAt = DateTime.now();
    _clearedAtLoaded = true;
    _entries.removeWhere((e) => !_visible(e));
    notifyListeners();
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_clearedAtKey, _clearedAt!.millisecondsSinceEpoch);
      } catch (_) {
        /* best-effort */
      }
    }());
  }
}

/// ── Feedback store (feedback table) ──────────────────────────
const List<String> kFeedbackCategories = [
  'Barangay Services',
  'Cleanliness & Sanitation',
  'Peace & Order',
  'Infrastructure',
  'Barangay Officials',
  'Health Services',
  'Other',
];

const List<String> kRatingLabels = [
  '',
  'Very Poor',
  'Poor',
  'Average',
  'Good',
  'Excellent',
];

class FeedbackEntry {
  FeedbackEntry({
    this.id,
    required this.ts,
    required this.rating,
    required this.category,
    required this.comment,
    this.name = 'Anonymous',
    this.contact = '',
    this.status = 'new',
    this.accountId,
  });

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        id: j['id'] as int?,
        ts: _parseTs(j['created_at']),
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        category: (j['category'] ?? 'Other') as String,
        comment: (j['comment'] ?? '') as String? ?? '',
        name: (j['name'] ?? 'Anonymous') as String,
        contact: (j['contact'] ?? '') as String? ?? '',
        status: (j['status'] ?? 'new') as String,
        accountId: j['account_id'] as int?,
      );

  final int? id;
  final DateTime ts;
  final int rating;
  final String category;
  final String comment;
  final String name;
  final String contact;
  final String status; // new | reviewed | archived

  /// account_id of the signed-in submitter (null = anonymous/visitor).
  final int? accountId;
}

class FeedbackStore extends ChangeNotifier with ApiStore {
  FeedbackStore._();
  static final FeedbackStore instance = FeedbackStore._();

  final List<FeedbackEntry> _entries = [];
  List<FeedbackEntry> get all => List.unmodifiable(_entries);

  int get unreviewedCount => _entries.where((e) => e.status == 'new').length;

  int countInCategory(String category) =>
      _entries.where((e) => e.category == category).length;

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/feedback') as List;
    _entries
      ..clear()
      ..addAll(
          rows.map((r) => FeedbackEntry.fromJson(r as Map<String, dynamic>)));
  }

  /// Permanently remove a feedback row and drop it locally.
  Future<void> delete(FeedbackEntry e, {int? accountId}) async {
    if (e.id == null) return;
    final path = '/api/feedback/${e.id}';
    await ApiClient.instance
        .delete(accountId == null ? path : '$path?account_id=$accountId');
    _entries.removeWhere((x) => x.id == e.id);
    notifyListeners();
  }

  Future<void> add({
    required int rating,
    required String category,
    required String comment,
    String name = '',
    String contact = '',
    int? accountId,
  }) async {
    final res = await ApiClient.instance.post('/api/feedback', {
      'rating': rating,
      'category': category,
      'comment': comment,
      'name': name.trim(),
      if (contact.trim().isNotEmpty) 'contact': contact.trim(),
      if (accountId != null) 'account_id': accountId,
    }) as Map<String, dynamic>;
    _entries.insert(
      0,
      FeedbackEntry(
        id: res['id'] as int?,
        ts: _parseTs(res['created_at']),
        rating: rating,
        category: category,
        comment: comment,
        name: name.trim().isEmpty ? 'Anonymous' : name.trim(),
        contact: contact,
        accountId: accountId,
      ),
    );
    notifyListeners();
  }
}

/// ── Incident / blotter store (incident table) ────────────────
class IncidentReport {
  IncidentReport({
    this.id,
    required this.caseNo,
    required this.typeKey,
    required this.complainant,
    required this.narration,
    required this.createdAt,
    this.contact = '',
    this.respondent = '',
    this.witnesses = '',
    this.location = '',
    this.mapPoint,
    this.resolved = false,
    this.complainantId,
    this.reporterRole = '',
  });

  final int? id;
  final String caseNo;
  final String typeKey;
  final String complainant;
  final String narration;
  final DateTime createdAt;
  final String contact;
  final String respondent;
  final String witnesses;
  final String location;

  /// resident_id of the complainant — links the report back to the account
  /// that filed it (Activity History).
  final int? complainantId;

  /// Where the pin was dropped, normalized 0..1 against the GIS map
  /// canvas (converted from the DB's real lat/lng).
  final Offset? mapPoint;
  bool resolved;

  /// account.role of whoever filed it ('' when filed signed-out) — colors
  /// the pin official (Admin/Officer/Staff) vs resident.
  final String reporterRole;

  bool get isOfficial =>
      reporterRole == 'Admin' ||
      reporterRole == 'Officer' ||
      reporterRole == 'Staff';

  String get typeLabel => incidentTypeByKey(typeKey).label;
}

class IncidentStore extends ChangeNotifier with ApiStore {
  IncidentStore._();
  static final IncidentStore instance = IncidentStore._();

  final List<IncidentReport> _reports = [];

  List<IncidentReport> get all {
    final list = List<IncidentReport>.from(_reports);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get activeCount => _reports.where((r) => !r.resolved).length;
  int get resolvedCount => _reports.where((r) => r.resolved).length;

  int get filedThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    return _reports.where((r) => !r.createdAt.isBefore(monthStart)).length;
  }

  @override
  Future<void> fetch() async {
    // The map projection converts each row's lat/lng into the normalized
    // pin position the GIS canvas draws.
    final results = await Future.wait([
      ApiClient.instance.get('/api/incidents'),
      GisMapData.load(),
    ]);
    final rows = results[0] as List;
    final gis = results[1] as GisMapData;

    _reports.clear();
    for (final raw in rows) {
      final j = raw as Map<String, dynamic>;
      final lat = (j['lat'] as num?)?.toDouble();
      final lng = (j['lng'] as num?)?.toDouble();
      _reports.add(IncidentReport(
        id: j['id'] as int?,
        caseNo: (j['case_no'] ?? '') as String,
        typeKey: (j['report_type'] ?? 'other') as String,
        complainant: (j['complainant_name'] ?? '') as String,
        narration: (j['narration'] ?? '') as String,
        contact: (j['contact'] ?? '') as String? ?? '',
        respondent: (j['respondent'] ?? '') as String? ?? '',
        witnesses: (j['witnesses'] ?? '') as String? ?? '',
        location: 'Pinned on GIS map',
        complainantId: j['complainant_id'] as int?,
        reporterRole: (j['reporter_role'] ?? '') as String? ?? '',
        mapPoint: (lat != null && lng != null)
            ? gis.normalizedFromLatLng(lat, lng)
            : null,
        resolved: j['status'] == 'resolved' || j['status'] == 'dismissed',
        createdAt: _parseTs(j['created_at']),
      ));
    }
  }

  Future<IncidentReport> file({
    required String typeKey,
    required String complainant,
    required String narration,
    String contact = '',
    String respondent = '',
    String witnesses = '',
    String location = '',
    Offset? mapPoint,
    int? complainantId,
    int? accountId,
    String reporterRole = '',
  }) async {
    double? lat, lng;
    if (mapPoint != null) {
      final gis = await GisMapData.load();
      (lat, lng) = gis.latLngFromNormalized(mapPoint);
    }
    final body = {
      'report_type': typeKey,
      'title': incidentTypeByKey(typeKey).label,
      'narration': narration,
      'complainant_name': complainant,
      if (contact.isNotEmpty) 'contact': contact,
      if (respondent.isNotEmpty) 'respondent': respondent,
      if (witnesses.isNotEmpty) 'witnesses': witnesses,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (complainantId != null) 'complainant_id': complainantId,
      if (accountId != null) 'account_id': accountId,
    };
    final Map<String, dynamic> res;
    try {
      res = await ApiClient.instance.post('/api/incidents', body)
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode != 0) rethrow;
      // Offline: park it in the queue; it uploads when connectivity returns.
      await OfflineQueue.instance.enqueue('incident', '/api/incidents', body);
      return IncidentReport(
        caseNo: kPendingSyncRef,
        typeKey: typeKey,
        complainant: complainant,
        complainantId: complainantId,
        reporterRole: reporterRole,
        narration: narration,
        contact: contact,
        respondent: respondent,
        witnesses: witnesses,
        location: location,
        mapPoint: mapPoint,
        createdAt: DateTime.now(),
      );
    }

    final report = IncidentReport(
      id: res['id'] as int?,
      caseNo: res['case_no'] as String,
      typeKey: typeKey,
      complainant: complainant,
      complainantId: complainantId,
      reporterRole: reporterRole,
      narration: narration,
      contact: contact,
      respondent: respondent,
      witnesses: witnesses,
      location: location,
      mapPoint: mapPoint,
      createdAt: _parseTs(res['created_at']),
    );
    _reports.add(report);
    notifyListeners();
    return report;
  }

  /// Permanently remove a blotter entry and drop it locally.
  Future<void> delete(IncidentReport r, {int? accountId}) async {
    if (r.id == null) return;
    final path = '/api/incidents/${r.id}';
    await ApiClient.instance
        .delete(accountId == null ? path : '$path?account_id=$accountId');
    _reports.removeWhere((x) => x.id == r.id);
    notifyListeners();
  }

  /// Resolve / reopen. Optimistic: flips locally, reverts if the server
  /// rejects it (the UI listens, so a revert shows immediately).
  void setResolved(String caseNo, bool resolved, {int? accountId}) {
    for (final r in _reports) {
      if (r.caseNo != caseNo) continue;
      final prev = r.resolved;
      r.resolved = resolved;
      notifyListeners();
      if (r.id == null) return;
      unawaited(ApiClient.instance.patch('/api/incidents/${r.id}', {
        'status': resolved ? 'resolved' : 'open',
        if (accountId != null) 'account_id': accountId,
      }).catchError((_) {
        r.resolved = prev;
        notifyListeners();
        return null;
      }));
      return;
    }
  }
}

/// ── GIS map state (GET /api/gis/state) ───────────────────────
/// Building tags saved from the web MIS map (government / business /
/// household), plus custom-drawn buildings — the shared-DB side of the
/// web's gis_building_tags localStorage store.
class BuildingTag {
  const BuildingTag({
    required this.name,
    required this.type,
    this.subcat = '',
    this.notes = '',
  });

  factory BuildingTag.fromJson(Map<String, dynamic> j) => BuildingTag(
        name: (j['name'] ?? '') as String? ?? '',
        type: (j['type'] ?? '') as String? ?? '',
        subcat: (j['subcat'] ?? '') as String? ?? '',
        notes: (j['notes'] ?? '') as String? ?? '',
      );

  final String name;
  final String type; // government | business | households
  final String subcat; // seniors | pwd | solo-parent | indigent (households)
  final String notes;

  /// "Government Building", "Business", "Household · Senior Citizen" —
  /// mirrors the web's gisTagDisplayMeta labels.
  String get typeLabel {
    const typeLabels = {
      'government': 'Government Building',
      'business': 'Business',
      'households': 'Household',
    };
    const subcatLabels = {
      'seniors': 'Senior Citizen',
      'pwd': 'PWD',
      'solo-parent': 'Solo Parent',
      'indigent': 'Indigent Family',
    };
    final base = typeLabels[type] ?? type;
    final sub = subcatLabels[subcat];
    return sub == null ? base : '$base · $sub';
  }
}

/// One custom-drawn building polygon (ring of lng/lat pairs), tagged via
/// the key 'c<id>' in [GisStateStore.buildingTags].
class CustomBuilding {
  const CustomBuilding({required this.id, required this.ring});
  final int id;
  final List<(double lng, double lat)> ring;

  String get tagKey => 'c$id';
}

typedef LngLat = (double lng, double lat);

List<LngLat> _lngLatList(dynamic coords) => [
      for (final p in (coords as List? ?? const []))
        ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];

/// Staff-drawn road (map_feature type 'road').
class CustomRoad {
  const CustomRoad(
      {required this.id, required this.points, this.name = '', this.roadType = 'local'});
  final int id;
  final List<LngLat> points;
  final String name;
  final String roadType; // major | local | service
}

/// Staff-drawn vegetation area (map_feature type 'vegetation').
class CustomVegetation {
  const CustomVegetation(
      {required this.id, required this.ring, this.kind = '', this.notes = ''});
  final int id;
  final List<LngLat> ring;
  final String kind; // farmland | farmyard | orchard | meadow | wood
  final String notes;
}

/// Construction area (map_feature type 'construction').
class ConstructionArea {
  const ConstructionArea({
    required this.id,
    required this.ring,
    this.name = '',
    this.status = 'planned',
    this.notes = '',
  });
  final int id;
  final List<LngLat> ring;
  final String name;
  final String status; // planned | ongoing | completed
  final String notes;

  String get statusLabel =>
      {'planned': 'Planned', 'ongoing': 'Ongoing', 'completed': 'Completed'}[status] ??
      status;
}

/// Hazard ping (map_feature type 'hazard') — a circular area marker.
class HazardZone {
  const HazardZone({
    required this.id,
    required this.lng,
    required this.lat,
    this.radius = 35,
    this.hazardType = 'other',
    this.severity = '',
    this.notes = '',
  });
  final int id;
  final double lng;
  final double lat;

  /// In map units of the web's 0..1000 viewBox (GIS_HAZARD_PING_RADIUS).
  final double radius;
  final String hazardType; // flood | landslide | fire | other
  final String severity; // low | medium | high | critical | ''
  final String notes;

  String get typeLabel =>
      {
        'flood': 'Flood Zone',
        'landslide': 'Landslide Risk',
        'fire': 'Fire Risk',
        'other': 'Other Hazard',
      }[hazardType] ??
      'Hazard';
}

/// Lightweight view-model for a tapped map feature — the map screen turns
/// this into a details dialog.
class MapFeatureInfo {
  const MapFeatureInfo({required this.title, required this.badge, this.body = ''});
  final String title;
  final String badge;
  final String body;
}

class GisStateStore extends ChangeNotifier with ApiStore {
  GisStateStore._();
  static final GisStateStore instance = GisStateStore._();

  /// building id (OSM way id, or 'c<id>' for custom) → tag.
  Map<String, BuildingTag> buildingTags = {};
  List<CustomBuilding> customBuildings = [];
  List<CustomRoad> customRoads = [];
  List<CustomVegetation> customVegetation = [];
  List<ConstructionArea> construction = [];
  List<HazardZone> hazards = [];

  /// OSM buildings tombstoned from the web map's Edit Mode.
  Set<String> deletedBuildingIds = {};

  /// vegetation id (OSM or map_feature id) → cut rings trimmed out of it.
  Map<String, List<List<LngLat>>> vegetationCuts = {};

  /// Bumped on every fetch so the painter can cache derived geometry.
  int version = 0;

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/gis/state')
        as Map<String, dynamic>;
    buildingTags = {
      for (final e in ((j['buildingTags'] as Map?) ?? const {}).entries)
        e.key.toString():
            BuildingTag.fromJson((e.value as Map).cast<String, dynamic>()),
    };
    customBuildings = [
      for (final raw in (j['customBuildings'] as List? ?? const []))
        CustomBuilding(
          id: ((raw as Map)['id'] as num).toInt(),
          ring: _lngLatList(raw['coordinates']),
        ),
    ];

    final features = (j['features'] as Map?) ?? const {};
    List<Map<String, dynamic>> rows(String type) => [
          for (final raw in (features[type] as List? ?? const []))
            (raw as Map).cast<String, dynamic>(),
        ];

    customRoads = [
      for (final r in rows('road'))
        CustomRoad(
          id: (r['id'] as num).toInt(),
          points: _lngLatList(r['coordinates']),
          name: (r['name'] ?? '') as String? ?? '',
          roadType: (r['roadType'] ?? 'local') as String? ?? 'local',
        ),
    ];
    customVegetation = [
      for (final r in rows('vegetation'))
        CustomVegetation(
          id: (r['id'] as num).toInt(),
          ring: _lngLatList((r['coordinates'] as List).isEmpty
              ? const []
              : (r['coordinates'] as List)[0]),
          kind: (r['kind'] ?? '') as String? ?? '',
          notes: (r['notes'] ?? '') as String? ?? '',
        ),
    ];
    construction = [
      for (final r in rows('construction'))
        ConstructionArea(
          id: (r['id'] as num).toInt(),
          ring: _lngLatList((r['coordinates'] as List).isEmpty
              ? const []
              : (r['coordinates'] as List)[0]),
          name: (r['name'] ?? '') as String? ?? '',
          status: (r['status'] ?? 'planned') as String? ?? 'planned',
          notes: (r['notes'] ?? '') as String? ?? '',
        ),
    ];
    hazards = [
      for (final r in rows('hazard'))
        HazardZone(
          id: (r['id'] as num).toInt(),
          lng: ((r['coordinates'] as List)[0] as num).toDouble(),
          lat: ((r['coordinates'] as List)[1] as num).toDouble(),
          radius: (r['radius'] as num?)?.toDouble() ?? 35,
          hazardType: (r['hazardType'] ?? 'other') as String? ?? 'other',
          severity: (r['severity'] ?? '') as String? ?? '',
          notes: (r['notes'] ?? '') as String? ?? '',
        ),
    ];
    // (map_feature 'accident' rows were migrated into the incident table —
    // accidents render as regular report pins now.)

    deletedBuildingIds = {};
    vegetationCuts = {};
    for (final raw in (j['osmEdits'] as List? ?? const [])) {
      final e = (raw as Map).cast<String, dynamic>();
      final osmId = e['osm_id']?.toString() ?? '';
      if (e['edit_type'] == 'delete' && e['feature_kind'] == 'building') {
        deletedBuildingIds.add(osmId);
      } else if (e['edit_type'] == 'cut' && e['feature_kind'] == 'vegetation') {
        final rings = ((e['overrides'] as Map?)?['rings'] as List?) ?? const [];
        vegetationCuts[osmId] = [for (final ring in rings) _lngLatList(ring)];
      }
    }
    version++;
  }
}

/// ── Dashboard stats (GET /api/stats/dashboard) ───────────────
class DashboardStats extends ChangeNotifier with ApiStore {
  DashboardStats._();
  static final DashboardStats instance = DashboardStats._();

  int residents = 0;
  int households = 0;
  int certificatesPending = 0;
  int incidentsOpen = 0;
  int incidentsThisMonth = 0;
  int feedbackNew = 0;
  double? feedbackAvg;
  int accountsClaimed = 0;

  /// purok name → active residents.
  Map<String, int> byPurok = {};

  /// classification slug → residents.
  Map<String, int> byClassification = {};

  /// certificate status → count.
  Map<String, int> certificatesByStatus = {};

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/stats/dashboard')
        as Map<String, dynamic>;
    residents = (j['residents'] as num?)?.toInt() ?? 0;
    households = (j['households'] as num?)?.toInt() ?? 0;
    certificatesPending = (j['certificates_pending'] as num?)?.toInt() ?? 0;
    incidentsOpen = (j['incidents_open'] as num?)?.toInt() ?? 0;
    incidentsThisMonth = (j['incidents_this_month'] as num?)?.toInt() ?? 0;
    feedbackNew = (j['feedback_new'] as num?)?.toInt() ?? 0;
    feedbackAvg = (j['feedback_avg'] as num?)?.toDouble();
    accountsClaimed = (j['accounts_claimed'] as num?)?.toInt() ?? 0;
    byPurok = {
      for (final r in (j['by_purok'] as List? ?? const []))
        (r['purok'] ?? '?') as String: (r['residents'] as num?)?.toInt() ?? 0,
    };
    byClassification = {
      for (final r in (j['by_classification'] as List? ?? const []))
        (r['classification'] ?? '?') as String:
            (r['residents'] as num?)?.toInt() ?? 0,
    };
    certificatesByStatus = {
      for (final e
          in ((j['certificates_by_status'] as Map?) ?? const {}).entries)
        e.key.toString(): (e.value as num?)?.toInt() ?? 0,
    };
  }
}

/// ── Notifications (notification table via /api/notifications) ─
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.ref,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String? ?? '',
        kind: (j['kind'] ?? 'system') as String,
        ref: (j['ref'] ?? '') as String? ?? '',
        read: j['is_read'] == true,
        createdAt: _parseTs(j['created_at']),
      );

  final int id;
  final String title;
  final String body;
  final String kind; // certificate | message | system
  final String ref; // e.g. CERT-2026-001
  bool read;
  final DateTime createdAt;
}

/// The signed-in account's notification feed. The bell badge shows
/// [unreadCount]; opening the Notifications screen marks everything read.
class NotificationStore extends ChangeNotifier with ApiStore {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  /// Injected by AppSession (same pattern as [AuditLog]) to avoid a
  /// circular import.
  int? Function()? currentAccountId;

  final List<AppNotification> _items = [];
  List<AppNotification> get all => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  @override
  Future<void> fetch() async {
    final accountId = currentAccountId?.call();
    if (accountId == null) {
      _items.clear();
      return;
    }
    final rows = await ApiClient.instance.get('/api/notifications',
        query: {'account_id': '$accountId', 'limit': '100'}) as List;
    _items
      ..clear()
      ..addAll(
          rows.map((r) => AppNotification.fromJson(r as Map<String, dynamic>)));
  }

  Future<void> markAllRead() async {
    final accountId = currentAccountId?.call();
    if (accountId == null || unreadCount == 0) return;
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
    unawaited(ApiClient.instance
        .post('/api/notifications/read-all', {'account_id': accountId})
        .catchError((_) => null));
  }

  /// Sign-out: drop the feed and force a refetch on the next sign-in.
  void reset() {
    _items.clear();
    _loaded = false;
    notifyListeners();
  }

  /// Send a notification to another account (staff → requester message).
  /// Static because the sender doesn't touch the local feed.
  static Future<void> send({
    int? accountId,
    int? residentId,
    required String title,
    String body = '',
    String kind = 'message',
    String? ref,
  }) {
    return ApiClient.instance.post('/api/notifications', {
      if (accountId != null) 'account_id': accountId,
      if (residentId != null) 'resident_id': residentId,
      'title': title,
      if (body.isNotEmpty) 'body': body,
      'kind': kind,
      if (ref != null) 'ref': ref,
    });
  }
}

/// ── Announcements (announcement table via /api/announcements) ─
/// The landing page's "Latest announcements" bulletin; staff manage the
/// list from MIS → Site Content.
class AnnouncementStore extends ChangeNotifier with ApiStore {
  AnnouncementStore._();
  static final AnnouncementStore instance = AnnouncementStore._();

  final List<Announcement> _items = [];
  List<Announcement> get all => List.unmodifiable(_items);

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/announcements') as List;
    _items
      ..clear()
      ..addAll(
          rows.map((r) => Announcement.fromJson(r as Map<String, dynamic>)));
  }

  /// Create ([id] == null) or update an announcement.
  Future<void> save({
    int? id,
    required String title,
    required String body,
    required String tag,
    int? accountId,
  }) async {
    final payload = {
      'title': title,
      'body': body,
      'tag': tag,
      if (accountId != null) 'account_id': accountId,
    };
    final res = id == null
        ? await ApiClient.instance.post('/api/announcements', payload)
        : await ApiClient.instance.put('/api/announcements/$id', payload);
    final saved = Announcement.fromJson(res as Map<String, dynamic>);
    if (id == null) {
      _items.insert(0, saved);
    } else {
      final ix = _items.indexWhere((a) => a.id == id);
      if (ix >= 0) _items[ix] = saved;
    }
    notifyListeners();
  }

  Future<void> remove(Announcement a, {int? accountId}) async {
    final path = '/api/announcements/${a.id}';
    await ApiClient.instance.delete(
        accountId == null ? path : '$path?account_id=$accountId');
    _items.removeWhere((x) => x.id == a.id);
    notifyListeners();
  }
}

/// ── Barangay officials (official table via /api/officials) ────
/// The landing page's "Barangay Officials" leadership cards — the DB-backed
/// replacement for the web's js/site-config.js localStorage store.
class Official {
  const Official({
    this.id,
    required this.name,
    required this.role,
    required this.desc,
    this.honorific = 'Hon.',
    this.photo,
  });

  factory Official.fromJson(Map<String, dynamic> j) => Official(
        id: j['id'] as int?,
        honorific: (j['honorific'] ?? 'Hon.') as String? ?? 'Hon.',
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        desc: (j['description'] ?? '') as String? ?? '',
        photo: j['photo'] as String?,
      );

  final int? id;
  final String honorific;
  final String name;
  final String role;
  final String desc;

  /// base64 data URL (same convention as resident.photo) or null.
  final String? photo;

  String get displayName =>
      honorific.isEmpty ? name : '$honorific $name';

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

class OfficialStore extends ChangeNotifier with ApiStore {
  OfficialStore._();
  static final OfficialStore instance = OfficialStore._();

  final List<Official> _items = [];
  List<Official> get all => List.unmodifiable(_items);

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/officials') as List;
    _items
      ..clear()
      ..addAll(rows.map((r) => Official.fromJson(r as Map<String, dynamic>)));
  }

  /// Create ([id] == null) or update an official.
  Future<void> save({
    int? id,
    required String honorific,
    required String name,
    required String role,
    required String desc,
    String? photo,
    int? accountId,
  }) async {
    final payload = {
      'honorific': honorific,
      'name': name,
      'role': role,
      'description': desc,
      'photo': photo,
      if (accountId != null) 'account_id': accountId,
    };
    final res = id == null
        ? await ApiClient.instance.post('/api/officials', payload)
        : await ApiClient.instance.put('/api/officials/$id', payload);
    final saved = Official.fromJson(res as Map<String, dynamic>);
    if (id == null) {
      _items.add(saved);
    } else {
      final ix = _items.indexWhere((o) => o.id == id);
      if (ix >= 0) _items[ix] = saved;
    }
    notifyListeners();
  }

  Future<void> remove(Official o, {int? accountId}) async {
    final path = '/api/officials/${o.id}';
    await ApiClient.instance.delete(
        accountId == null ? path : '$path?account_id=$accountId');
    _items.removeWhere((x) => x.id == o.id);
    notifyListeners();
  }

  /// Move an official one slot up/down in the display order. Optimistic:
  /// reorders locally, then persists the whole order in one call.
  Future<void> move(Official o, int delta, {int? accountId}) async {
    final ix = _items.indexWhere((x) => x.id == o.id);
    final to = ix + delta;
    if (ix < 0 || to < 0 || to >= _items.length) return;
    final prev = List<Official>.from(_items);
    _items
      ..removeAt(ix)
      ..insert(to, o);
    notifyListeners();
    try {
      await ApiClient.instance.post('/api/officials/order', {
        'ids': [for (final x in _items) x.id],
        if (accountId != null) 'account_id': accountId,
      });
    } catch (_) {
      _items
        ..clear()
        ..addAll(prev);
      notifyListeners();
      rethrow;
    }
  }
}

/// ── Delete permissions (settings: delete-permissions) ─────────
/// Which staff roles may delete records in each module. Admin can always
/// delete (and is the only role that edits this matrix); Officer is
/// configurable per module from User Management; Residents never delete.
/// Persisted in the shared `app_setting` table via /api/settings so the
/// same rules apply on every device.

/// A module whose records can be deleted, with its display label. The [key]
/// matches the settings JSON and the pages that gate their delete buttons.
class DeletableModule {
  const DeletableModule(this.key, this.label);
  final String key;
  final String label;
}

const List<DeletableModule> kDeletableModules = [
  DeletableModule('residency', 'Residency — Delete Residents'),
  DeletableModule('certificates', 'Certificates — Delete Requests'),
  DeletableModule('incidents', 'Blotter — Delete Reports'),
  DeletableModule('feedback', 'Feedback — Delete Entries'),
  DeletableModule('announcements', 'Site Content — Delete Announcements'),
  DeletableModule('officials', 'Site Content — Delete Officials'),
  DeletableModule('buildings', 'GIS Map — Delete Buildings'),
];

class DeletePermissions extends ChangeNotifier with ApiStore {
  DeletePermissions._();
  static final DeletePermissions instance = DeletePermissions._();

  static const String _settingKey = 'delete-permissions';

  /// role name ('officer') → { moduleKey → allowed }. Admin is implicit
  /// (always allowed) and never stored here.
  Map<String, Map<String, bool>> _matrix = {};

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/settings/$_settingKey')
        as Map<String, dynamic>;
    final value = j['value'];
    _matrix = {};
    if (value is Map) {
      for (final role in value.entries) {
        final perms = role.value;
        if (perms is Map) {
          _matrix[role.key.toString()] = {
            for (final e in perms.entries) e.key.toString(): e.value == true,
          };
        }
      }
    }
  }

  /// The single blanket delete permission key (delete is now one matrix row,
  /// not per-module).
  static const String recordsKey = 'records';

  /// Whether the role named [roleName] (UserRole.name — 'admin' / 'officer' /
  /// 'resident') may delete records. Admin: always. Residents/guests: never.
  /// Any other role (Officer, custom staff roles): only when the single
  /// "Delete Records" permission is granted. [moduleKey] is ignored now that
  /// delete is one blanket toggle. Kept role-name based so this store doesn't
  /// import session.dart (which imports stores.dart).
  bool can(String? roleName, String moduleKey) {
    if (roleName == 'admin') return true;
    if (roleName == null || roleName == 'resident') return false;
    return _matrix[roleName]?[recordsKey] ?? false;
  }

  bool officerCan(String moduleKey) => _matrix['officer']?[moduleKey] ?? false;

  /// Whether an arbitrary role key (lowercased role name) may delete
  /// [moduleKey] — the matrix UI reads this per column. Delete defaults off.
  bool roleCan(String roleKey, String moduleKey) =>
      _matrix[roleKey]?[moduleKey] ?? false;

  /// Set the permission for any role and persist the whole matrix.
  Future<void> setRolePerm(String roleKey, String moduleKey, bool allowed) async {
    final prev = _cloneMatrix();
    (_matrix[roleKey] ??= {})[moduleKey] = allowed;
    notifyListeners();
    try {
      await ApiClient.instance
          .put('/api/settings/$_settingKey', {'value': _matrix});
    } catch (_) {
      _matrix = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Drop a whole role's delete permissions (when a custom role is removed).
  Future<void> removeRole(String roleKey) async {
    if (!_matrix.containsKey(roleKey)) return;
    final prev = _cloneMatrix();
    _matrix.remove(roleKey);
    notifyListeners();
    try {
      await ApiClient.instance
          .put('/api/settings/$_settingKey', {'value': _matrix});
    } catch (_) {
      _matrix = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Set the Officer permission for one module and persist the whole matrix.
  /// Optimistic: flips locally, reverts if the save fails.
  Future<void> setOfficer(String moduleKey, bool allowed) async {
    final prev = _cloneMatrix();
    (_matrix['officer'] ??= {})[moduleKey] = allowed;
    notifyListeners();
    try {
      await ApiClient.instance.put('/api/settings/$_settingKey', {
        'value': _matrix,
      });
    } catch (_) {
      _matrix = prev;
      notifyListeners();
      rethrow;
    }
  }

  Map<String, Map<String, bool>> _cloneMatrix() =>
      {for (final e in _matrix.entries) e.key: Map<String, bool>.from(e.value)};
}

/// One entry in the system recycle bin (GET /api/archive). A record that was
/// deleted from the system and can be restored — residents, certificate
/// requests, blotter reports, feedback, announcements, officials.
class ArchiveEntry {
  ArchiveEntry({
    required this.archiveId,
    required this.module,
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.archivedBy,
    required this.archivedAt,
  });

  final int archiveId;
  final String module;
  final String typeLabel;
  final String title;
  final String subtitle;
  final String archivedBy;
  final DateTime archivedAt;

  factory ArchiveEntry.fromJson(Map<String, dynamic> j) => ArchiveEntry(
        archiveId: j['archiveId'] as int,
        module: (j['module'] ?? '') as String,
        typeLabel: (j['typeLabel'] ?? 'Record') as String,
        title: (j['title'] ?? '') as String,
        subtitle: (j['subtitle'] ?? '') as String,
        archivedBy: (j['archivedBy'] ?? 'System') as String,
        archivedAt:
            DateTime.tryParse('${j['archivedAt']}')?.toLocal() ?? DateTime.now(),
      );
}

/// The recycle bin backing the Archive module. Lists deleted records from the
/// shared `archive` table and restores / permanently deletes them. Every
/// action is audited server-side (see the server's archive-service.js).
class ArchiveStore extends ChangeNotifier with ApiStore {
  ArchiveStore._();
  static final ArchiveStore instance = ArchiveStore._();

  final List<ArchiveEntry> _items = [];
  List<ArchiveEntry> get all => List.unmodifiable(_items);

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/archive') as List;
    _items
      ..clear()
      ..addAll(rows.map((r) => ArchiveEntry.fromJson(r as Map<String, dynamic>)));
  }

  /// Bring a record back to where it was.
  Future<void> restore(ArchiveEntry e, {int? accountId}) async {
    await ApiClient.instance.post('/api/archive/${e.archiveId}/restore', {
      if (accountId != null) 'account_id': accountId,
    });
    _items.removeWhere((x) => x.archiveId == e.archiveId);
    notifyListeners();
  }

  /// Permanently delete a record — it can no longer be restored.
  Future<void> purge(ArchiveEntry e, {int? accountId}) async {
    final path = '/api/archive/${e.archiveId}';
    await ApiClient.instance
        .delete(accountId == null ? path : '$path?account_id=$accountId');
    _items.removeWhere((x) => x.archiveId == e.archiveId);
    notifyListeners();
  }
}

/// One deleted GIS map building (GET /api/gis/archive). These have their own
/// snapshot shape and restore path (POST /api/gis/archive/restore) separate
/// from the record recycle bin above.
class ArchivedBuilding {
  ArchivedBuilding({
    required this.id,
    required this.name,
    required this.category,
    required this.archivedAt,
  });

  final String id;
  final String name;
  final String category;
  final DateTime archivedAt;

  factory ArchivedBuilding.fromJson(Map<String, dynamic> j) {
    final tag = (j['tag'] as Map?)?.cast<String, dynamic>();
    final ms = j['archivedAt'];
    return ArchivedBuilding(
      id: '${j['id']}',
      name: (tag?['name'] as String?)?.trim().isNotEmpty == true
          ? tag!['name'] as String
          : 'Untagged Building',
      category: (tag?['type'] as String?) ?? '',
      archivedAt: ms is num
          ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
          : DateTime.now(),
    );
  }
}

/// The "Deleted Map Buildings" list on the Archive page. Mirrors the web
/// archive.js building section: pulls the shared snapshots and restores them.
class MapBuildingArchiveStore extends ChangeNotifier with ApiStore {
  MapBuildingArchiveStore._();
  static final MapBuildingArchiveStore instance = MapBuildingArchiveStore._();

  final List<ArchivedBuilding> _items = [];
  List<ArchivedBuilding> get all => List.unmodifiable(_items);

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/gis/archive') as List;
    _items
      ..clear()
      ..addAll(
          rows.map((r) => ArchivedBuilding.fromJson(r as Map<String, dynamic>)));
  }

  /// Restore a building (custom → active, OSM → tombstone removed) on the map.
  Future<void> restore(ArchivedBuilding b, {int? accountId}) async {
    await ApiClient.instance.post('/api/gis/archive/restore', {
      'id': b.id,
      if (accountId != null) 'account_id': accountId,
    });
    _items.removeWhere((x) => x.id == b.id);
    notifyListeners();
  }
}

/// A login account row (GET /api/accounts) for User Management.
class AccountRow {
  AccountRow({
    required this.accountId,
    required this.name,
    required this.email,
    required this.role,
    required this.residentId,
    required this.purok,
    required this.createdAt,
  });

  final int accountId;
  final String name;
  final String email;
  String role;
  final int? residentId;
  final String? purok;
  final String createdAt;

  factory AccountRow.fromJson(Map<String, dynamic> j) => AccountRow(
        accountId: j['account_id'] as int,
        name: (j['name'] ?? j['email'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        role: (j['role'] ?? 'Resident') as String,
        residentId: j['resident_id'] as int?,
        purok: j['purok'] as String?,
        createdAt: (j['created_at'] ?? '') as String,
      );
}

/// The account list + role changing behind User Management (mirrors the web's
/// js/pages/users.js). Only an Admin may change roles; the server writes the
/// ROLE_CHANGE audit entry.
class AccountStore extends ChangeNotifier with ApiStore {
  AccountStore._();
  static final AccountStore instance = AccountStore._();

  final List<AccountRow> _items = [];
  List<AccountRow> get all => List.unmodifiable(_items);

  @override
  Future<void> fetch() async {
    final rows = await ApiClient.instance.get('/api/accounts') as List;
    _items
      ..clear()
      ..addAll(rows.map((r) => AccountRow.fromJson(r as Map<String, dynamic>)));
  }

  /// Change one account's role. [actorAccountId]/[actorName]/[actorRole]
  /// identify the acting admin for the audit trail.
  Future<void> changeRole(
    AccountRow a,
    String newRole, {
    int? actorAccountId,
    String? actorName,
    String? actorRole,
  }) async {
    await ApiClient.instance.patch('/api/accounts/${a.accountId}/role', {
      'role': newRole,
      if (actorAccountId != null) 'account_id': actorAccountId,
      if (actorName != null) 'actor_name': actorName,
      if (actorRole != null) 'actor_role': actorRole,
    });
    a.role = newRole;
    notifyListeners();
  }
}

/// Which MIS modules an Officer may open. Same shape/setting mechanism as
/// [DeletePermissions] but for module access (settings key 'module-access').
/// Admins always have every module; residents use the public portal — so only
/// the Officer row is configurable. Unset modules fall back to a caller-
/// supplied default, so a fresh install behaves exactly as before.
class ModuleAccess extends ChangeNotifier with ApiStore {
  ModuleAccess._();
  static final ModuleAccess instance = ModuleAccess._();

  static const String _settingKey = 'module-access';

  /// Full role → {moduleKey: bool} map. Other roles (resident + any custom
  /// roles the web matrix adds) are kept intact so a save here never wipes
  /// them; only the 'officer' entry is enforced/edited on mobile.
  Map<String, Map<String, bool>> _byRole = {};

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/settings/$_settingKey')
        as Map<String, dynamic>;
    final value = j['value'];
    _byRole = {};
    if (value is Map) {
      value.forEach((role, perms) {
        if (perms is Map) {
          _byRole[role.toString()] = {
            for (final e in perms.entries) e.key.toString(): e.value == true,
          };
        }
      });
    }
  }

  /// Effective Officer access for [moduleKey]: an explicit override if set,
  /// otherwise [fallback] (the module's built-in default).
  bool officerCan(String moduleKey, {required bool fallback}) =>
      _byRole['officer']?[moduleKey] ?? fallback;

  /// Effective access for any role key (lowercased role name); [fallback] is
  /// the role's built-in default when there's no stored override.
  bool can(String roleKey, String moduleKey, {required bool fallback}) =>
      _byRole[roleKey]?[moduleKey] ?? fallback;

  Map<String, Map<String, bool>> _clone() =>
      {for (final e in _byRole.entries) e.key: Map<String, bool>.from(e.value)};

  /// Set the override for any role + module (preserving every other role).
  Future<void> setRole(String roleKey, String moduleKey, bool allowed) async {
    final prev = _clone();
    (_byRole[roleKey] ??= {})[moduleKey] = allowed;
    notifyListeners();
    try {
      await ApiClient.instance
          .put('/api/settings/$_settingKey', {'value': _byRole});
    } catch (_) {
      _byRole = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Drop a whole role's overrides (when a custom role is removed).
  Future<void> removeRole(String roleKey) async {
    if (!_byRole.containsKey(roleKey)) return;
    final prev = _clone();
    _byRole.remove(roleKey);
    notifyListeners();
    try {
      await ApiClient.instance
          .put('/api/settings/$_settingKey', {'value': _byRole});
    } catch (_) {
      _byRole = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Set the Officer override for one module (preserving every other role).
  Future<void> setOfficer(String moduleKey, bool allowed) =>
      setRole('officer', moduleKey, allowed);
}

/// The editable role columns shown in the Role Access Matrix (settings key
/// 'matrix-roles'). Admin is implicit (always full access) and never listed
/// here; the built-ins (Officer, Resident) are always present, and Admins can
/// append custom roles. Shared with the web matrix.
class MatrixRoles extends ChangeNotifier with ApiStore {
  MatrixRoles._();
  static final MatrixRoles instance = MatrixRoles._();

  static const String _settingKey = 'matrix-roles';
  static const List<String> builtins = ['Officer', 'Resident'];

  List<String> _roles = List.of(builtins);
  List<String> get roles => List.unmodifiable(_roles);

  bool isBuiltin(String role) =>
      builtins.any((b) => b.toLowerCase() == role.toLowerCase());

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/settings/$_settingKey')
        as Map<String, dynamic>;
    final value = j['value'];
    final saved = (value is Map && value['roles'] is List)
        ? (value['roles'] as List).map((e) => '$e').toList()
        : <String>[];
    _roles = saved.isNotEmpty ? saved : List.of(builtins);
    // Built-ins are always present, in front.
    for (final b in builtins.reversed) {
      if (!_roles.any((r) => r.toLowerCase() == b.toLowerCase())) {
        _roles.insert(0, b);
      }
    }
  }

  Future<void> _persist(List<String> prev) async {
    notifyListeners();
    try {
      await ApiClient.instance
          .put('/api/settings/$_settingKey', {'value': {'roles': _roles}});
    } catch (_) {
      _roles = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Add a custom role. Throws [ArgumentError] on a duplicate / reserved name.
  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.toLowerCase() == 'admin' ||
        _roles.any((r) => r.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('That role already exists.');
    }
    final prev = List.of(_roles);
    _roles.add(trimmed);
    await _persist(prev);
  }

  Future<void> remove(String name) async {
    if (isBuiltin(name)) return;
    final prev = List.of(_roles);
    _roles.removeWhere((r) => r.toLowerCase() == name.toLowerCase());
    await _persist(prev);
  }
}

/// Live data behind the Analytics module (GET /api/stats/analytics) — the four
/// KPIs and the four charts, all computed from real records.
class AnalyticsStats extends ChangeNotifier with ApiStore {
  AnalyticsStats._();
  static final AnalyticsStats instance = AnalyticsStats._();

  int residents = 0;
  int certEfficiency = 0;
  int incidentResolutionRate = 0;
  double? satisfactionAvg;

  /// month label → total service requests (certificates + incidents + feedback).
  List<({String label, int total})> monthly = [];
  List<({String type, int n})> incidentByType = [];
  List<({String type, int n})> certByType = [];

  /// Counts for ratings 1..5 (index 0 = 1★).
  List<int> satisfactionByRating = const [0, 0, 0, 0, 0];

  @override
  Future<void> fetch() async {
    final j = await ApiClient.instance.get('/api/stats/analytics')
        as Map<String, dynamic>;
    residents = (j['residents'] as num?)?.toInt() ?? 0;
    certEfficiency = (j['cert_efficiency'] as num?)?.toInt() ?? 0;
    incidentResolutionRate =
        (j['incident_resolution_rate'] as num?)?.toInt() ?? 0;
    satisfactionAvg = (j['satisfaction_avg'] as num?)?.toDouble();
    monthly = [
      for (final m in (j['monthly'] as List? ?? const []))
        (
          label: (m['label'] ?? '') as String,
          total: ((m['certificates'] as num?)?.toInt() ?? 0) +
              ((m['incidents'] as num?)?.toInt() ?? 0) +
              ((m['feedback'] as num?)?.toInt() ?? 0),
        ),
    ];
    incidentByType = [
      for (final r in (j['incident_by_type'] as List? ?? const []))
        (type: (r['type'] ?? '') as String, n: (r['n'] as num?)?.toInt() ?? 0),
    ];
    certByType = [
      for (final r in (j['certificate_by_type'] as List? ?? const []))
        (type: (r['type'] ?? '') as String, n: (r['n'] as num?)?.toInt() ?? 0),
    ];
    final ratings = List<int>.filled(5, 0);
    for (final r in (j['satisfaction_by_rating'] as List? ?? const [])) {
      final rt = (r['rating'] as num?)?.toInt() ?? 0;
      if (rt >= 1 && rt <= 5) ratings[rt - 1] = (r['n'] as num?)?.toInt() ?? 0;
    }
    satisfactionByRating = ratings;
  }
}
