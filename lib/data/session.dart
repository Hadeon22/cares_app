import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'push_service.dart';
import 'resident_profile.dart';
import 'stores.dart';

/// User roles mirrored from the web system (js/shell.js).
enum UserRole { admin, officer, resident }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.officer:
        return 'Officer';
      case UserRole.resident:
        return 'Resident';
    }
  }

  /// Long-form label shown under the user's name (web: nav-user-role).
  String get title {
    switch (this) {
      case UserRole.admin:
        return 'System Admin';
      case UserRole.officer:
        return 'Barangay Officer';
      case UserRole.resident:
        return 'Resident';
    }
  }

  bool get isStaff => this != UserRole.resident;
}

/// Active session — mirrors the web's `ibmdss.session` localStorage record,
/// but signed in for real against POST /api/auth/login (the same accounts
/// table the web system uses).
class AppSession extends ChangeNotifier {
  AppSession._() {
    AuditLog.instance.currentUser =
        () => isSignedIn ? _displayName : 'Guest';
    AuditLog.instance.currentRole =
        () => _role?.label ?? 'Visitor';
    AuditLog.instance.currentAccountId = () => _accountId;
    NotificationStore.instance.currentAccountId = () => _accountId;
  }
  static final AppSession instance = AppSession._();

  UserRole? _role;
  String _serverRole = '';
  String _displayName = '';
  String _initials = '';
  String _user = '';
  int? _accountId;
  int? _residentId;

  bool get isSignedIn => _role != null;
  UserRole? get role => _role;

  /// The exact role string from the account table
  /// (Admin / Officer / Staff / Viewer / Resident).
  String get serverRole => _serverRole;
  String get displayName => _displayName;
  String get initials => _initials;
  String get user => _user;
  int? get accountId => _accountId;
  int? get residentId => _residentId;

  /// First two words of the display name (web: shortName).
  String get shortName =>
      _displayName.split(' ').take(2).join(' ');

  /// account.role → the app's three-way role. Staff/Viewer get the Officer
  /// experience (MIS access without admin-only pages), same as the web.
  static UserRole _mapRole(String role) {
    switch (role) {
      case 'Admin':
        return UserRole.admin;
      case 'Officer':
      case 'Staff':
      case 'Viewer':
        return UserRole.officer;
      default:
        return UserRole.resident;
    }
  }

  /// "Santos, Pedro J." or "Pedro Santos" → "PS".
  static String _deriveInitials(String name) {
    if (name.contains(',')) {
      final parts = name.split(',');
      final surname = parts[0].trim();
      final first = parts.length > 1 ? parts[1].trim() : '';
      return '${first.isNotEmpty ? first[0] : '?'}'
              '${surname.isNotEmpty ? surname[0] : ''}'
          .toUpperCase();
    }
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  static const _prefsKey = 'cares.session';

  /// Real login against the shared PostgreSQL accounts table.
  /// Throws [ApiException] with a user-showable message on failure.
  /// With [remember] the session is saved locally, so reopening the app
  /// signs the account back in without asking for the password again.
  Future<void> signIn(String email, String password,
      {bool remember = false}) async {
    final res = await ApiClient.instance.post('/api/auth/login', {
      'username': email.trim(),
      'password': password,
    }) as Map<String, dynamic>;

    _serverRole = (res['role'] as String?) ?? 'Resident';
    _role = _mapRole(_serverRole);
    _displayName = (res['name'] as String?) ?? email.trim();
    _initials = _deriveInitials(_displayName);
    _user = (res['username'] as String?) ?? email.trim();
    _accountId = res['account_id'] as int?;
    _residentId = res['resident_id'] as int?;

    if (remember) unawaited(_persist());

    // Register this phone for push under the new account.
    final acct = _accountId;
    if (acct != null) unawaited(PushService.instance.registerForAccount(acct));

    // Warm the offline cache with the resident's own record so "My
    // Information" and the certificate auto-fill work without internet.
    final rid = _residentId;
    if (rid != null) {
      unawaited(() async {
        try {
          await ResidentProfile.fetch(rid);
        } catch (_) {}
      }());
    }

    AuditLog.instance.log(
      'LOGIN',
      '$_displayName signed in as $_serverRole ($_user)',
      category: AuditCategory.auth,
    );
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          jsonEncode({
            'role': _serverRole,
            'name': _displayName,
            'user': _user,
            'account_id': _accountId,
            'resident_id': _residentId,
          }));
    } catch (_) {
      /* best-effort — worst case the user signs in again next launch */
    }
  }

  /// Restore a remembered session at app launch (before runApp).
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _serverRole = (j['role'] as String?) ?? 'Resident';
      _role = _mapRole(_serverRole);
      _displayName = (j['name'] as String?) ?? '';
      _initials = _deriveInitials(_displayName);
      _user = (j['user'] as String?) ?? '';
      _accountId = j['account_id'] as int?;
      _residentId = j['resident_id'] as int?;
      notifyListeners();
    } catch (_) {
      /* unreadable session — start signed out */
    }
  }

  /// Offline sign-in for widget tests — sets session state without the API.
  @visibleForTesting
  void debugSignIn(UserRole role, String displayName, String email) {
    _role = role;
    _serverRole = role.label;
    _displayName = displayName;
    _initials = _deriveInitials(displayName);
    _user = email;
    notifyListeners();
  }

  void signOut() {
    AuditLog.instance.log(
      'LOGOUT',
      '${_displayName.isEmpty ? "User" : _displayName} signed out',
      category: AuditCategory.auth,
    );
    // Stop pushes to this device for the account that's leaving.
    unawaited(PushService.instance.unregister());

    // Forget the remembered session and this resident's cached record.
    final rid = _residentId;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
        if (rid != null) await prefs.remove('cares.profile.$rid');
      } catch (_) {}
    }());
    _role = null;
    _serverRole = '';
    _displayName = '';
    _initials = '';
    _user = '';
    _accountId = null;
    _residentId = null;
    NotificationStore.instance.reset();
    notifyListeners();
  }
}
