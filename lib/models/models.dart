import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

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

  static const List<ServiceItem> catalog = [
    ServiceItem(
      title: 'Barangay Residency',
      subtitle: 'Search and view resident records and purok listings',
      icon: Icons.holiday_village_outlined,
      action: ServiceAction.residency,
      accent: Color(0xFF3B82F6), // sc-blue
    ),
    ServiceItem(
      title: 'Certificate Issuance',
      subtitle: 'Request clearances, indigency, residency & more',
      icon: Icons.description_outlined,
      action: ServiceAction.certificates,
      accent: AppColors.goldDeep, // sc-gold
    ),
    ServiceItem(
      title: 'Blotter Reporting',
      subtitle: 'File an incident report for complaints or concerns',
      icon: Icons.campaign_outlined,
      action: ServiceAction.incidents,
      accent: AppColors.flagRed, // sc-red
    ),
    ServiceItem(
      title: 'Feedback',
      subtitle: 'Share comments and suggestions on barangay services',
      icon: Icons.chat_bubble_outline,
      action: ServiceAction.feedback,
      accent: AppColors.success, // sc-green
    ),
    // GIS Map and Account Claiming are reachable from the GIS tab and
    // the sign-in screen respectively, so they're not repeated here.
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

  static const List<InfoItem> items = [
    InfoItem(
      label: 'Barangay Hotline',
      value: AppStrings.hotline,
      icon: Icons.call_outlined,
    ),
    InfoItem(
      label: 'Office Hours',
      value: AppStrings.officeHours,
      icon: Icons.schedule_outlined,
    ),
    InfoItem(
      label: 'Address',
      value: AppStrings.address,
      icon: Icons.location_on_outlined,
    ),
    InfoItem(
      label: 'Population',
      value: AppStrings.population,
      icon: Icons.diversity_3_outlined,
    ),
  ];
}

/// A community announcement card.
class Announcement {
  const Announcement({
    required this.title,
    required this.body,
    required this.date,
    required this.tag,
    this.tagColor = AppColors.royalBlue,
  });

  final String title;
  final String body;
  final String date;
  final String tag;
  final Color tagColor;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        date: json['date'] as String? ?? '',
        tag: json['tag'] as String? ?? 'Advisory',
      );

  /// Placeholder data — replace with `GET /api/announcements`.
  static const List<Announcement> latest = [
    Announcement(
      title: 'Free Anti-Rabies Vaccination Drive',
      body: 'Bring your pets to the covered court this Saturday, '
          '8:00 AM–12:00 NN. First 150 pets only.',
      date: 'Jul 9, 2026',
      tag: 'Health',
      tagColor: AppColors.success,
    ),
    Announcement(
      title: 'Scheduled Power Interruption',
      body: 'BATELEC II advises a scheduled maintenance outage on '
          'Jul 14, 9:00 AM–3:00 PM affecting Purok 2 & 3.',
      date: 'Jul 8, 2026',
      tag: 'Advisory',
      tagColor: AppColors.goldDeep,
    ),
    Announcement(
      title: 'Barangay Assembly — 3rd Quarter',
      body: 'All residents are invited to the quarterly assembly at the '
          'Barangay Hall grounds on Jul 26, 4:00 PM.',
      date: 'Jul 5, 2026',
      tag: 'Community',
    ),
  ];
}
