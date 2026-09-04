import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Active public tunnel URL (permanent ngrok static domain)
  static const String publicTunnelUrl = 'https://kenneth-nonfortuitous-unthreateningly.ngrok-free.dev';

  /// Base host configuration.
  /// Uses public tunnel if configured, or falls back to local emulator / localhost.
  static String get defaultHost {
    if (publicTunnelUrl.isNotEmpty) return publicTunnelUrl;
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static int port = 8000;

  static String customUrlOrHost = '';

  static String get effectiveHost =>
      customUrlOrHost.isNotEmpty ? customUrlOrHost : defaultHost;

  static String get httpBaseUrl {
    final raw = effectiveHost.trim();
    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    }
    // If it contains a port already (e.g. 192.168.1.15:8000)
    if (raw.contains(':')) {
      return 'http://$raw';
    }
    return 'http://$raw:$port';
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

  // Audio parameters: PCM16 16kHz mono, 40ms frame buffer (~1280 bytes)
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int frameChunkSize = 1280; // 40ms of 16-bit 16kHz mono audio
}
