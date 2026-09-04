import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundManager {
  static bool _initialized = false;

  static void init() {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'walkie_talkie_channel_silent_v2',
        channelName: 'Walkie Talkie Background Service',
        channelDescription: 'Keeps audio connected silently in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Request notification permission (Android 13+) and battery optimization exclusion
  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Ensure Android OS does not put the app into deep sleep when screen is locked
      final isIgnoringBattery = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoringBattery) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  static String? _lastTitle;
  static String? _lastText;

  /// Start persistent foreground task with channel name
  static Future<void> start({
    required String channelName,
    String? userName,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await requestPermission();

      final title = '📻 SSTA walkie: $channelName';
      const text = 'Active in background • Tap to open';

      if (await FlutterForegroundTask.isRunningService) {
        if (_lastTitle != title || _lastText != text) {
          _lastTitle = title;
          _lastText = text;
          await FlutterForegroundTask.updateService(
            notificationTitle: title,
            notificationText: text,
          );
        }
        return;
      }

      _lastTitle = title;
      _lastText = text;
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: title,
        notificationText: text,
        callback: _dummyCallback,
      );
    } catch (e) {
      debugPrint('Error starting foreground task: $e');
    }
  }

  /// Update notification status silently (only if text changes)
  static Future<void> updateStatus({
    required String channelName,
    String? speakerName,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        final title = '📻 SSTA walkie: $channelName';
        final text = (speakerName != null && speakerName.isNotEmpty)
            ? '🎙️ $speakerName is speaking...'
            : 'Active in background • Tap to open';

        if (_lastTitle == title && _lastText == text) {
          return;
        }

        _lastTitle = title;
        _lastText = text;
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (e) {
      debugPrint('Error updating foreground notification: $e');
    }
  }

  /// Stop persistent foreground task
  static Future<void> stop() async {
    _lastTitle = null;
    _lastText = null;
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Error stopping foreground task: $e');
    }
  }
}

@pragma('vm:entry-point')
void _dummyCallback() {
  FlutterForegroundTask.setTaskHandler(_DummyTaskHandler());
}

class _DummyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isDestroyed) async {}
}
