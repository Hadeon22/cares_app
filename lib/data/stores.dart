import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────
/// Shared in-app stores mirrored from the web system's
/// localStorage-backed stores (js/audit-log.js, js/feedback-store.js,
/// js/gis-map.js community reports). Swap for the Laravel REST API later.
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

const List<String> kResidentStatuses = ['Active', 'Inactive', 'Deceased'];

/// ── Resident directory (RESIDENTS_DATA in js/shell.js) ──────
class ResidentRecord {
  const ResidentRecord({
    required this.name,
    required this.age,
    required this.purok,
    this.category = '',
    this.status = 'Active',
  });

  final String name; // "Santos, Pedro J."
  final int age;
  final String purok; // "Purok 1"
  final String category; // "" | Senior Citizen | PWD | ...
  final String status; // Active | Inactive | Deceased

  /// Two-letter avatar initials: first name initial + surname initial.
  String get initials {
    final parts = name.split(',');
    final surname = parts[0].trim();
    final first = parts.length > 1 ? parts[1].trim() : '';
    return '${first.isNotEmpty ? first[0] : '?'}${surname.isNotEmpty ? surname[0] : ''}';
  }
}

const List<ResidentRecord> kResidents = [
  ResidentRecord(name: 'Santos, Pedro J.', age: 34, purok: 'Purok 1'),
  ResidentRecord(
      name: 'dela Cruz, Maria L.',
      age: 67,
      purok: 'Purok 2',
      category: 'Senior Citizen'),
  ResidentRecord(
      name: 'Reyes, Jose B.',
      age: 45,
      purok: 'Purok 3',
      category: 'Indigent Family'),
  ResidentRecord(
      name: 'Aquino, Ana M.', age: 29, purok: 'Purok 1', category: 'Solo Parent'),
  ResidentRecord(
      name: 'Bautista, Carlos F.', age: 52, purok: 'Purok 4', category: 'PWD'),
  ResidentRecord(
      name: 'Villanueva, Rosa T.',
      age: 78,
      purok: 'Purok 5',
      category: 'Senior Citizen'),
  ResidentRecord(name: 'Garcia, Luis N.', age: 38, purok: 'Purok 2'),
  ResidentRecord(
      name: 'Mendoza, Elena P.',
      age: 44,
      purok: 'Purok 3',
      category: 'Indigent Family',
      status: 'Inactive'),
  ResidentRecord(name: 'Santos, Juan R.', age: 22, purok: 'Purok 1'),
  ResidentRecord(
      name: 'Cruz, Nora T.',
      age: 61,
      purok: 'Purok 5',
      category: 'Senior Citizen'),
];

/// ── Certificate types (index.html cert-type-grid) ───────────
class CertificateType {
  const CertificateType(this.name, this.shortName);
  final String name;
  final String shortName;
}

const List<CertificateType> kCertificateTypes = [
  CertificateType('Barangay Clearance', 'Barangay Clearance'),
  CertificateType('Certificate of Indigency', 'Certificate of Indigency'),
  CertificateType('Certificate of Residency', 'Certificate of Residency'),
  CertificateType('Business Clearance', 'Business Clearance'),
  CertificateType('Certificate of Good Moral', 'Good Moral Certificate'),
  CertificateType('Certificate of Solo Parent', 'Solo Parent Certificate'),
];

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

/// ── Audit log (js/audit-log.js) ──────────────────────────────
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

  final DateTime ts;
  final String user;
  final String role;
  final String action;
  final String details;
  final AuditLevel level;
  final AuditCategory category;
}

class AuditLog extends ChangeNotifier {
  AuditLog._();
  static final AuditLog instance = AuditLog._();
  static const int _max = 500;

  final List<AuditEntry> _entries = [];
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Session lookup is injected lazily to avoid a circular import.
  String Function()? currentUser;
  String Function()? currentRole;

  void log(String action, String details,
      {AuditLevel level = AuditLevel.info,
      AuditCategory category = AuditCategory.system}) {
    _entries.insert(
      0,
      AuditEntry(
        ts: DateTime.now(),
        user: currentUser?.call() ?? 'Guest',
        role: currentRole?.call() ?? 'Visitor',
        action: action,
        details: details,
        level: level,
        category: category,
      ),
    );
    if (_entries.length > _max) _entries.removeRange(_max, _entries.length);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// ── Feedback store (js/feedback-store.js) ────────────────────
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
    required this.ts,
    required this.rating,
    required this.category,
    required this.comment,
    this.name = 'Anonymous',
    this.contact = '',
    this.isSeed = false,
  });

  final DateTime ts;
  final int rating;
  final String category;
  final String comment;
  final String name;
  final String contact;
  final bool isSeed;
}

