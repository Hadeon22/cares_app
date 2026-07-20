import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The languages the resident-facing app is offered in. Filipino is the
/// working language of most Conde Labac households; English stays the
/// default because the barangay's official forms are in English.
enum AppLanguage { english, filipino }

/// Shorthand accessor — `L.text.homeTab`.
///
/// Deliberately context-free, matching how [AppColors] is used across the
/// app, so a string can be pulled from anywhere including non-widget code.
abstract class L {
  static AppText get text => LocaleController.instance.text;
  static AppLanguage get lang => LocaleController.instance.language;
}

/// Every resident-facing string, in both languages.
///
/// Written as getters with a ternary rather than a `Map<String, String>` so
/// a missing translation is a compile error instead of a silent fallback to
/// the key. Staff-facing MIS screens are intentionally not translated —
/// barangay personnel are trained on the English module names that match
/// the web system's sidebar.
class AppText {
  const AppText(this.language);

  final AppLanguage language;

  /// True when Filipino strings should be used.
  bool get _f => language == AppLanguage.filipino;

  String get languageName => _f ? 'Filipino' : 'English';

  // ── Navigation ───────────────────────────────────────────────────────
  String get navHome => _f ? 'Home' : 'Home';
  String get navServices => _f ? 'Serbisyo' : 'Services';
  String get navGisMap => _f ? 'Mapa' : 'GIS Map';
  String get navProfile => _f ? 'Profile' : 'Profile';

  // ── Home ─────────────────────────────────────────────────────────────
  String get servicesHeading => _f
      ? 'Paano kayo matutulungan ng barangay ngayon?'
      : 'How can the barangay help you today?';
  String get servicesSub => _f
      ? 'Makipagtransaksyon sa Barangay Conde Labac nang hindi pumipila sa hall.'
      : 'Transact with Barangay Conde Labac without lining up at the hall.';
  String get heroDescription => _f
      ? 'Ang opisyal na serbisyong plataporma ng Barangay Conde Labac — '
          'humiling ng sertipiko, mag-file ng blotter report, tingnan ang '
          'community GIS map, at maabot ang inyong barangay kahit saan.'
      : 'The official service platform of Barangay Conde Labac — request '
          'certificates, file blotter reports, explore the community GIS map, '
          'and reach your barangay from anywhere.';
  String get announcements => _f ? 'Mga Anunsyo' : 'Announcements';
  String get citizenServices => _f ? 'Serbisyo sa Mamamayan' : 'Citizen Services';
  String get chooseService => _f
      ? 'Pumili ng serbisyo upang magsimula.'
      : 'Choose a service to get started.';
  String get noAccountNeeded => _f
      ? 'Hindi kailangan ng account sa karamihan ng serbisyo.'
      : 'No account required for most services.';
  String get seeAll => _f ? 'Lahat' : 'See all';

  // ── Quick info chips ─────────────────────────────────────────────────
  String get infoHotline => _f ? 'Hotline ng Barangay' : 'Barangay Hotline';
  String get infoHours => _f ? 'Oras ng Opisina' : 'Office Hours';
  String get infoAddress => _f ? 'Address' : 'Address';
  String get infoPopulation => _f ? 'Populasyon' : 'Population';

  // ── Services catalog ─────────────────────────────────────────────────
  String get svcResidency => _f ? 'Talaan ng Residente' : 'Barangay Residency';
  String get svcResidencySub => _f
      ? 'Hanapin at tingnan ang mga talaan ng residente at listahan ng purok'
      : 'Search and view resident records and purok listings';
  String get svcCertificates =>
      _f ? 'Paglabas ng Sertipiko' : 'Certificate Issuance';
  String get svcCertificatesSub => _f
      ? 'Humiling ng clearance, indigency, residency at iba pa'
      : 'Request clearances, indigency, residency & more';
  String get svcIncidents => _f ? 'Pag-uulat ng Blotter' : 'Blotter Reporting';
  String get svcIncidentsSub => _f
      ? 'Mag-file ng incident report para sa reklamo o alalahanin'
      : 'File an incident report for complaints or concerns';
  String get svcFeedback => _f ? 'Puna at Mungkahi' : 'Feedback';
  String get svcFeedbackSub => _f
      ? 'Ibahagi ang inyong komento at mungkahi sa serbisyo ng barangay'
      : 'Share comments and suggestions on barangay services';

  // ── Profile ──────────────────────────────────────────────────────────
  String get myInformation => _f ? 'Aking Impormasyon' : 'My Information';
  String get myInformationSub => _f
      ? 'Tingnan ang inyong account at talaan sa barangay'
      : 'View your account & barangay record';
  String get myRequests => _f ? 'Aking mga Hiling' : 'My Requests';
  String get myRequestsSub => _f
      ? 'Subaybayan ang mga sertipiko at clearance'
      : 'Track certificates & clearances';
  String get activityHistory => _f ? 'Kasaysayan ng Aktibidad' : 'Activity History';
  String get activityHistorySub => _f
      ? 'Mga ulat na isinumite at punang ibinigay'
      : 'Reports filed & feedback given';
  String get notifications => _f ? 'Mga Abiso' : 'Notifications';
  String get notificationsSub =>
      _f ? 'Mga advisory at update sa hiling' : 'Advisories & request updates';
  String get helpSupport => _f ? 'Tulong at Suporta' : 'Help & Support';
  String get signOut => _f ? 'Mag-sign Out' : 'Sign Out';
  String get signIn => _f ? 'Mag-sign In' : 'Sign In';
  String get guest => _f ? 'Bisita' : 'Guest';

  // ── Settings ─────────────────────────────────────────────────────────
  String get settings => _f ? 'Mga Setting' : 'Settings';
  String get settingsSub => _f
      ? 'Itsura, wika, abiso at tungkol sa app'
      : 'Appearance, language, notifications & about';

