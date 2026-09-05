import 'dart:io';
import 'package:flutter/services.dart';

/// Platform channel interface to Android native AudioManager and PowerManager
class NativeAudioControl {
  static const MethodChannel _channel = MethodChannel('com.ssta.walkie/audio_control');

  /// Set mode to MODE_IN_COMMUNICATION with speakerphone enabled
  static Future<void> setCommunicationMode(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setCommunicationMode', {'enable': enable});
    } catch (_) {}
  }

  /// Ensure volume is unmuted and audible even if user's phone is in silent or vibrate mode
  static Future<void> ensureAudible() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('ensureAudible');
    } catch (_) {}
  }

  /// Acquire wake lock temporarily while audio is actively transmitting or receiving
  static Future<void> acquireTransmissionWakeLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('acquireTransmissionWakeLock');
    } catch (_) {}
  }

  /// Release wake lock as soon as transmission finishes so device can sleep
  static Future<void> releaseTransmissionWakeLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('releaseTransmissionWakeLock');
    } catch (_) {}
  }
}
