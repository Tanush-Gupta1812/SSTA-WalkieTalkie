import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../services/websocket_service.dart';
import '../services/foreground_manager.dart';

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

    if (_activeGroup != null && _wsService != null) {
      ForegroundManager.updateStatus(
        channelName: _activeGroup!.name,
        speakerName: _wsService!.activeSpeakerName,
      );
    }

    notifyListeners();
  }

  /// Explicitly disconnect and terminate session (e.g. when powered off or left)
  void disconnect() {
    _wsService?.removeListener(_onWsUpdate);
    _wsService?.dispose();
    _wsService = null;
    _activeGroup = null;
    ForegroundManager.stop();
    notifyListeners();
  }
}
