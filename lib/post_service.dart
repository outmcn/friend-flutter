import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

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
    this.videoUrl,
    this.thumbnailUrl,
    required this.views,
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
  final String? videoUrl;
  final String? thumbnailUrl;
  final int views;
  DDPost copyWith({
    bool? liked,
    int? likes,
    bool? favorited,
    int? favorites,
  }) =>
      DDPost(
        id: id,
        userId: userId,
        content: content,
        createdAt: createdAt,
        nickname: nickname,
        avatar: avatar,
        likes: likes ?? this.likes,
        favorites: favorites ?? this.favorites,
        comments: comments,
        following: following,
        distanceKm: distanceKm,
        liked: liked ?? this.liked,
        favorited: favorited ?? this.favorited,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        views: views,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'content': content,
        'createdAt': createdAt,
        'nickname': nickname,
        'avatar': avatar,
        'likes': likes,
        'favorites': favorites,
        'comments': comments,
        'following': following,
        'distanceKm': distanceKm,
        'liked': liked,
        'favorited': favorited,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'views': views,
      };
  factory DDPost.fromJson(Map<String, dynamic> json) => DDPost(
        id: _intValue(json['id']) ?? 0,
        userId: _intValue(json['userId']),
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        nickname: '${json['nickname'] ?? '用户'}',
        avatar: DDPostService.mediaUrl(json['avatar']?.toString()),
        likes: _intValue(json['likes']) ?? 0,
        favorites: _intValue(json['favorites']) ?? 0,
        comments: _intValue(json['comments']) ?? 0,
        following: json['following'] == true,
        distanceKm: _doubleValue(json['distanceKm']),
        liked: json['liked'] == true,
        favorited: json['favorited'] == true,
        imageUrl: DDPostService.mediaUrl(json['imageUrl']?.toString()),
        videoUrl: DDPostService.mediaUrl(json['videoUrl']?.toString()),
        thumbnailUrl: DDPostService.mediaUrl(json['thumbnailUrl']?.toString()),
        views: _intValue(json['views']) ?? 0,
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
        id: _intValue(json['id']) ?? 0,
        userId: _intValue(json['userId']),
        parentId: _intValue(json['parentId']),
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
      this.avatar,
      this.postId,
      this.commentId,
      this.postContent,
      this.commentContent,
      this.read = false});
  final int id;
  final String type;
  final String content;
  final String createdAt;
  final String? nickname;
  final String? avatar;
  final int? postId;
  final int? commentId;
  final String? postContent;
  final String? commentContent;
  final bool read;
  factory DDNotification.fromJson(Map<String, dynamic> json) => DDNotification(
        id: _intValue(json['id']) ?? 0,
        type: '${json['type'] ?? ''}',
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        nickname: json['nickname']?.toString(),
        avatar: DDPostService.mediaUrl(json['avatar']?.toString()),
        postId: _intValue(json['postId']),
        commentId: _intValue(json['commentId']),
        postContent: json['postContent']?.toString(),
        commentContent: json['commentContent']?.toString(),
        read: json['read'] == true,
      );
}

class DDPostService {
  DDPostService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _base = Uri.parse('https://friend.outmcn.net');
  final http.Client _client;
  static const profileTabCachePrefix = 'dd.profile.tab.cache.';

  Uri _api(String path) => _base.resolve(path.startsWith('/api/') ? path : '/api$path');

  static Future<void> clearProfileTabCaches() async {
    final prefs = await SharedPreferences.getInstance();
    for (var tab = 0; tab < 3; tab++) {
      await prefs.remove('$profileTabCachePrefix$tab');
      await prefs.remove('dd.profile.tab.cache.at.$tab');
    }
  }

