import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../gis/gis_data.dart';
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
        createdAt: _parseTs(j['created_at']),
      );

  final int id;
  final String requestNo;
  final String applicant;
  final String typeKey;
  final String purpose;
  String status; // pending | approved | issued | rejected

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

  /// Move a request through the pipeline (approve / issue / reject).
  Future<void> setStatus(CertificateRequest r, String status,
      {String? remarks, int? accountId}) async {
    final prev = r.status;
    r.status = status; // optimistic — revert on failure
    notifyListeners();
    try {
      await ApiClient.instance.patch('/api/certificates/${r.id}', {
        'status': status,
        if (remarks != null) 'remarks': remarks,
        if (accountId != null) 'account_id': accountId,
      });
    } catch (_) {
      r.status = prev;
      notifyListeners();
      rethrow;
    }
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

const List<IncidentType> kIncidentTypes = [
  IncidentType('noise', 'Noise Complaint'),
  IncidentType('dispute', 'Property Dispute', interpersonal: true),
  IncidentType('altercation', 'Physical Altercation', interpersonal: true),
  IncidentType('theft', 'Theft / Robbery', interpersonal: true),
  IncidentType('vandalism', 'Vandalism'),
  IncidentType('domestic', 'Domestic Disturbance', interpersonal: true),
  IncidentType('flooding', 'Flooding / Natural Hazard'),
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
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        ts: _parseTs(j['created_at']),
        user: (j['actor'] ?? 'System') as String,
        role: (j['role'] ?? 'System') as String,
        action: (j['action'] ?? '') as String,
        details: (j['details'] ?? '') as String? ?? '',
        level: AuditLevel.values.asNameMap()[j['level']] ?? AuditLevel.info,
        category: _auditCategoryFrom(j['category'] as String?),
      );

  final DateTime ts;
  final String user;
  final String role;
  final String action;
  final String details;
  final AuditLevel level;
  final AuditCategory category;
}

/// Mirrors js/audit-log.js. log() records locally right away (so the UI is
/// instant) AND pushes the entry to POST /api/audit so the shared DB trail
/// gets it too; ensureLoaded()/refresh() pull the full server-side trail
/// (which also contains the web system's entries + DB trigger rows).
class AuditLog extends ChangeNotifier with ApiStore {
  AuditLog._();
  static final AuditLog instance = AuditLog._();
  static const int _max = 500;

  final List<AuditEntry> _entries = [];
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Session lookups are injected lazily to avoid a circular import.
  String Function()? currentUser;
  String Function()? currentRole;
  int? Function()? currentAccountId;

  @override
  Future<void> fetch() async {
    final rows =
        await ApiClient.instance.get('/api/audit', query: {'limit': '200'})
            as List;
    _entries
      ..clear()
      ..addAll(
          rows.map((r) => AuditEntry.fromJson(r as Map<String, dynamic>)));
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

  /// Clears the local view only — the DB trail is append-only by design.
  void clear() {
    _entries.clear();
    notifyListeners();
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

/// ── Barangay officials (js/site-config.js defaults) ──────────
class Official {
  const Official({
    required this.name,
    required this.role,
    required this.desc,
    this.honorific = 'Hon.',
  });

  final String honorific;
  final String name;
  final String role;
  final String desc;

  String get displayName => '$honorific $name';

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

const List<Official> kOfficials = [
  Official(
    name: 'Juan Dela Cruz',
    role: 'Punong Barangay',
    desc: 'Leads the barangay administration and community programs.',
  ),
  Official(
    name: 'Maria Santos',
    role: 'Kagawad — Public Safety',
    desc: 'Oversees public safety, peace and order, and disaster response.',
  ),
  Official(
    name: 'Pedro Reyes',
    role: 'Kagawad — Health & Sanitation',
    desc: 'Manages health programs, sanitation, and community welfare.',
  ),
];
