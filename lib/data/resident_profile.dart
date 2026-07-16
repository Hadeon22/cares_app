import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'stores.dart' show kClassificationLabels;

/// Full resident record from GET /api/residents/:id — the same payload the
/// web's View-Resident modal renders. Used by the profile "My Information"
/// view, the certificate auto-fill and the MIS residency View sheet.
class ResidentProfile {
  const ResidentProfile({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName,
    this.suffix,
    this.birthdate,
    this.age,
    this.sex,
    this.civilStatus,
    this.relationshipToHead,
    this.contactNo,
    this.occupation,
    this.voterStatus,
    this.lifecycleStatus = 'active',
    this.accountClaimed = false,
    this.dateRegistered,
    this.householdNo,
    this.addressText,
    this.purok,
    this.classifications = const [],
  });

  factory ResidentProfile.fromJson(Map<String, dynamic> j) => ResidentProfile(
        id: j['resident_id'] as int,
        lastName: (j['last_name'] ?? '') as String,
        firstName: (j['first_name'] ?? '') as String,
        middleName: j['middle_name'] as String?,
        suffix: j['suffix'] as String?,
        birthdate: DateTime.tryParse(j['birthdate']?.toString() ?? ''),
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex'] as String?,
        civilStatus: j['civil_status'] as String?,
        relationshipToHead: j['relationship_to_head'] as String?,
        contactNo: j['contact_no'] as String?,
        occupation: j['occupation'] as String?,
        voterStatus: j['voter_status'] as String?,
        lifecycleStatus: (j['status'] ?? 'active') as String,
        accountClaimed: j['account_claimed'] == true,
        dateRegistered:
            DateTime.tryParse(j['date_registered']?.toString() ?? ''),
        householdNo: j['household_no'] as String?,
        addressText: j['address_text'] as String?,
        purok: j['purok'] as String?,
        classifications: [
          for (final c in (j['classifications'] as List? ?? const []))
            kClassificationLabels[c] ?? c.toString(),
        ],
      );

  /// Network fetch with an offline fallback: every successful load is cached
  /// locally, and when the server is unreachable the cached copy (saved at
  /// login or on any earlier view) is returned instead.
  static Future<ResidentProfile> fetch(int residentId) async {
    final cacheKey = 'cares.profile.$residentId';
    try {
      final j = await ApiClient.instance.get('/api/residents/$residentId')
          as Map<String, dynamic>;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(j));
      } catch (_) {
        /* caching is best-effort */
      }
      return ResidentProfile.fromJson(j);
    } on ApiException catch (e) {
      if (e.statusCode != 0) rethrow; // real server answer (404 etc.)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return ResidentProfile.fromJson(
              (jsonDecode(cached) as Map).cast<String, dynamic>());
        }
      } catch (_) {}
      rethrow;
    }
  }

  final int id;
  final String lastName;
  final String firstName;
  final String? middleName;
  final String? suffix;
  final DateTime? birthdate;
  final int? age;
  final String? sex;
  final String? civilStatus;
  final String? relationshipToHead;
  final String? contactNo;
  final String? occupation;
  final String? voterStatus;
  final String lifecycleStatus; // active | deceased | moved | archived
  final bool accountClaimed;
  final DateTime? dateRegistered;
  final String? householdNo;
  final String? addressText;
  final String? purok;
  final List<String> classifications; // display labels

  /// "Santos, Pedro J. Jr." — middle name always as an initial (web rule).
  String get fullName =>
      '$lastName, $firstName'
      '${(middleName ?? '').isNotEmpty ? ' ${middleName![0]}.' : ''}'
      '${(suffix ?? '').isNotEmpty ? ' $suffix' : ''}';

  String get sexLabel =>
      sex == 'M' ? 'Male' : sex == 'F' ? 'Female' : '—';
}
