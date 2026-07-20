import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';

/// Appearance preference (Settings → Appearance), persisted across launches.
///
/// The active brightness is mirrored onto [AppColors.brightness] so the
/// palette getters resolve correctly everywhere — screens keep using
/// `AppColors.ink` and friends without needing a BuildContext.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _key = 'cares.theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Whether dark colours are currently in effect — resolves
  /// [ThemeMode.system] against the OS setting.
  bool get isDark => switch (_mode) {
        ThemeMode.light => false,
        ThemeMode.dark => true,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  /// Human-readable label for the current choice (used on the Profile tile).
  String get label => switch (_mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Follow system',
      };

  /// Loads the saved preference. Call before `runApp` so the first frame
  /// already paints in the right theme (no light-mode flash).
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _mode = ThemeMode.system;
    }

    // Follow the OS toggle live while on "Follow system".
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
      if (_mode == ThemeMode.system) {
        _apply();
        notifyListeners();
      }
    };

    _apply();
  }

  Future<void> setMode(ThemeMode next) async {
    if (next == _mode) return;
    _mode = next;
    _apply();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next.name);
    } catch (_) {
      // A failed write only costs the preference on next launch.
    }
  }

  void _apply() {
    AppColors.brightness = isDark ? Brightness.dark : Brightness.light;
  }
}
