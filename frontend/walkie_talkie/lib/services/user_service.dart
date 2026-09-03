import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserService {
  static const String _keyUserId = 'walkie_user_id';
  static const String _keyDisplayName = 'walkie_display_name';
  static const String _keyJoinedGroupIds = 'walkie_joined_groups';

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
}
