import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/group.dart';
import '../models/member.dart';

class ApiService {
  static Future<Group> createGroup(String name) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  static Future<List<Group>> listGroups() async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) => Group.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to list groups: ${response.body}');
    }
  }

  static Future<Group> getGroup(String groupId) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to get group info: ${response.body}');
    }
  }

  static Future<Group> joinGroupByToken({
    required String joinToken,
    required String userId,
    required String displayName,
  }) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/join');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'join_token': joinToken,
        'user_id': userId,
        'display_name': displayName,
      }),
    );

    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final decoded = jsonDecode(response.body);
      final errorMsg = decoded['detail'] ?? response.body;
      throw Exception(errorMsg);
    }
  }

  static Future<List<Member>> getMembers(String groupId) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId/members');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) => Member.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to get members: ${response.body}');
    }
  }

  static Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId/members/$userId');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to leave group: ${response.body}');
    }
  }
}
