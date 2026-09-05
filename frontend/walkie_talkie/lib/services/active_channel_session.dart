import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../services/websocket_service.dart';
import '../services/foreground_manager.dart';
import '../services/user_service.dart';
import '../services/native_audio_control.dart';

/// Singleton manager that holds the active walkie-talkie channel session
/// so it remains connected and transmitting/receiving even when the user
/// navigates back to the Channels List or switches pages.
class ActiveChannelSession extends ChangeNotifier {
  static final ActiveChannelSession instance = ActiveChannelSession._internal();
  ActiveChannelSession._internal();

  Group? _activeGroup;
  WebSocketService? _wsService;

  Group? get activeGroup => _activeGroup;
  WebSocketService? get wsService => _wsService;

  bool get hasActiveSession =>
      _activeGroup != null &&
      _wsService != null &&
      _wsService!.isPoweredOn;

  String? get activeGroupId => _activeGroup?.id;
  String? get activeGroupName => _activeGroup?.name;

  /// Start or reuse a session for the specified group
  WebSocketService getOrCreateSession({
    required Group group,
    required String userId,
    required String displayName,
  }) {
    // If already connected to this same group, reuse existing service
    if (_activeGroup?.id == group.id && _wsService != null) {
      return _wsService!;
    }

    // If switching to a different group, disconnect previous one
    disconnect();

    _activeGroup = group;
    _wsService = WebSocketService(
      groupId: group.id,
      userId: userId,
      displayName: displayName,
    );

    _wsService!.addListener(_onWsUpdate);

    // Persist session state so Android can restore connection if killed
    UserService.saveActiveGroup(group);

    // Configure native communication audio mode (speakerphone + silent mode override)
    NativeAudioControl.setCommunicationMode(true);

    ForegroundManager.start(
      channelName: group.name,
      userName: displayName,
    );

    notifyListeners();
    return _wsService!;
  }

  void _onWsUpdate() {
    if (_wsService?.isGroupDeleted == true) {
      disconnect();
      return;
    }

    notifyListeners();
  }

  /// Update active group name when renamed
  void updateGroupName(String groupId, String newName) {
    if (_activeGroup?.id == groupId) {
      _activeGroup = _activeGroup!.copyWith(name: newName);
      UserService.saveActiveGroup(_activeGroup!);
      ForegroundManager.start(
        channelName: newName,
      );
      notifyListeners();
    }
  }

  /// Update user display name in active session and websocket
  void updateDisplayName(String newDisplayName) {
    if (_wsService != null) {
      _wsService!.updateDisplayName(newDisplayName);
      notifyListeners();
    }
  }

  /// Explicitly disconnect and terminate session (e.g. when powered off, left, or deleted)
  void disconnect() {
    _wsService?.removeListener(_onWsUpdate);
    _wsService?.dispose();
    _wsService = null;
    _activeGroup = null;
    UserService.clearActiveGroup();
    NativeAudioControl.setCommunicationMode(false);
    ForegroundManager.stop();
    notifyListeners();
  }

  /// Automatically restore connection to the last active channel if the app was killed while connected
  Future<void> restoreLastSessionIfNeeded() async {
    try {
      final wasActive = await UserService.isSessionActive();
      if (!wasActive) {
        // Explicitly stopped or disconnected previously — ensure foreground service is off
        await ForegroundManager.stop();
        return;
      }

      final lastGroup = await UserService.getLastConnectedGroup();
      if (lastGroup == null) return;

      final userId = await UserService.getUserId();
      final displayName = await UserService.getDisplayName();

      debugPrint('Restoring background session for last connected channel: ${lastGroup.name}');
      getOrCreateSession(
        group: lastGroup,
        userId: userId,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('Error in restoreLastSessionIfNeeded: $e');
    }
  }
}
