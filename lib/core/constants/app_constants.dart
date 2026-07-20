/// Feature flags for modules that are built but not yet exposed.
abstract class AppFeatures {
  /// The MIS "Account Claiming" review module is hidden for now — it still
  /// runs on placeholder claims with an approve action the API does not
  /// implement (claiming is instant, with no pending queue). The page itself
  /// is intact; only its sidebar entry is gated. Flip to `true` to restore it.
  ///
  /// This does NOT affect resident-facing account claiming from the sign-in
  /// screen, which stays available.
  static const bool misAccountClaiming = false;
}

/// Central place for copy, contact details, spacing and motion values.
/// When the Laravel REST API is wired in, most strings here will be
/// replaced by remote data — keep this file thin and declarative.
abstract class AppStrings {
  static const String appAcronym = 'C.A.R.E.S.';
  static const String appFullName = 'Conde Labac Residents System';
  static const String portalBadge = 'OFFICIAL DIGITAL PORTAL · BATANGAS CITY';
  static const String republic = 'Republic of the Philippines';
  static const String hallCaption = 'Barangay Hall · Conde Labac, Batangas City';
  // heroDescription, servicesHeading and servicesSub moved to AppText
  // (core/i18n/app_text.dart) when the Filipino translation landed — they
  // vary by language, so they can't live here as constants.

  static const String hotline = '(043) 702–4011';
  static const String officeHours = 'Mon–Fri · 8:00 AM–5:00 PM';
  static const String address = 'Conde Labac, Batangas City';
  static const String population = '4,800+ residents';
}

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter used across every screen.
  static const double gutter = 20;
}

abstract class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 100;
}

abstract class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 550);
}
