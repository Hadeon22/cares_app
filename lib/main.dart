import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/offline_queue.dart';
import 'data/push_service.dart';
import 'data/session.dart';
import 'data/stores.dart';
import 'screens/main_shell.dart';
import 'screens/mis/mis_shell.dart';
import 'screens/profile/notifications_screen.dart';

/// Lets a tapped push notification open the Notifications screen from
/// anywhere (PushService has no BuildContext of its own).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore a remembered session ("keep me signed in") and any submissions
  // queued while offline before the first frame.
  await AppSession.instance.restore();
  await OfflineQueue.instance.load();
  // After a queue sync, re-pull the stores so the real server rows (with
  // their CERT-/INC- numbers) replace the queued placeholders.
  OfflineQueue.instance.onSynced = () {
    if (CertificateStore.instance.loaded) CertificateStore.instance.refresh();
    if (IncidentStore.instance.loaded) IncidentStore.instance.refresh();
  };

  // Firebase push. Guarded so the app still runs if Firebase isn't available
  // on this platform (e.g. desktop) or the config is missing.
  try {
    await Firebase.initializeApp();
    PushService.instance.onOpenNotifications = () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    };
    await PushService.instance.init();
    // Remembered session already signed in → register this device now.
    final accountId = AppSession.instance.accountId;
    if (accountId != null) PushService.instance.registerForAccount(accountId);
  } catch (e) {
    debugPrint('Firebase/push init skipped: $e');
  }

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
    return MaterialApp(
      title: 'C.A.R.E.S. · Barangay Conde Labac',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: AppSession.instance,
        builder: (context, _) {
          final session = AppSession.instance;
          final isStaff = session.role?.isStaff ?? false;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: isStaff
                ? const MisShell(key: ValueKey('mis'))
                : const MainShell(key: ValueKey('portal')),
          );
        },
      ),
    );
  }
}
