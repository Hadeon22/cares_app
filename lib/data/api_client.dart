import 'dart:convert';

import 'package:http/http.dart' as http;

/// ─────────────────────────────────────────────────────────────
/// Thin HTTP wrapper around the Conde Labac MIS API — the Dart
/// twin of the web system's js/api.js + js/api-config.js. Every
/// network call in the app goes through here so the base URL and
/// JSON/error handling live in one place.
///
/// Base URL resolution (mirrors api-config.js):
///   1. --dart-define=API_BASE=http://10.0.2.2:3000  (dev override;
///      10.0.2.2 reaches the host machine from the Android emulator)
///   2. the permanent ngrok domain — same one the web frontend uses
/// ─────────────────────────────────────────────────────────────

/// SET THIS to the permanent ngrok / Cloudflare domain (keep in sync with
/// PERMANENT_API_BASE in the web system's js/api-config.js).
const String kPermanentApiBase =
    'https://graffiti-grunge-doorway.ngrok-free.dev';

const String _apiBaseOverride = String.fromEnvironment('API_BASE');

/// Thrown for any non-2xx response; [message] is the server's `error` field
/// when present, so it's safe to show in a SnackBar.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  String get baseUrl =>
      _apiBaseOverride.isNotEmpty ? _apiBaseOverride : kPermanentApiBase;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(
          queryParameters: (query == null || query.isEmpty) ? null : query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', _uri(path, query));

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', _uri(path), body);

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', _uri(path), body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', _uri(path), body);

  Future<dynamic> delete(String path) => _send('DELETE', _uri(path));

  Future<dynamic> _send(String method, Uri uri,
      [Map<String, dynamic>? body]) async {
    final req = http.Request(method, uri);
    // Skips free-ngrok's "You are about to visit…" interstitial; harmless
    // (ignored) when the API isn't behind ngrok.
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    late http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(const Duration(seconds: 20)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          0, 'Cannot reach the barangay server. Check your connection.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = '${res.statusCode} ${res.reasonPhrase ?? ''}'.trim();
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] is String) msg = j['error'] as String;
      } catch (_) {}
      throw ApiException(res.statusCode, msg);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}