  String get appearance => _f ? 'Itsura' : 'Appearance';
  String get appearanceCaption => _f
      ? 'Pinapanatili ng dark mode ang navy at ginto ng barangay — mas '
          'magaan lang sa mata kapag gabi.'
      : 'Dark mode keeps the barangay navy and gold, just easier on the '
          'eyes at night.';
  String get themeSystem => _f ? 'Sundan ang system' : 'Follow system';
  String get themeSystemSub => _f
      ? 'Tumugma sa setting ng inyong telepono'
      : 'Match your phone\'s display setting';
  String get themeLight => _f ? 'Maliwanag' : 'Light';
  String get themeLightSub =>
      _f ? 'Cream na background, navy na teksto' : 'Cream background, navy text';
  String get themeDark => _f ? 'Madilim' : 'Dark';
  String get themeDarkSub => _f
      ? 'Navy na background, gintong accent'
      : 'Navy background, gold accents';

  String get languageSection => _f ? 'Wika' : 'Language';
  String get languageCaption => _f
      ? 'Nalalapat sa mga screen na nakaharap sa residente. Nananatiling '
          'Ingles ang MIS ng kawani upang tumugma sa web system.'
      : 'Applies to resident-facing screens. The staff MIS stays in English '
          'to match the web system.';
  String get languageChanged => _f ? 'Nakatakda na sa Filipino.' : 'Switched to English.';

  String get security => _f ? 'Seguridad' : 'Security';
  String get changePassword => _f ? 'Palitan ang Password' : 'Change Password';
  String get changePasswordSub => _f
      ? 'Kailangan ang kasalukuyang password'
      : 'Requires your current password';

  String get notificationsGroup => _f ? 'Mga Abiso' : 'Notifications';
  String get notifAdvisories =>
      _f ? 'Mga advisory ng barangay' : 'Barangay advisories';
  String get notifAdvisoriesSub => _f
      ? 'Anunsyo, kalamidad at curfew na abiso'
      : 'Announcements, calamity and curfew notices';
  String get notifRequests => _f ? 'Update sa mga hiling' : 'Request updates';
  String get notifRequestsSub => _f
      ? 'Kapag nagbago ang status ng sertipiko o ulat'
      : 'When a certificate or report changes status';

  String get about => _f ? 'Tungkol Dito' : 'About';
  String get version => _f ? 'Bersyon' : 'Version';
  String get signedInAs => _f ? 'Naka-sign in bilang' : 'Signed in as';

  String turnedOn(String what) => _f ? 'Naka-on ang $what.' : '$what turned on.';
  String turnedOff(String what) =>
      _f ? 'Naka-off ang $what.' : '$what turned off.';

  // ── Change password ──────────────────────────────────────────────────
  String get pwIntro => _f
      ? 'Ilagay muna ang inyong kasalukuyang password. Hindi sapat ang '
          'naka-sign in lamang — pinoprotektahan nito ang inyong account '
          'kung maiwan ang telepono nang nakabukas.'
      : 'Enter your current password first. Being signed in alone is not '
          'enough — this protects your account if your phone is left '
          'unlocked.';
  String get pwCurrent => _f ? 'Kasalukuyang Password' : 'Current Password';
  String get pwCurrentHint =>
      _f ? 'Ang password na ginagamit ninyo ngayon' : 'The password you use now';
  String get pwNew => _f ? 'Bagong Password' : 'New Password';
  String get pwNewHint =>
      _f ? 'Hindi bababa sa 8 karakter' : 'At least 8 characters';
  String get pwConfirm =>
      _f ? 'Kumpirmahin ang Bagong Password' : 'Confirm New Password';
  String get pwConfirmHint =>
      _f ? 'Ilagay muli ang bagong password' : 'Re-enter the new password';
  String get pwSubmit => _f ? 'Palitan ang Password' : 'Change Password';
  String get pwSaving => _f ? 'Sine-save…' : 'Saving…';
  String get pwEnterCurrent =>
      _f ? 'Ilagay ang kasalukuyang password.' : 'Enter your current password.';
  String get pwTooShort => _f
      ? 'Dapat hindi bababa sa 8 karakter ang bagong password.'
      : 'New password must be at least 8 characters.';
  String get pwNoMatch =>
      _f ? 'Hindi magkatugma ang password.' : 'Passwords do not match.';
  String get pwMatches => _f ? 'Magkatugma ang password.' : 'Passwords match.';
  String get pwSameAsOld => _f
      ? 'Dapat iba ang bagong password sa kasalukuyan.'
      : 'New password must be different from the current one.';
  String get pwChanged => _f
      ? 'Napalitan na ang password.'
      : 'Password changed successfully.';
  String get pwWeak => _f ? 'Mahina' : 'Weak';
  String get pwFair => _f ? 'Katamtaman' : 'Fair';
  String get pwStrong => _f ? 'Malakas' : 'Strong';
}

/// Holds the active language, persists it, and notifies the app to rebuild.
/// Mirrors ThemeController so both preferences behave the same way.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const String _key = 'cares.language';

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  AppText _text = const AppText(AppLanguage.english);
  AppText get text => _text;

  /// Loads the saved language. Call before `runApp` so the first frame is
  /// already in the right language.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString(_key) == 'filipino'
          ? AppLanguage.filipino
          : AppLanguage.english;
    } catch (_) {
      _language = AppLanguage.english;
    }
    _text = AppText(_language);
  }

  Future<void> setLanguage(AppLanguage next) async {
    if (next == _language) return;
    _language = next;
    _text = AppText(next);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next.name);
    } catch (_) {
      // A failed write only costs the preference on next launch.
    }
  }
}
