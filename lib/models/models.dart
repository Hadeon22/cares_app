import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';

/// What tapping a service card opens (mirrors openServicePopup on the web).
enum ServiceAction {
  residency,
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
  static List<ServiceItem> get catalog => [
        ServiceItem(
          title: L.text.svcResidency,
          subtitle: L.text.svcResidencySub,
          icon: Icons.holiday_village_outlined,
          action: ServiceAction.residency,
          accent: const Color(0xFF3B82F6), // sc-blue
        ),
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
  });

  final int? id;
  final String title;
  final String body;
  final String tag;
  final DateTime createdAt;

  Color get tagColor =>
      kAnnouncementTagColors[tag] ?? AppColors.royalBlue;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int?,
        title: (json['title'] ?? '') as String,
        body: json['body'] as String? ?? '',
        tag: json['tag'] as String? ?? 'Advisory',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
