import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';

class UserService {
  static const String _keyUserId = 'walkie_user_id';
  static const String _keyDisplayName = 'walkie_display_name';
  static const String _keyJoinedGroupIds = 'walkie_joined_groups';
  static const String _keyServerUrl = 'walkie_server_url';
  static const String _keyIsSessionActive = 'walkie_is_session_active';
  static const String _keyLastConnectedGroupJson = 'walkie_last_connected_group_json';

  static Future<String?> getSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyServerUrl);
    if (url != null && url.contains('ngrok-free.dev')) {
      await prefs.remove(_keyServerUrl);
      return null;
    }
    return url;
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url.trim());
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_keyUserId);
    if (userId == null || userId.isEmpty) {
      userId = const Uuid().v4();
      await prefs.setString(_keyUserId, userId);
    }
    return userId;
  }

  static Future<String> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString(_keyDisplayName);
    if (name == null || name.isEmpty) {
      // Default initial handle
      final shortId = (await getUserId()).substring(0, 4).toUpperCase();
      name = 'Operator-$shortId';
      await prefs.setString(_keyDisplayName, name);
    }
    return name;
  }

  static Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, name.trim());
  }

  static Future<List<String>> getJoinedGroupIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyJoinedGroupIds) ?? [];
  }

  static Future<void> saveJoinedGroupId(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyJoinedGroupIds) ?? [];
    if (!list.contains(groupId)) {
      list.add(groupId);
      await prefs.setStringList(_keyJoinedGroupIds, list);
    }
  }

  static Future<void> removeJoinedGroupId(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyJoinedGroupIds) ?? [];
    list.remove(groupId);
    await prefs.setStringList(_keyJoinedGroupIds, list);
  }

  /// Persist active channel session state so the app can auto-reconnect if killed by Android
  static Future<void> saveActiveGroup(Group group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastConnectedGroupJson, jsonEncode(group.toJson()));
    await prefs.setBool(_keyIsSessionActive, true);
  }

  /// Explicitly clear active channel session (called on user leave or power off)
  static Future<void> clearActiveGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsSessionActive, false);
  }

  /// Check if the user was actively connected to a channel when the app was closed/killed
  static Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsSessionActive) ?? false;
  }

  /// Retrieve the last connected group if the session was active
  static Future<Group?> getLastConnectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_keyIsSessionActive) ?? false;
    if (!isActive) return null;
    final jsonStr = prefs.getString(_keyLastConnectedGroupJson);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Group.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
