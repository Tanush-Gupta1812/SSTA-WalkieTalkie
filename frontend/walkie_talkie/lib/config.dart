import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String ec2ServerUrl = 'http://ec2-54-201-5-16.us-west-2.compute.amazonaws.com:2035';

  /// Candidate backend URLs for auto-discovery (in priority order)
  static const List<String> candidates = [
    ec2ServerUrl,                                                  // ✨ Primary AWS EC2 KalorTech Server
    'http://10.0.2.2:8000',                                        // Android Emulator
    'http://127.0.0.1:8000',                                       // iOS Simulator / USB adb reverse
    'http://10.0.33.180:8000',                                     // Direct Wi-Fi / Hotspot LAN IP
  ];

  static const String _cacheKey = 'active_api_url';
  static const String _manualKey = 'manual_api_url';
  static const Duration _pingTimeout = Duration(milliseconds: 1500);

  static String? _activeUrl;
  static String? _manualUrl;
  static bool _discovering = false;

  /// Returns current active host or falls back to EC2 server
  static String get effectiveHost => _manualUrl ?? _activeUrl ?? ec2ServerUrl;

  static String get httpBaseUrl {
    final raw = effectiveHost.trim();
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    }
    if (raw.contains(':')) {
      return 'http://$raw';
    }
    return 'http://$raw:8000';
  }

  static String get wsBaseUrl {
    final httpUrl = httpBaseUrl;
    if (httpUrl.startsWith('https://')) {
      return 'wss://${httpUrl.substring(8)}';
    } else if (httpUrl.startsWith('http://')) {
      return 'ws://${httpUrl.substring(7)}';
    }
    return 'ws://$httpUrl';
  }

  /// Backward-compatibility getter and setter for manual custom URL
  static String get customUrlOrHost => _manualUrl ?? '';
  static set customUrlOrHost(String url) {
    setManualUrl(url.isEmpty ? null : url);
  }

  /// Loads cached or manual URL from SharedPreferences
  static Future<void> loadCache() async {
    if (_activeUrl != null || _manualUrl != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualUrl = prefs.getString(_manualKey);
      _activeUrl = prefs.getString(_cacheKey);

      // Auto-purge any old ngrok URLs cached from earlier testing
      if (_manualUrl != null && _manualUrl!.contains('ngrok-free.dev')) {
        _manualUrl = null;
        await prefs.remove(_manualKey);
      }
      if (_activeUrl != null && _activeUrl!.contains('ngrok-free.dev')) {
        _activeUrl = null;
        await prefs.remove(_cacheKey);
      }

      if (_manualUrl != null) {
        debugPrint('[AppConfig] 🛠️ Manual URL loaded: $_manualUrl');
      } else if (_activeUrl != null) {
        debugPrint('[AppConfig] 💾 Active URL loaded from cache: $_activeUrl');
      }
    } catch (_) {}
  }

  /// Sets or clears a manual URL override
  static Future<void> setManualUrl(String? url) async {
    _manualUrl = (url == null || url.trim().isEmpty) ? null : url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_manualUrl != null) {
        await prefs.setString(_manualKey, _manualUrl!);
        debugPrint('[AppConfig] 🛠️ Manual URL set: $_manualUrl');
      } else {
        await prefs.remove(_manualKey);
        debugPrint('[AppConfig] 🛠️ Manual URL cleared');
      }
    } catch (_) {}
  }

  /// Pings a candidate URL to check health (tries /walkie/health, then /health)
  static Future<bool> pingUrl(String url) async {
    try {
      final clean = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse('$clean/walkie/health');
      final res = await http.get(uri, headers: {
        'ngrok-skip-browser-warning': 'true',
        'Bypass-Tunnel-Reminder': 'true',
      }).timeout(_pingTimeout);
      if (res.statusCode == 200) return true;

      // Fallback ping to /health
      final uriFallback = Uri.parse('$clean/health');
      final res2 = await http.get(uriFallback, headers: {
        'ngrok-skip-browser-warning': 'true',
        'Bypass-Tunnel-Reminder': 'true',
      }).timeout(_pingTimeout);
      return res2.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Concurrent auto-discovery: races all candidate URLs in parallel
  /// First 200 OK response wins and is cached
  static Future<String> discover() async {
    if (_manualUrl != null) return _manualUrl!;

    if (_discovering) {
      while (_discovering) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_activeUrl != null) return _activeUrl!;
    }

    _discovering = true;
    debugPrint('[AppConfig] 🔍 Starting backend auto-discovery race...');

    try {
      final completer = Completer<String>();
      int failures = 0;

      for (final url in candidates) {
        pingUrl(url).then((reachable) {
          if (reachable && !completer.isCompleted) {
            completer.complete(url);
          } else if (!reachable) {
            failures++;
            if (failures == candidates.length && !completer.isCompleted) {
              completer.completeError(Exception('No reachable backend found in candidate pool'));
            }
          }
        });
      }

      _activeUrl = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => _activeUrl ?? candidates.first,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, _activeUrl!);
      } catch (_) {}

      debugPrint('[AppConfig] ✅ Connected to winner: $_activeUrl');
      return _activeUrl!;
    } catch (e) {
      debugPrint('[AppConfig] ❌ Discovery race failed: $e. Falling back to ${_activeUrl ?? candidates.first}');
      _activeUrl = _activeUrl ?? candidates.first;
      return _activeUrl!;
    } finally {
      _discovering = false;
    }
  }

  /// Ensures we have a valid and validated baseUrl before making requests
  static Future<void> ensureConnected() async {
    if (_manualUrl != null) return;
    await loadCache();
    if (_activeUrl != null) {
      final isAlive = await pingUrl(_activeUrl!);
      if (isAlive) return;
      debugPrint('[AppConfig] ⚠️ Cached URL failed validation. Starting race discovery...');
    }
    await discover();
  }

  /// Invalidate cache and re-discover when connection drops
  static Future<void> handleConnectionError() async {
    debugPrint('[AppConfig] 🔄 Connection lost. Re-discovering best reachable host...');
    _activeUrl = null;
    await discover();
  }

  // Audio parameters: PCM16 16kHz mono, 40ms frame buffer (~1280 bytes)
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int frameChunkSize = 1280; // 40ms of 16-bit 16kHz mono audio
}
