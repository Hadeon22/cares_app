import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';

/// What tapping a service card opens (mirrors openServicePopup on the web).
// `residency` is gone: the public resident-directory lookup it opened was
// removed on data-privacy grounds (see ServiceItem.catalog).
enum ServiceAction {
  certificates,
  incidents,
  feedback,
  gis,
  accounts,
}

/// A citizen-facing barangay service (grid item on Home & Services).
/// The six services mirror the web resident portal's services grid
/// (renderResidentPortal in js/shell.js).
class ServiceItem {
  const ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    this.accent = AppColors.royalBlue,
    this.isEmergency = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ServiceAction action;
  final Color accent;
  final bool isEmergency;

  /// Built per-call rather than held as a `const` list, because the titles
  /// come from [L] and must follow the language toggle in Settings.
  /// GIS Map and Account Claiming are reachable from the GIS tab and the
  /// sign-in screen respectively, so they're not repeated here.
  ///
  /// Barangay Residency is deliberately absent: it opened a lookup over the
  /// whole resident directory — names, ages, puroks and the senior / PWD /
  /// solo parent / indigent classifications — to any signed-in resident. That
  /// is personal (and for the classifications, sensitive) information under
  /// RA 10173, and no resident has a basis to see another's record. Residents
  /// read their own details under My Information; staff use MIS → Barangay
  /// Residency.
  static List<ServiceItem> get catalog => [
        ServiceItem(
          title: L.text.svcCertificates,
          subtitle: L.text.svcCertificatesSub,
          icon: Icons.description_outlined,
          action: ServiceAction.certificates,
          accent: AppColors.goldDeep, // sc-gold
        ),
        ServiceItem(
          title: L.text.svcIncidents,
          subtitle: L.text.svcIncidentsSub,
          icon: Icons.campaign_outlined,
          action: ServiceAction.incidents,
          accent: AppColors.flagRed, // sc-red
        ),
        ServiceItem(
          title: L.text.svcFeedback,
          subtitle: L.text.svcFeedbackSub,
          icon: Icons.chat_bubble_outline,
          action: ServiceAction.feedback,
          accent: AppColors.success, // sc-green
        ),
      ];
}

/// A quick-info chip (hotline, hours, address, population).
class InfoItem {
  const InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Labels follow the language toggle; the values are numbers and proper
  /// nouns, so they stay identical in both languages.
  static List<InfoItem> get items => [
        InfoItem(
          label: L.text.infoHotline,
          value: AppStrings.hotline,
          icon: Icons.call_outlined,
        ),
        InfoItem(
          label: L.text.infoHours,
          value: AppStrings.officeHours,
          icon: Icons.schedule_outlined,
        ),
        InfoItem(
          label: L.text.infoAddress,
          value: AppStrings.address,
          icon: Icons.location_on_outlined,
        ),
        InfoItem(
          label: L.text.infoPopulation,
          value: AppStrings.population,
          icon: Icons.diversity_3_outlined,
        ),
      ];
}

/// Allowed announcement tags → chip color (kept in sync with the TAGS list
/// in the server's routes/announcements.js).
const Map<String, Color> kAnnouncementTagColors = {
  'Advisory': AppColors.goldDeep,
  'Health': AppColors.success,
  'Community': AppColors.royalBlue,
  'Event': Color(0xFF8B5CF6),
  'Emergency': AppColors.flagRed,
};

/// A community announcement card (announcement table, /api/announcements).
class Announcement {
  const Announcement({
    this.id,
    required this.title,
    required this.body,
    required this.tag,
    required this.createdAt,
    this.expiresAt,
    this.expiresTime,
    this.expired = false,
  });

  final int? id;
  final String title;
  final String body;
  final String tag;
  final DateTime createdAt;

  /// Optional take-down date as `YYYY-MM-DD`, or null for "stays up until
  /// removed". The post is live until the END of this day, so a notice for
  /// "the assembly on the 14th" is still up on the 14th.
  ///
  /// The public feed already filters expired posts out server-side, so the
  /// resident-facing screens never see one. It is carried here for the MIS
  /// Site Content editor, which asks for `?include_expired=1` precisely so
  /// staff can re-date a post that has come down.
  final String? expiresAt;

  /// Optional time of day for the take-down, as 24-hour `HH:MM`, or null /
  /// empty for "the end of that day". Only meaningful alongside [expiresAt].
  ///
  /// Most notices come down on a date and nobody wants to pick an hour to say
  /// so; a time is for the ones that stop being true partway through a day —
  /// a brown-out until 5 PM, a deadline at noon.
  final String? expiresTime;

  /// Server-computed: this post is past its take-down date. Only ever true on
  /// rows fetched with `include_expired=1`.
  final bool expired;

  Color get tagColor =>
      kAnnouncementTagColors[tag] ?? AppColors.royalBlue;

  /// The moment the post comes down, or null for "stays up until removed".
  /// Without a time it is the END of the take-down date — a notice for "the
  /// assembly on the 14th" is still up on the 14th. Mirrors the server's rule
  /// in routes/announcements.js.
  DateTime? get expiryEnd {
    final raw = expiresAt;
    if (raw == null || raw.isEmpty) return null;
    final t = expiresTime;
    return (t == null || t.isEmpty)
        ? DateTime.tryParse('${raw}T23:59:59')
        : DateTime.tryParse('${raw}T$t:00');
  }

  /// `14:30` → `2:30 PM`. Nobody reads a barangay notice board in 24-hour time.
  static String formatExpiryTime(String? t) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(t ?? '');
    if (m == null) return '';
    final h = int.parse(m.group(1)!);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
  }

  /// Plain-language state of the expiry, for the Site Content editor. A raw
  /// date does not tell a reader whether the post is currently visible.
  String get expiryNote {
    final end = expiryEnd;
    if (end == null) {
      final raw = expiresAt;
      return (raw == null || raw.isEmpty)
          ? 'Stays up until removed'
          : 'Take-down date: $raw';
    }
    final now = DateTime.now();
    if (end.isBefore(now)) return 'Expired — no longer on the public bulletin';
    // Counted date-to-date, not in elapsed hours: "comes down in 8 hours" at
    // 9 AM means today, which rounding the hours would have called tomorrow.
    final days = DateTime(end.year, end.month, end.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final at = (expiresTime == null || expiresTime!.isEmpty)
        ? ''
        : ' at ${formatExpiryTime(expiresTime)}';
    if (days <= 0) {
      return at.isEmpty ? 'Comes down at the end of today' : 'Comes down$at';
    }
    if (days == 1) return 'Comes down tomorrow$at';
    return 'Comes down in $days days$at';
  }

  Announcement copyWith({
    String? title,
    String? body,
    String? tag,
    String? expiresAt,
    String? expiresTime,
    bool clearExpiry = false,
  }) =>
      Announcement(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        tag: tag ?? this.tag,
        createdAt: createdAt,
        expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
        // The time goes with the date it belongs to.
        expiresTime: clearExpiry ? null : (expiresTime ?? this.expiresTime),
        // Clearing the date puts the post back up immediately.
        expired: clearExpiry ? false : expired,
      );

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int?,
        title: (json['title'] ?? '') as String,
        body: json['body'] as String? ?? '',
        tag: json['tag'] as String? ?? 'Advisory',
        expiresAt: json['expires_at'] as String?,
        expiresTime: json['expires_time'] as String?,
        expired: json['expired'] == true,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
