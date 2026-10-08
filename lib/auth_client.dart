import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'friend.auth.token';

/// Authentication-only client for the new Friend backend.
class FriendAuthClient {
  FriendAuthClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ??
            Uri.parse(const String.fromEnvironment(
              'FRIEND_API_BASE_URL',
              defaultValue: 'https://api.outmcn.com',
            ));

  final http.Client _client;
  final Uri _baseUri;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw FriendAuthException(data['error']?.toString() ?? '登录失败');
    }
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const FriendAuthException('登录响应格式错误');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final user = data['user'];
    if (user is Map && user['id'] != null) {
      await prefs.setString('friend.auth.userId', '${user['id']}');
    }
    return token;
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/logout'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw FriendAuthException(
          _decode(response)['error']?.toString() ?? '退出登录失败');
    }
    await clearToken();
  }

  Future<String?> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    final response = await _client.get(
      _baseUri.resolve('/api/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await clearToken();
      return null;
    }
    return token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('friend.auth.userId');
  }

  void dispose() => _client.close();

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FriendAuthException('后端响应格式错误');
    }
    return value;
  }
}

class FriendAuthException implements Exception {
  const FriendAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
