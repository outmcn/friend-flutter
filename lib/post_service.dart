import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DDPost {
  const DDPost({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.nickname,
    required this.avatar,
    required this.likes,
    required this.favorites,
    required this.liked,
    required this.favorited,
    this.imageUrl,
  });

  final int id;
  final String content;
  final String createdAt;
  final String nickname;
  final String avatar;
  final int likes;
  final int favorites;
  final bool liked;
  final bool favorited;
  final String? imageUrl;

  factory DDPost.fromJson(Map<String, dynamic> json) => DDPost(
        id: (json['id'] as num?)?.toInt() ?? 0,
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? json['created_at'] ?? ''}',
        nickname: '${json['nickname'] ?? json['username'] ?? '用户'}',
        avatar: '${json['avatar'] ?? ''}',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        favorites: (json['favorites'] as num?)?.toInt() ?? 0,
        liked: json['liked'] == true,
        favorited: json['favorited'] == true,
        imageUrl: (json['imageURL'] ?? json['image_url'])?.toString(),
      );
}

class DDComment {
  const DDComment(
      {required this.id,
      required this.nickname,
      required this.content,
      required this.createdAt});
  final int id;
  final String nickname;
  final String content;
  final String createdAt;
  factory DDComment.fromJson(Map<String, dynamic> json) => DDComment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nickname: '${json['nickname'] ?? '用户'}',
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
      );
}

class DDPostService {
  DDPostService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _base = Uri.parse('https://friend.outmcn.net/api');
  final http.Client _client;

  Future<String> login(
      {required String username, required String password}) async {
    final response = await _client.post(
      _base.resolve('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '登录失败'}');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic> || data['token'] is! String) {
      throw Exception('登录响应格式错误');
    }
    final token = data['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dd.auth.token', token);
    return token;
  }

  Future<List<DDPost>> fetchPosts(String token) =>
      _fetchList(token, '/api/posts');
  Future<List<DDPost>> fetchMyPosts(String token) =>
      _fetchList(token, '/api/me/posts');

  Future<List<DDPost>> _fetchList(String token, String path) async {
    final response = await _client.get(
      _base.resolve(path),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('动态加载失败（${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['posts'] : null);
    if (list is! List) throw Exception('动态数据格式错误');
    return list.whereType<Map<String, dynamic>>().map(DDPost.fromJson).toList();
  }

  Future<int> createPost(
      {required String token,
      required String content,
      String? imageDataUrl}) async {
    final body = <String, dynamic>{'content': content};
    if (imageDataUrl != null && imageDataUrl.isNotEmpty) {
      body['image'] = imageDataUrl;
    }
    final response = await _client.post(
      _base.resolve('/api/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '发布动态失败'}');
    }
    final data = decoded['data'];
    return data is Map<String, dynamic>
        ? (data['id'] as num?)?.toInt() ?? 0
        : 0;
  }

  Future<List<DDComment>> fetchComments(String token, int postId) async {
    final response = await _client.get(
      _base.resolve('/api/posts/$postId/comments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('评论加载失败');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) throw Exception('评论数据格式错误');
    return data
        .whereType<Map<String, dynamic>>()
        .map(DDComment.fromJson)
        .toList();
  }

  Future<void> createComment(
      {required String token,
      required int postId,
      required String content}) async {
    final response = await _client.post(
      _base.resolve('/api/posts/$postId/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'content': content}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '评论发布失败'}');
    }
  }

  Future<void> toggleFollow(String token, int userId) async {
    final response = await _client.post(
      _base.resolve('/api/users/$userId/follow'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '关注操作失败'}');
    }
  }

  Future<void> logout(String token) async {
    final response = await _client.post(_base.resolve('/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('退出登录失败');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dd.auth.token');
  }

  Future<Map<String, dynamic>> fetchMe(String token) =>
      _fetchObject(token, '/api/me');

  Future<Map<String, dynamic>> updateMe(
      {required String token, String? nickname, String? city}) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        if (nickname != null) 'nickname': nickname,
        if (city != null) 'city': city
      }),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '资料保存失败'}');
    }
    return (decoded['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _fetchObject(String token, String path) async {
    final response = await _client
        .get(_base.resolve(path), headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '资料加载失败'}');
    }
    return (decoded['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  Future<void> toggleLike(String token, int postId) =>
      _postAction(token, postId, 'like');

  Future<void> toggleFavorite(String token, int postId) =>
      _postAction(token, postId, 'favorite');

  Future<void> _postAction(String token, int postId, String action) async {
    final response = await _client.post(
      _base.resolve('/api/posts/$postId/$action'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('操作失败（${response.statusCode}）');
    }
  }

  void dispose() => _client.close();
}
