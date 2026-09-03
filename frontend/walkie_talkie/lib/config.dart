import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Base host configuration.
  /// For Android emulator: use 10.0.2.2
  /// For iOS simulator / Web / Desktop: use 128.0.0.1 or localhost
  /// For physical device: replace with your local WiFi IP (e.g., 192.168.1.15)
  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static int port = 8000;

  static String customHost = '';

  static String get effectiveHost =>
      customHost.isNotEmpty ? customHost : defaultHost;

  static String get httpBaseUrl => 'http://$effectiveHost:$port';
  static String get wsBaseUrl => 'ws://$effectiveHost:$port';

  // Audio parameters: PCM16 16kHz mono, 40ms frame buffer (~1280 bytes)
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int frameChunkSize = 1280; // 40ms of 16-bit 16kHz mono audio
}
