import 'package:flutter/material.dart';

/// Official C.A.R.E.S. brand palette — derived from the
/// Barangay Conde Labac seal (navy, gold, royal blue, red).
abstract class AppColors {
  // ── Primary navy family ──────────────────────────────────
  static const Color navyDeep = Color(0xFF081426); // darkest backdrop
  static const Color navy = Color(0xFF0B1D3A); // primary surface (hero)
  static const Color navyLight = Color(0xFF13294B); // elevated navy cards
  static const Color navyBorder = Color(0xFF1E3A66); // hairline on navy

  // ── Gold family ──────────────────────────────────────────
  static const Color gold = Color(0xFFFFC72C); // CTA / brand accent
  static const Color goldDeep = Color(0xFFB8860B); // pressed / dark gold
  static const Color goldSoft = Color(0xFFFFF3D1); // gold-tinted chip bg

  // ── Seal accents ─────────────────────────────────────────
  static const Color royalBlue = Color(0xFF1E4FBF);
  static const Color flagRed = Color(0xFFC8102E);

  // ── Theme-dependent neutrals ─────────────────────────────
  // These five resolve against [brightness] so the whole app follows the
  // Settings → Appearance choice without every call site needing a
  // BuildContext. The brand colours above never change between themes.
  //
  // Dark mode reuses the navy family rather than neutral greys, so it reads
  // as the same government brand with the lights off — effectively the hero
  // section extended across the app.
  static Brightness brightness = Brightness.light;
  static bool get isDark => brightness == Brightness.dark;

  /// Page background.
  static Color get cream => isDark ? _darkBg : _cream;

  /// Cards sitting on [cream].
  static Color get surface => isDark ? _darkSurface : _surface;

  /// Headings.
  static Color get ink => isDark ? _darkInk : _ink;

  /// Body / secondary copy.
  static Color get inkMuted => isDark ? _darkInkMuted : _inkMuted;

  /// Hairline borders and separators.
  static Color get divider => isDark ? _darkBorder : _divider;

  // Light values
  static const Color _cream = Color(0xFFFAF7F0);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF16213A);
  static const Color _inkMuted = Color(0xFF5A6478);
  static const Color _divider = Color(0xFFE7E2D6);

  // Dark values — navy-family, tuned so cards lift off the background and
  // body copy still clears WCAG AA against it.
  static const Color _darkBg = Color(0xFF060E1B);
  static const Color _darkSurface = Color(0xFF0E2039);
  static const Color _darkInk = Color(0xFFEDF1F9);
  static const Color _darkInkMuted = Color(0xFF9FADC7);
  static const Color _darkBorder = Color(0xFF233D68);

  // ── Text on navy ─────────────────────────────────────────
  static const Color onNavy = Color(0xFFF4F6FB);
  static const Color onNavyMuted = Color(0xFFAAB6CE);

  // ── Semantic ─────────────────────────────────────────────
  static const Color success = Color(0xFF2E8B57);
  static const Color emergency = flagRed;
}
