import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Material 3 theme for C.A.R.E.S.
///
/// Typography pairing:
///  • Playfair Display — dignified serif for headlines (mirrors the
///    "How can the barangay help you today?" heading on the web portal)
///  • Manrope — clean geometric sans for UI and body copy
abstract class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        onPrimary: AppColors.onNavy,
        secondary: AppColors.gold,
        onSecondary: AppColors.navyDeep,
        tertiary: AppColors.royalBlue,
        error: AppColors.flagRed,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.cream,
    );

    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,

      // ── AppBar: navy, flat, light status-bar icons ─────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.onNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Filled (gold) buttons ──────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDeep,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),

      // ── Outlined (ghost) buttons on navy ───────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onNavy,
          side: const BorderSide(color: AppColors.navyBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),

      // ── Bottom navigation ──────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navy,
        indicatorColor: AppColors.gold.withOpacity(0.18),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.onNavyMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.onNavyMuted,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final serif = GoogleFonts.playfairDisplayTextTheme(base);
    final sans = GoogleFonts.manropeTextTheme(base);

    return sans.copyWith(
      // Serif reserved for display / headline moments.
      displayLarge: serif.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: serif.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: serif.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium:
          serif.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: serif.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: sans.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: sans.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: sans.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: sans.bodyMedium?.copyWith(height: 1.55),
    );
  }
}