  static String mediaUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('https://')) return raw;
    return '';
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
        response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '登录失败'}');
    }
    final token = decoded['token'];
    if (token is! String) throw Exception('登录响应格式错误');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friend.auth.token', token);
    return token;
  }

  Future<List<DDNotification>> fetchNotifications(String token) async => <DDNotification>[];

  Future<void> markNotificationsRead(String token) async {}

  Future<List<DDPost>> fetchPosts(String token) async {
    final response = await _client.get(
      _api('/posts'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('动态数据格式错误');
    return rows.whereType<Map<String, dynamic>>().map(DDPost.fromJson).toList();
  }
  Future<List<DDPost>> fetchNearbyPosts(String token) => fetchPosts(token);
  Future<List<DDPost>> fetchFollowingPosts(String token) => fetchPosts(token);

  Future<DDPost> fetchPost(String token, int postId) async {
    final response = await _client.get(
      _api('/posts/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] ?? '动态加载失败'
          : '动态加载失败';
      throw Exception('$message（${response.statusCode}）');
    }
    if (decoded is! Map<String, dynamic> || decoded['post'] is! Map) {
      throw Exception('动态数据格式错误');
    }
    return DDPost.fromJson((decoded['post'] as Map).cast<String, dynamic>());
  }

  Future<List<DDPost>> fetchMyPosts(String token) async {
    final posts = await fetchPosts(token);
    final me = await fetchMe(token);
    final myId = _intValue(me['id']);
    return myId == null ? const [] : posts.where((post) => post.userId == myId).toList();
  }

  Future<List<DDPost>> fetchLikedPosts(String token) async {
    return _fetchProfilePosts(token, '/me/liked-posts');
  }

  Future<List<DDPost>> fetchFavoritedPosts(String token) async {
    return _fetchProfilePosts(token, '/me/favorited-posts');
  }

  Future<List<DDPost>> _fetchProfilePosts(String token, String path) async {
    final response = await _client.get(
      _api(path),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('我的动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('动态数据格式错误');
    return rows.whereType<Map<String, dynamic>>().map(DDPost.fromJson).toList();
  }

  Future<List<DDPost>> _fetchList(String token, String path) async {
    return const [];
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

  Future<int> createPost({
      required String token,
      required String content,
      String? imageDataUrl,
      String? videoUrl,
      String? thumbnailUrl,
      String visibility = 'public',
      double? latitude,
      double? longitude}) async {
    final body = <String, dynamic>{
      'content': content,
      'visibility': visibility,
    };
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
    if (imageDataUrl != null && imageDataUrl.isNotEmpty) {
      body['imageKey'] = imageDataUrl;
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      body['videoKey'] = videoUrl;
    }
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      body['thumbnailKey'] = thumbnailUrl;
    }
    final response = await _client.post(
      _api('/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );
    final decoded = await _decodeResponse(response, '发布动态失败');
    final post = decoded['post'];
    return _intValue(post is Map ? post['id'] : decoded['id']) ?? 0;
  }

  Future<List<DDComment>> fetchComments(String token, int postId) async {
    final response = await _client.get(
      _api('/posts/$postId/comments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('评论加载失败（${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('评论数据格式错误');
    return decoded.whereType<Map<String, dynamic>>().map(DDComment.fromJson).toList();
  }

  Future<void> createComment(
      {required String token,
      required int postId,
      required String content,
      int? parentId}) async {
    final response = await _client.post(
      _api('/posts/$postId/comments'),
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '评论发布失败'}');
    }
  }

  Future<void> deleteComment(String token, int commentId) async {
    final response = await _client.delete(
      _api('/comments/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '删除评论失败'}');
    }
  }

  Future<void> reportComment({
    required String token,
    required int commentId,
    required String reason,
  }) async {
    final response = await _client.post(
      _api('/comments/$commentId/report'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '举报评论失败'}');
    }
  }

  Future<Map<String, dynamic>> toggleProfileLike(
      String token, int userId) async {
    final response = await _client.post(
      _api('/users/$userId/like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '点赞失败'}');
    }
    return decoded;
  }

  Future<void> toggleFollow(String token, int userId) async {
    final response = await _client.post(
      _api('/users/$userId/follow'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '关注操作失败'}');
    }
  }

  Future<void> logout(String token) async {
    final response = await _client.post(_base.resolve('/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('退出登录失败');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('friend.auth.token');
  }

  Future<Map<String, dynamic>> fetchUserProfile(String token, int userId) async {
    final response = await _client.get(
      _api('/users/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('用户资料加载失败');
    }
    return decoded['user'] is Map<String, dynamic> ? decoded['user'] as Map<String, dynamic> : decoded;
  }

  Future<List<Map<String, dynamic>>> fetchUsers(String token,
      {required String relation}) async {
    final response = await _client.get(
      _api('/users/search?q='),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('用户列表加载失败');
    }
    final rows = decoded['users'];
    if (rows is! List) throw Exception('用户列表数据格式错误');
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String token) =>
      fetchUsers(token, relation: 'history');

  Future<Map<String, dynamic>> postMediaUploadUrl({
    required String token,
    required String fileName,
    required String contentType,
    required String kind,
  }) async {
    final uri = _api('/media/post/upload-url').replace(queryParameters: {
      'fileName': fileName,
      'contentType': contentType,
      'kind': kind,
    });
    final response = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('动态媒体上传地址获取失败');
    }
    return decoded;
  }

  Future<String> mediaUrlForKey(String token, String key) async {
    final uri = _api('/media/url').replace(queryParameters: {'key': key});
    final response = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic> || decoded['url'] is! String) {
      throw Exception('动态媒体地址获取失败');
    }
    return decoded['url'] as String;
  }

  Future<Map<String, dynamic>> avatarUploadUrl({
    required String token,
    required String fileName,
    required String contentType,
  }) async {
    final uri = _api('/media/avatar/upload-url').replace(queryParameters: {
      'fileName': fileName,
      'contentType': contentType,
    });
    final response = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic>) {
      throw Exception('头像上传地址获取失败');
    }
    return decoded;
  }

  Future<bool> uploadAvatar({
    required String url,
    required List<int> bytes,
    required String contentType,
  }) async {
    final response = await _client.put(
      Uri.parse(url),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<String> avatarUrl(String token, String objectKey) async {
    final uri = _api('/api/media/avatar/url').replace(queryParameters: {'key': objectKey});
    final response = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map<String, dynamic> || decoded['url'] is! String) {
      throw Exception('头像地址获取失败');
    }
    return decoded['url'] as String;
  }

  Future<String?> resolveAvatarUrl(String token, Object? avatarKey) async {
    final key = '${avatarKey ?? ''}'.trim();
    if (key.isEmpty) return null;
    return avatarUrl(token, key);
  }
  Future<Map<String, dynamic>> fetchMe(String token) async {
    final data = await _fetchObject(token, '/api/me');
    final user = data['user'];
    return user is Map<String, dynamic> ? user : data;
  }

  Future<Map<String, dynamic>> updateMe({
    required String token,
    String? nickname,
    String? gender,
    String? city,
    String? avatarKey,
  }) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (nickname != null) 'nickname': nickname,
        if (gender != null) 'gender': gender,
        if (city != null) 'city': city,
        if (avatarKey != null) 'avatarKey': avatarKey,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '资料保存失败'}');
    }
    return decoded['user'] is Map<String, dynamic>
        ? (decoded['user'] as Map<String, dynamic>)
        : decoded as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLocation({
      required String token,
      required double latitude,
      required double longitude,
      String? city}) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      }),
    );
    return _decodeResponse(response, '定位更新失败');
  }

  Future<Map<String, dynamic>> _fetchObject(String token, String path) async {
    final response = await _client
        .get(_base.resolve(path), headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error'] ?? '资料加载失败')
          : '资料加载失败';
      throw Exception('$message');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('资料数据格式错误');
    }
    return decoded;
  }

  Future<void> deletePost(String token, int postId) async {
    final response = await _client.delete(_api('/posts/$postId'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception('${decoded['error'] ?? '删除动态失败'}');
    }
  }

  Future<void> reportPost(
      {required String token,
      required int postId,
      required String reason}) async {
    final response = await _client.post(
      _api('/posts/$postId/report'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '举报动态失败'}');
    }
  }

  Future<void> toggleLike(String token, int postId) =>
      _postAction(token, postId, 'like');

  Future<void> toggleFavorite(String token, int postId) =>
      _postAction(token, postId, 'favorite');

  Future<void> _postAction(String token, int postId, String action) async {
    final response = await _client.post(
      _api('/posts/$postId/$action'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('操作失败（${response.statusCode}）');
    }
  }

  void dispose() => _client.close();
}
