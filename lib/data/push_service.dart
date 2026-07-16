import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'stores.dart';

/// Background isolate handler — required by firebase_messaging, must be a
/// top-level function. Messages that carry a `notification` block are drawn
/// in the system tray by the OS automatically, so there's nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Bridges Firebase Cloud Messaging to the app: asks permission, keeps the
/// device's FCM token registered with the server for the signed-in account,
/// refreshes the in-app feed when a push arrives, and opens the Notifications
/// screen when one is tapped.
///
/// Deliberately does NOT import the session (session imports this instead),
/// so there's no circular dependency — the account id is passed in.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  String? _token;
  int? _registeredAccountId;
  bool _ready = false;

  /// Set by main.dart so a tapped notification can navigate to the feed.
  VoidCallback? onOpenNotifications;

  /// Wire up messaging. Safe to call once at startup; if Firebase isn't
  /// available on this platform it simply stays disabled.
  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    final messaging = FirebaseMessaging.instance;

    // Android 13+ / iOS permission prompt (no-op where not needed).
    await messaging.requestPermission();

    // Foreground push → pull the feed so the bell badge updates live.
    FirebaseMessaging.onMessage.listen((_) {
      NotificationStore.instance.refresh();
    });
    // Tapped while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      NotificationStore.instance.refresh();
      onOpenNotifications?.call();
    });
    // Launched from a tap while terminated.
    final initial = await messaging.getInitialMessage();
    if (initial != null) onOpenNotifications?.call();

    // FCM rotates tokens periodically — re-register when it does.
    messaging.onTokenRefresh.listen((t) {
      _token = t;
      final acct = _registeredAccountId;
      if (acct != null) _register(acct, t);
    });

    _token = await _safeToken();
    _ready = true;
  }

  /// Register this device to receive pushes for [accountId] (call after
  /// sign-in, and at launch for a remembered session).
  Future<void> registerForAccount(int accountId) async {
    if (!_ready) return;
    _registeredAccountId = accountId;
    final token = _token ??= await _safeToken();
    if (token != null) await _register(accountId, token);
  }

  /// Stop pushes to this device (call on sign-out) so the next user of the
  /// phone doesn't receive the previous account's notifications.
  Future<void> unregister() async {
    final token = _token;
    _registeredAccountId = null;
    if (token == null) return;
    try {
      await ApiClient.instance
          .post('/api/notifications/unregister-device', {'token': token});
    } catch (_) {
      /* offline / server down — the token is dropped server-side on next
         send anyway if it becomes invalid */
    }
  }

  Future<String?> _safeToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _register(int accountId, String token) async {
    try {
      await ApiClient.instance.post('/api/notifications/register-device', {
        'account_id': accountId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (_) {
      /* best-effort — retried on next sign-in or token refresh */
    }
  }
}
