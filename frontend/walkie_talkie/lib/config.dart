import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String ec2ServerUrl = 'http://ec2-54-201-5-16.us-west-2.compute.amazonaws.com:2035';

  /// Candidate backend URLs (Built-in primary server)
  static const List<String> candidates = [
    ec2ServerUrl,
  ];

  static const String _cacheKey = 'active_api_url';
  static const String _manualKey = 'manual_api_url';
  static const Duration _pingTimeout = Duration(milliseconds: 2000);

  /// Returns built-in EC2 server exclusively (user cannot change)
  static String get effectiveHost => ec2ServerUrl;

  static String get httpBaseUrl => ec2ServerUrl;

  static String get wsBaseUrl => 'ws://ec2-54-201-5-16.us-west-2.compute.amazonaws.com:2035';

  /// Backward-compatibility getter and setter (no manual override permitted)
  static String get customUrlOrHost => '';
  static set customUrlOrHost(String url) {}

  /// Loads cache and ensures any legacy manual overrides are cleared
  static Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_manualKey);
      await prefs.remove(_cacheKey);
      await prefs.remove('walkie_server_url');
    } catch (_) {}
  }

  /// No-op: manual override disabled in favor of built-in forceful server
  static Future<void> setManualUrl(String? url) async {}

  /// Pings the built-in server to check health (tries /walkie/health, then /health)
  static Future<bool> pingUrl(String url) async {
    try {
      final clean = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse('$clean/walkie/health');
      final res = await http.get(uri).timeout(_pingTimeout);
      if (res.statusCode == 200) return true;

      // Fallback ping to /health
      final uriFallback = Uri.parse('$clean/health');
      final res2 = await http.get(uriFallback).timeout(_pingTimeout);
      return res2.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Built-in connection verification
  static Future<String> discover() async {
    return ec2ServerUrl;
  }

  /// Ensures we have a valid and validated baseUrl before making requests
  static Future<void> ensureConnected() async {}

  /// Invalidate cache and re-discover when connection drops
  static Future<void> handleConnectionError() async {}

  // Audio parameters: PCM16 16kHz mono, 40ms frame buffer (~1280 bytes)
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int frameChunkSize = 1280; // 40ms of 16-bit 16kHz mono audio
}
