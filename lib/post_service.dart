import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DDPost {
  const DDPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.nickname,
    required this.avatar,
    required this.likes,
    required this.favorites,
    required this.comments,
    required this.following,
    this.distanceKm,
    required this.liked,
    required this.favorited,
    this.imageUrl,
  });

  final int id;
  final int? userId;
  final String content;
  final String createdAt;
  final String nickname;
  final String avatar;
  final int likes;
  final int favorites;
  final int comments;
  final bool following;
  final double? distanceKm;
  final bool liked;
  final bool favorited;
  final String? imageUrl;

  factory DDPost.fromJson(Map<String, dynamic> json) => DDPost(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['userId'] as num?)?.toInt(),
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? json['created_at'] ?? ''}',
        nickname: '${json['nickname'] ?? json['username'] ?? '用户'}',
        avatar: DDPostService.mediaUrl(json['avatar']?.toString()),
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        favorites: (json['favorites'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        following: json['following'] == true,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        liked: json['liked'] == true,
        favorited: json['favorited'] == true,
        imageUrl: DDPostService.mediaUrl(
          (json['imageURL'] ?? json['image_url'] ?? json['image'])?.toString(),
        ),
      );
}

class DDComment {
  const DDComment(
      {required this.id,
      required this.userId,
      required this.parentId,
      required this.nickname,
      required this.content,
      required this.createdAt});
  final int id;
  final int? userId;
  final int? parentId;
  final String nickname;
  final String content;
  final String createdAt;
  factory DDComment.fromJson(Map<String, dynamic> json) => DDComment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['userId'] as num?)?.toInt(),
        parentId: (json['parentId'] as num?)?.toInt(),
        nickname: '${json['nickname'] ?? '用户'}',
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
      );
}

class DDNotification {
  const DDNotification(
      {required this.id,
      required this.type,
      required this.content,
      required this.createdAt,
      this.nickname,
      this.read = false});
  final int id;
  final String type;
  final String content;
  final String createdAt;
  final String? nickname;
  final bool read;
  factory DDNotification.fromJson(Map<String, dynamic> json) => DDNotification(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: '${json['type'] ?? ''}',
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        nickname: json['nickname']?.toString(),
        read: json['read'] == true,
      );
}

class DDPostService {
  DDPostService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _base = Uri.parse('https://friend.outmcn.net/api');
  final http.Client _client;
  static String mediaUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://friend.outmcn.net${raw.startsWith('/') ? raw : '/$raw'}';
  }

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

  Future<List<DDNotification>> fetchNotifications(String token) async {
    final response = await _client.get(_base.resolve('/api/notifications'),
        headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '通知加载失败'}');
    }
    final data = decoded['data'];
    if (data is! List) {
      throw Exception('通知数据格式错误');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(DDNotification.fromJson)
        .toList();
  }

  Future<void> markNotificationsRead(String token) async {
    final response = await _client.post(
        _base.resolve('/api/notifications/read'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('通知已读失败');
    }
  }

  Future<List<DDPost>> fetchPosts(String token) =>
      _fetchList(token, '/api/posts');
  Future<List<DDPost>> fetchNearbyPosts(String token) =>
      _fetchList(token, '/api/posts/nearby');
  Future<List<DDPost>> fetchFollowingPosts(String token) =>
      _fetchList(token, '/api/posts/following');

  Future<DDPost> fetchPost(String token, int postId) async {
    final response = await _client.get(
      _base.resolve('/api/posts/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('动态加载失败（${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
      throw Exception('动态数据格式错误');
    }
    return DDPost.fromJson((decoded['data'] as Map).cast<String, dynamic>());
  }

  Future<List<DDPost>> fetchMyPosts(String token) =>
      _fetchList(token, '/api/me/posts');
  Future<List<DDPost>> fetchLikedPosts(String token) =>
      _fetchList(token, '/api/me/liked');
  Future<List<DDPost>> fetchFavoritedPosts(String token) =>
      _fetchList(token, '/api/me/favorited');

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

  Future<Map<String, dynamic>> _decodeResponse(
      http.Response response, String fallback) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$fallback（${response.statusCode}）');
    }
    if (response.body.trim().isEmpty) {
      throw Exception('$fallback：服务器返回空响应');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('响应不是 JSON 对象');
      }
      return decoded;
    } on FormatException catch (e) {
      throw Exception('$fallback：响应格式错误（${e.message}）');
    }
  }

  Future<int> createPost(
      {required String token,
      required String content,
      String? imageDataUrl,
      double? latitude,
      double? longitude}) async {
    final body = <String, dynamic>{'content': content};
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
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
    final decoded = await _decodeResponse(response, '发布动态失败');
    if (decoded['ok'] != true) {
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
      required String content,
      int? parentId}) async {
    final response = await _client.post(
      _base.resolve('/api/posts/$postId/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'content': content,
        if (parentId != null) 'parentId': parentId,
      }),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '评论发布失败'}');
    }
  }

  Future<void> deleteComment(String token, int commentId) async {
    final response = await _client.delete(
      _base.resolve('/api/comments/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '删除评论失败'}');
    }
  }

  Future<void> reportComment({
    required String token,
    required int commentId,
    required String reason,
  }) async {
    final response = await _client.post(
      _base.resolve('/api/comments/$commentId/report'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '举报评论失败'}');
    }
  }

  Future<Map<String, dynamic>> toggleProfileLike(
      String token, int userId) async {
    final response = await _client.post(
      _base.resolve('/api/users/$userId/like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '点赞失败'}');
    }
    return (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
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

  Future<Map<String, dynamic>> fetchUserProfile(String token, int userId) =>
      _fetchObject(token, '/api/users/$userId');

  Future<Map<String, dynamic>> fetchMe(String token) =>
      _fetchObject(token, '/api/me');

  Future<Map<String, dynamic>> updateMe(
      {required String token,
      String? nickname,
      String? city,
      String? avatar}) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        if (nickname != null) 'nickname': nickname,
        if (city != null) 'city': city,
        if (avatar != null) 'avatar': avatar
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

  Future<Map<String, dynamic>> updateLocation(
      {required String token,
      required double latitude,
      required double longitude}) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );
    return _decodeResponse(response, '定位更新失败');
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

  Future<void> deletePost(String token, int postId) async {
    final response = await _client.delete(_base.resolve('/api/posts/$postId'),
        headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '删除动态失败'}');
    }
  }

  Future<void> reportPost(
      {required String token,
      required int postId,
      required String reason}) async {
    final response = await _client.post(
        _base.resolve('/api/posts/$postId/report'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'reason': reason}));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] != true) {
      throw Exception('${decoded['message'] ?? '举报动态失败'}');
    }
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
