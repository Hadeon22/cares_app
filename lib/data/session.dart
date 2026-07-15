import 'package:flutter/foundation.dart';

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

/// Active session — mirrors the web's `ibmdss.session` localStorage record.
/// Demo credentials follow system.html: each role signs in as a fixed persona.
class AppSession extends ChangeNotifier {
  AppSession._() {
    AuditLog.instance.currentUser =
        () => isSignedIn ? _displayName : 'Guest';
    AuditLog.instance.currentRole =
        () => _role?.label ?? 'Visitor';
  }
  static final AppSession instance = AppSession._();

  UserRole? _role;
  String _displayName = '';
  String _initials = '';
  String _user = '';

  bool get isSignedIn => _role != null;
  UserRole? get role => _role;
  String get displayName => _displayName;
  String get initials => _initials;
  String get user => _user;

  /// First two words of the display name (web: shortName).
  String get shortName =>
      _displayName.split(' ').take(2).join(' ');

  static const _names = {
    UserRole.admin: 'Juan D. Administrator',
    UserRole.officer: 'Maria R. Officer',
    UserRole.resident: 'Pedro S. Santos',
  };
  static const _initialsMap = {
    UserRole.admin: 'JD',
    UserRole.officer: 'MR',
    UserRole.resident: 'PS',
  };

  void signIn(UserRole role, String user) {
    _role = role;
    _displayName = _names[role]!;
    _initials = _initialsMap[role]!;
    _user = user.trim().isEmpty ? 'User' : user.trim();
    AuditLog.instance.log(
      'LOGIN',
      '$_displayName signed in as ${role.label} ($_user)',
      category: AuditCategory.auth,
    );
    notifyListeners();
  }

  void signOut() {
    AuditLog.instance.log(
      'LOGOUT',
      '${_displayName.isEmpty ? "User" : _displayName} signed out',
      category: AuditCategory.auth,
    );
    _role = null;
    _displayName = '';
    _initials = '';
    _user = '';
    notifyListeners();
  }
}
