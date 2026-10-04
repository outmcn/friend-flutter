import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'friend.auth.token';
const _userKey = 'friend.auth.user';

/// Small client for the new Friend backend authentication contract.
///
/// This file deliberately contains authentication only. Social, media,
/// messaging, storage, and call APIs will be added as separate modules later.
class FriendAuthClient {
  FriendAuthClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        // A phone build must pass the reachable backend URL with
        // --dart-define=FRIEND_API_BASE_URL=https://your-host.example.
        _baseUri = baseUri ??
            Uri.parse(const String.fromEnvironment(
              'FRIEND_API_BASE_URL',
              defaultValue: 'http://127.0.0.1:3000',
            ));

  final http.Client _client;
  final Uri _baseUri;

  /// Restore the last session from local storage and validate it with /api/me.
  /// Invalid or expired tokens are removed instead of opening the app as if
  /// the user were still authenticated.
  Future<FriendLoginResult?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    try {
      final user = await me(token);
      await _saveSession(FriendLoginResult(token: token, user: user));
      return FriendLoginResult(token: token, user: user);
    } on FriendAuthException {
      await clearStoredSession();
      return null;
    }
  }

  /// Register a new account. Registration does not create a session.
  Future<FriendUser> register({
    required String username,
    required String password,
    String? nickname,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
      }),
    );
    final data = _decode(response);
    if (response.statusCode != 201) {
      throw FriendAuthException(
        data['error']?.toString() ?? '注册失败',
        response.statusCode,
      );
    }
    return FriendUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Login and return the raw bearer token plus the authenticated user.
  Future<FriendLoginResult> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw FriendAuthException(
        data['error']?.toString() ?? '登录失败',
        response.statusCode,
      );
    }
    final result = FriendLoginResult(
      token: data['token'] as String,
      user: FriendUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    await _saveSession(result);
    return result;
  }

  /// Load the current user with a previously issued bearer token.
  Future<FriendUser> me(String token) async {
    final response = await _client.get(
      _baseUri.resolve('/api/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw FriendAuthException(
        data['error']?.toString() ?? '登录已失效',
        response.statusCode,
      );
    }
    return FriendUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Revoke the current session on the backend.
  Future<void> logout(String token) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/logout'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      final data = _decode(response);
      throw FriendAuthException(
        data['error']?.toString() ?? '退出登录失败',
        response.statusCode,
      );
    }
    await clearStoredSession();
  }

  /// Remove the locally persisted token and user record.
  Future<void> clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Store only the session needed to restore authentication after restart.
  /// The password is never persisted.
  Future<void> _saveSession(FriendLoginResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    await prefs.setString(_userKey, jsonEncode(result.user.toJson()));
  }

  void dispose() => _client.close();

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FriendAuthException('后端响应格式错误', 502);
    }
    return decoded;
  }
}

class FriendLoginResult {
  const FriendLoginResult({required this.token, required this.user});

  final String token;
  final FriendUser user;
}

class FriendUser {
  const FriendUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String nickname;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'createdAt': createdAt,
      };

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: '${json['id'] ?? ''}',
      username: '${json['username'] ?? ''}',
      nickname: '${json['nickname'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
    );
  }
}

class FriendAuthException implements Exception {
  const FriendAuthException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
