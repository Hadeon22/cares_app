import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// One submission captured while offline, waiting to be POSTed.
class QueuedSubmission {
  QueuedSubmission({
    required this.kind,
    required this.path,
    required this.body,
    required this.createdAt,
  });

  factory QueuedSubmission.fromJson(Map<String, dynamic> j) =>
      QueuedSubmission(
        kind: (j['kind'] ?? '') as String,
        path: (j['path'] ?? '') as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String kind; // 'certificate' | 'incident'
  final String path; // POST target, e.g. /api/certificates
  final Map<String, dynamic> body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'path': path,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Persistent store-and-forward queue: requests filed while offline are
/// saved here (shared_preferences) and automatically POSTed once the
/// server is reachable again. While offline it keeps pinging /api/health
/// so both the sync and the shell's offline banner recover on their own.
class OfflineQueue extends ChangeNotifier {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _prefsKey = 'cares.offline_queue';

  final List<QueuedSubmission> _items = [];
  List<QueuedSubmission> get items => List.unmodifiable(_items);

  List<QueuedSubmission> ofKind(String kind) =>
      _items.where((i) => i.kind == kind).toList();

  bool _flushing = false;
  Timer? _pingTimer;

  /// Called after a flush that synced at least one item — main.dart points
  /// this at the stores so fresh server rows replace the queued copies.
  VoidCallback? onSynced;

  /// Load persisted items and start watching connectivity. Call once at
  /// startup (idempotent).
  bool _initialized = false;
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _items.addAll(list.map(
            (e) => QueuedSubmission.fromJson((e as Map).cast<String, dynamic>())));
        notifyListeners();
      }
    } catch (_) {
      // Corrupt queue — start clean rather than crash on launch.
      _items.clear();
    }
    ApiClient.instance.offline.addListener(_onConnectivityChanged);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode([for (final i in _items) i.toJson()]));
    } catch (_) {
      /* persistence is best-effort; items stay in memory */
    }
  }

  Future<void> enqueue(String kind, String path,
      Map<String, dynamic> body) async {
    _items.add(QueuedSubmission(
        kind: kind, path: path, body: body, createdAt: DateTime.now()));
    await _persist();
    notifyListeners();
  }

  void _onConnectivityChanged() {
    if (ApiClient.instance.offline.value) {
      // Offline: probe every 25s so the app notices recovery by itself.
      _pingTimer ??= Timer.periodic(
          const Duration(seconds: 25), (_) => ApiClient.instance.ping());
    } else {
      _pingTimer?.cancel();
      _pingTimer = null;
      flush();
    }
  }

  /// Send queued items in order. Stops on a network failure (still offline);
  /// drops items the server rejects outright so one bad record can't jam
  /// the queue forever.
  Future<void> flush() async {
    if (_flushing || _items.isEmpty) return;
    _flushing = true;
    var synced = false;
    try {
      while (_items.isNotEmpty) {
        final item = _items.first;
        try {
          await ApiClient.instance.post(item.path, item.body);
          synced = true;
        } on ApiException catch (e) {
          if (e.statusCode == 0) return; // still unreachable — retry later
          // Server said no (validation etc.) — drop below and move on.
        }
        _items.removeAt(0);
        await _persist();
        notifyListeners();
      }
    } finally {
      _flushing = false;
      if (synced) onSynced?.call();
    }
  }
}