class FeedbackStore extends ChangeNotifier {
  FeedbackStore._() {
    _entries.addAll(_seed);
  }
  static final FeedbackStore instance = FeedbackStore._();

  // Baseline sample feedback so the page isn't empty on a fresh install.
  static final List<FeedbackEntry> _seed = [
    FeedbackEntry(
        ts: DateTime(2025, 5, 2),
        rating: 4,
        category: 'Barangay Services',
        comment: 'The clearance process was much faster this time. Keep it up!',
        name: 'Pedro Santos',
        isSeed: true),
    FeedbackEntry(
        ts: DateTime(2025, 5, 1),
        rating: 5,
        category: 'Health Services',
        comment:
            'Free medical mission was very helpful for our community. Thank you!',
        isSeed: true),
    FeedbackEntry(
        ts: DateTime(2025, 4, 30),
        rating: 3,
        category: 'Infrastructure',
        comment:
            'The streetlights in Purok 2 need repair. Several have been broken for months.',
        name: 'Maria dela Cruz',
        isSeed: true),
    FeedbackEntry(
        ts: DateTime(2025, 4, 29),
        rating: 2,
        category: 'Cleanliness',
        comment: 'The garbage collection schedule is inconsistent. Please improve.',
        isSeed: true),
    FeedbackEntry(
        ts: DateTime(2025, 4, 28),
        rating: 5,
        category: 'Officials',
        comment:
            'Very responsive barangay officials. I was helped immediately with my concern.',
        name: 'Jose Reyes',
        isSeed: true),
  ];

  final List<FeedbackEntry> _entries = [];
  List<FeedbackEntry> get all => List.unmodifiable(_entries);

  /// Newly submitted (non-seed) entries — treated as "unreviewed".
  int get unreviewedCount => _entries.where((e) => !e.isSeed).length;

  void add({
    required int rating,
    required String category,
    required String comment,
    String name = '',
    String contact = '',
  }) {
    _entries.insert(
      0,
      FeedbackEntry(
        ts: DateTime.now(),
        rating: rating,
        category: category,
        comment: comment,
        name: name.trim().isEmpty ? 'Anonymous' : name.trim(),
        contact: contact,
      ),
    );
    notifyListeners();
  }
}

/// ── Incident / blotter store (gis-map.js community reports) ──
class IncidentReport {
  IncidentReport({
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
  });

  final String caseNo;
  final String typeKey;
  final String complainant;
  final String narration;
  final DateTime createdAt;
  final String contact;
  final String respondent;
  final String witnesses;
  final String location;

  /// Where the pin was dropped, normalized 0..1 against the GIS map
  /// canvas (mirrors the web's map-unit report coordinates).
  final Offset? mapPoint;
  bool resolved;

  String get typeLabel => incidentTypeByKey(typeKey).label;
}

class IncidentStore extends ChangeNotifier {
  IncidentStore._() {
    _reports.addAll([
      IncidentReport(
        caseNo: 'INC-2025-041',
        typeKey: 'flooding',
        complainant: 'Barangay Patrol',
        narration:
            'Flooding reported at Purok 3 — Sitio Malinis. 14 families affected. '
            'Response team dispatched.',
        location: 'Purok 3 – Sitio Malinis',
        mapPoint: const Offset(0.42, 0.35),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      IncidentReport(
        caseNo: 'INC-2025-040',
        typeKey: 'noise',
        complainant: 'Santos, Pedro J.',
        narration:
            'Loud karaoke past 11 PM near the basketball court. Resolved after '
            'barangay tanod mediation.',
        location: 'Purok 1 – near basketball court',
        mapPoint: const Offset(0.58, 0.62),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        resolved: true,
      ),
    ]);
  }
  static final IncidentStore instance = IncidentStore._();

  final List<IncidentReport> _reports = [];
  int _nextSeq = 42;

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

  IncidentReport file({
    required String typeKey,
    required String complainant,
    required String narration,
    String contact = '',
    String respondent = '',
    String witnesses = '',
    String location = '',
    Offset? mapPoint,
  }) {
    final caseNo =
        'INC-${DateTime.now().year}-${'$_nextSeq'.padLeft(3, '0')}';
    _nextSeq++;
    final report = IncidentReport(
      caseNo: caseNo,
      typeKey: typeKey,
      complainant: complainant,
      narration: narration,
      contact: contact,
      respondent: respondent,
      witnesses: witnesses,
      location: location,
      mapPoint: mapPoint,
      createdAt: DateTime.now(),
    );
    _reports.add(report);
    notifyListeners();
    return report;
  }

  void setResolved(String caseNo, bool resolved) {
    for (final r in _reports) {
      if (r.caseNo == caseNo) r.resolved = resolved;
    }
    notifyListeners();
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
