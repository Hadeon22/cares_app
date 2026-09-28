import 'package:flutter/material.dart';

import 'core/i18n/app_text.dart';
import 'core/theme/app_theme.dart';
import 'data/offline_queue.dart';
import 'data/session.dart';
import 'data/stores.dart';
import 'data/theme_controller.dart';
import 'screens/main_shell.dart';
import 'widgets/pull_to_refresh.dart';
import 'screens/mis/mis_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore a remembered session ("keep me signed in") and any submissions
  // queued while offline before the first frame.
  await AppSession.instance.restore();
  // Before the first frame, so the app never flashes the wrong theme or
  // language and then repaints.
  await ThemeController.instance.restore();
  await LocaleController.instance.restore();
  await OfflineQueue.instance.load();
  // After a queue sync, re-pull the stores so the real server rows (with
  // their CERT-/INC- numbers) replace the queued placeholders.
  OfflineQueue.instance.onSynced = () {
    if (CertificateStore.instance.loaded) CertificateStore.instance.refresh();
    if (IncidentStore.instance.loaded) IncidentStore.instance.refresh();
  };

  // The Role Access Matrix decides which shell a signed-in staff account even
  // gets (see CaresApp below), so ask for it as early as the session itself.
  // Not awaited: the built-in defaults are correct for a fresh install, and a
  // slow network must not hold up the first frame.
  if (AppSession.instance.isSignedIn) ModuleAccess.instance.ensureLoaded();

  runApp(const CaresApp());
  // Try to push anything still queued from the last run (no-op if offline).
  OfflineQueue.instance.flush();
}

/// C.A.R.E.S. — Conde Labac Residents System
/// Official mobile portal of Barangay Conde Labac, Batangas City.
///
/// Routing mirrors the web system: visitors and Residents get the
/// public portal (index.html), while Admin/Officer staff land on the
/// MIS dashboard (pages/dashboard.html).
class CaresApp extends StatelessWidget {
  const CaresApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the resolved theme is handed to MaterialApp — not theme +
    // darkTheme + themeMode. AppTheme reads the AppColors palette getters,
    // which resolve against a single global brightness, so building both
    // variants eagerly would leave them identical. ThemeController sets that
    // brightness, then we build the one theme that matches it.
    return AnimatedBuilder(
      // Both preferences rebuild the whole app: the theme swaps the palette,
      // the language swaps every resident-facing string.
      animation: Listenable.merge(
          [ThemeController.instance, LocaleController.instance]),
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        return MaterialApp(
          title: 'C.A.R.E.S. · Barangay Conde Labac',
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          // Catch up with the web system every time the app returns to the
          // foreground, so a request approved (or a certificate filled in) at
          // the barangay hall is already current when the phone is picked up.
          home: RefreshOnResume(
            child: AnimatedBuilder(
              // ModuleAccess joins the session here because "is this person
              // staff?" is no longer the whole question: the Role Access
              // Matrix's MIS Access row decides whether a staff role gets the
              // MIS at all, and revoking it should land them on the portal.
              animation: Listenable.merge(
                  [AppSession.instance, ModuleAccess.instance]),
              builder: (context, _) {
                final session = AppSession.instance;
                final isStaff = session.role?.isStaff ?? false;
                final mis = isStaff &&
                    ModuleAccess.instance.canOpenMis(session.role?.name);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: mis
                      ? const MisShell(key: ValueKey('mis'))
                      : const MainShell(key: ValueKey('portal')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
