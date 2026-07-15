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

  // ── Light-section neutrals ───────────────────────────────
  static const Color cream = Color(0xFFFAF7F0); // page background
  static const Color surface = Color(0xFFFFFFFF); // cards on cream
  static const Color ink = Color(0xFF16213A); // headings on light
  static const Color inkMuted = Color(0xFF5A6478); // body on light
  static const Color divider = Color(0xFFE7E2D6);

  // ── Text on navy ─────────────────────────────────────────
  static const Color onNavy = Color(0xFFF4F6FB);
  static const Color onNavyMuted = Color(0xFFAAB6CE);

  // ── Semantic ─────────────────────────────────────────────
  static const Color success = Color(0xFF2E8B57);
  static const Color emergency = flagRed;
}
