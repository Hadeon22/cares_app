# C.A.R.E.S. Mobile — Conde Labac Residents System

A mobile-first Flutter (3.x, Material 3, null-safe) redesign of the official
C.A.R.E.S. web portal of **Barangay Conde Labac, Batangas City**, preserving
the navy-and-gold government branding.

## Getting started

```bash
flutter pub get
flutter run
```

Optional brand assets (the UI shows branded placeholders if missing):

```
assets/images/barangay_hall.jpg   # Barangay Hall photo from the web hero
assets/images/barangay_seal.png   # Official barangay seal
```

## Project structure

```
lib/
├── main.dart                  # Entry point + MaterialApp
├── core/
│   ├── constants/
│   │   ├── app_colors.dart    # Brand palette (navy, gold, royal blue, red)
│   │   └── app_constants.dart # Copy, spacing, radii, motion durations
│   ├── theme/
│   │   └── app_theme.dart     # Material 3 theme, Playfair Display + Manrope
│   └── utils/
│       └── fade_slide.dart    # Reusable staggered entrance animation
├── models/
│   └── models.dart            # ServiceItem, InfoItem, Announcement (+fromJson)
├── widgets/
│   ├── common.dart            # SectionHeader, SealBadge, PortalBadge
│   ├── hero_section.dart      # Navy hero with CTAs
│   ├── barangay_hall_card.dart
│   ├── info_card_row.dart     # Horizontal hotline/hours/address/population
│   ├── service_card.dart      # Grid tile with ripple + press scale
│   ├── gis_banner.dart        # Featured GIS banner (CustomPaint map sketch)
│   └── announcement_card.dart
└── screens/
    ├── main_shell.dart        # AppBar + NavigationBar + AnimatedSwitcher
    ├── home_screen.dart
    ├── services_screen.dart
    ├── gis_map_screen.dart    # Placeholder ready for flutter_map / WebView
    └── profile_screen.dart
```

## Design notes

- **Branding** — deep navy `#0B1D3A`, gold `#FFC72C`, royal blue and flag
  red accents lifted from the barangay seal; cream `#FAF7F0` light sections
  mirror the web portal's two-tone layout.
- **Typography** — Playfair Display (serif headlines, matching the portal's
  "How can the barangay help you today?") paired with Manrope for UI/body.
- **Motion** — staggered `FadeSlide` entrances, `AnimatedSwitcher` tab
  cross-fades, `AnimatedScale` press feedback, `Hero`-ready wordmark, and
  Material ripples throughout. Everything stays under ~550 ms so the app
  feels responsive, not showy.
- **Responsive** — service grid switches 2 → 3 columns past 560 px; info
  cards scroll horizontally; all text scales with system font size.

## Laravel REST API integration (next step)

The models already expose `fromJson` factories. Suggested wiring:

1. Add `dio` or `http` and create `lib/core/network/api_client.dart`
   pointing at your Laravel base URL.
2. Create repositories (e.g. `ServiceRepository`, `AnnouncementRepository`)
   that map `GET /api/services` and `GET /api/announcements` to the models.
3. Swap the static `ServiceItem.catalog` / `Announcement.latest` lists for
   `FutureBuilder`s (or Riverpod/Bloc) fed by those repositories.
4. For GIS, embed the existing web map in `gis_map_screen.dart` via
   `webview_flutter`, or render layers natively with `flutter_map`.
