import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/group.dart';
import '../models/member.dart';

class ApiService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        'ngrok-skip-browser-warning': 'true',
        'Connection': 'close',
      };

  static Future<Group> createGroup(
    String name, {
    String? creatorId,
    String? creatorDisplayName,
  }) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups');
    final Map<String, dynamic> body = {'name': name};
    if (creatorId != null) body['creator_id'] = creatorId;
    if (creatorDisplayName != null) {
      body['creator_display_name'] = creatorDisplayName;
    }

    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  static Future<List<Group>> listGroups({String? userId}) async {
    final baseUri = Uri.parse('${AppConfig.httpBaseUrl}/groups');
    final uri = (userId != null && userId.isNotEmpty)
        ? baseUri.replace(queryParameters: {'user_id': userId})
        : baseUri;
    final response = await http.get(uri, headers: _headers);

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
    final response = await http.get(uri, headers: _headers);

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
      headers: _headers,
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
    final response = await http.get(uri, headers: _headers);

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
    final response = await http.delete(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to leave group: ${response.body}');
    }
  }

  static Future<void> deleteGroup(String groupId) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId');
    final response = await http.delete(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }

  static Future<List<dynamic>> getGroupAudioHistory(String groupId) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId/history');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (decoded['messages'] as List<dynamic>?) ?? [];
    } else {
      throw Exception('Failed to get audio history: ${response.body}');
    }
  }

  static Future<List<int>> getTransmissionRawPcm(String messageId) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/history/$messageId/raw');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to fetch audio data: ${response.statusCode}');
    }
  }

  static Future<void> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/users/$userId');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({'display_name': displayName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update display name: ${response.body}');
    }
  }

  static Future<Group> renameGroup({
    required String groupId,
    required String newName,
  }) async {
    final uri = Uri.parse('${AppConfig.httpBaseUrl}/groups/$groupId');
    final response = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to rename group: ${response.body}');
    }
  }
}
