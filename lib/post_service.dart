import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

part 'post_models.dart';
part 'im_models.dart';

class ImSendException implements Exception {
  const ImSendException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  bool get retryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;
  @override
  String toString() => '$message（HTTP $statusCode）';
}

class DDPostService {
  DDPostService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _base = Uri.parse('https://friend.outmcn.com');
  final http.Client _client;
  static const profileTabCachePrefix = 'dd.profile.tab.cache.';

  Uri _api(String path) =>
      _base.resolve(path.startsWith('/api/') ? path : '/api$path');

  static Future<void> clearProfileTabCaches() async {
    final prefs = await SharedPreferences.getInstance();
    for (var tab = 0; tab < 3; tab++) {
      await prefs.remove('$profileTabCachePrefix$tab');
      await prefs.remove('dd.profile.tab.cache.at.$tab');
      await prefs.remove('dd.profile.my.tab.$tab');
    }
  }

  static String mediaUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('https://')) return raw;
    return '';
  }

  // 缓存保存对象身份，展示时统一换取签名；已有有效签名不重复请求。
  static String mediaKey(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && uri.hasScheme ? uri.pathSegments.join('/') : source;
  }

  static bool _needsMediaSignature(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'https') return true;
    final query = {
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value
    };
    final expires = int.tryParse(query['expires'] ?? '');
    if (expires != null) {
      return DateTime.now().millisecondsSinceEpoch + 60000 >= expires * 1000;
    }
    return false;
  }

  static bool isLikelyExpired(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) return true;
    final query = {
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final expires = int.tryParse(query['expires'] ?? '');
    return expires != null &&
        DateTime.now().millisecondsSinceEpoch >= expires * 1000;
  }

  Future<DDPost> resolvePostMedia(String token, DDPost post) async {
    final data = post.toJson();
    await Future.wait(
        ['avatar', 'imageUrl', 'videoUrl', 'thumbnailUrl'].map((field) async {
      final raw = data[field] as String?;
      if (raw == null || raw.isEmpty) return;
      if (!_needsMediaSignature(raw)) return;
      data[field] = field == 'avatar'
          ? await avatarUrl(token, mediaKey(raw))
          : await mediaUrlForKey(token, mediaKey(raw));
    }));
    return DDPost.fromJson(data, preserveMediaKeys: true);
  }

  Future<String> login(
      {required String username, required String password}) async {
    final response = await _client.post(
      _base.resolve('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '登录失败'}');
    }
    final token = decoded['token'];
    if (token is! String) throw Exception('登录响应格式错误');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friend.auth.token', token);
    final user = decoded['user'];
    if (user is Map && user['id'] != null) {
      await prefs.setString('friend.auth.userId', '${user['id']}');
    }
    return token;
  }

  Future<List<DDConversation>> fetchImConversations(String token) async {
    final response = await _client.get(
      _api('/im/conversations'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['conversations'] is! List) {
      throw Exception('会话加载失败');
    }
    return (data['conversations'] as List)
        .whereType<Map>()
        .map((item) => DDConversation.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> createWerewolfRoom(String token) async =>
      _werewolfPost(token, '/werewolf/rooms', {});
  Future<Map<String, dynamic>> joinWerewolfRoom(
          String token, String code) async =>
      _werewolfPost(token, '/werewolf/rooms/join', {'roomCode': code});
  Future<Map<String, dynamic>> takeWerewolfSeat(
          String token, String roomId, int seat) async =>
      _werewolfPost(token, '/werewolf/rooms/$roomId/seat', {'seat': seat});
  Future<Map<String, dynamic>> readyWerewolfRoom(
          String token, String roomId, bool ready) async =>
      _werewolfPost(token, '/werewolf/rooms/$roomId/ready', {'ready': ready});
  Future<Map<String, dynamic>> startWerewolfMatch(String token) async =>
      _werewolfPost(token, '/werewolf/match/start', {});
  Future<Map<String, dynamic>> stopWerewolfMatch(String token) async =>
      _werewolfPost(token, '/werewolf/match/stop', {});
  Future<Map<String, dynamic>> _werewolfPost(
      String token, String path, Map<String, dynamic> body) async {
    final response = await _client.post(_api(path),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body));
    final value = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        value is! Map) {
      throw Exception(
          value is Map ? '${value['error'] ?? '狼人杀操作失败'}' : '狼人杀操作失败');
    }
    return value.cast<String, dynamic>();
  }

  Future<String> createDirectConversation(String token, String peerId) async {
    final response = await _client.post(
      _api('/im/conversations/direct'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'peerId': peerId}),
    );
    final data = jsonDecode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        data is! Map ||
        data['conversationId'] == null) {
      throw Exception(data is Map ? '${data['error'] ?? '会话创建失败'}' : '会话创建失败');
    }
    return '${data['conversationId']}';
  }

  Future<Map<String, dynamic>> recallImMessage(
      String token, String conversationId, String messageId) async {
    final response = await _client.post(
      _api('/im/conversations/$conversationId/messages/$messageId/recall'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data =
        response.body.trim().isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['message'] is! Map) {
      throw Exception(data is Map ? '${data['error'] ?? '撤回失败'}' : '撤回失败');
    }
    return (data['message'] as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchPendingImCalls(String token) async {
    final response = await _client.get(
      _api('/im/calls/pending'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data =
        response.body.trim().isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['calls'] is! List) {
      throw Exception(data is Map ? '${data['error'] ?? '获取来电失败'}' : '获取来电失败');
    }
    return (data['calls'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> startImCall(
      String token, String conversationId) async {
    final response = await _client.post(
        _api('/im/conversations/$conversationId/calls'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'kind': 'audio'}));
    final data =
        response.body.trim().isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != 201 || data is! Map || data['call'] is! Map) {
      throw Exception(data is Map ? '${data['error'] ?? '发起通话失败'}' : '发起通话失败');
    }
    return data.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateImCall(
      String token, String callId, String action) async {
    final response = await _client.post(_api('/im/calls/$callId/action'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'action': action}));
    final data =
        response.body.trim().isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['call'] is! Map) {
      throw Exception(data is Map ? '${data['error'] ?? '通话操作失败'}' : '通话操作失败');
    }
    return data.cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchImCallRecords(
      String token, String conversationId) async {
    final response = await _client.get(
      _api('/im/conversations/$conversationId/calls'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data =
        response.body.trim().isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['calls'] is! List) {
      throw Exception(
          data is Map ? '${data['error'] ?? '获取通话记录失败'}' : '获取通话记录失败');
    }
    return (data['calls'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> sendImMessage(
    String token,
    String conversationId, {
    required String text,
    required String clientId,
    String kind = 'text',
    int durationMs = 0,
    Map<String, dynamic>? metadata,
  }) async {
    if (token.trim().isEmpty) throw const ImSendException(401, '请先登录');
    final response = await _client.post(
      _api('/im/conversations/$conversationId/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'clientId': clientId,
        'kind': kind,
        if (durationMs > 0) 'durationMs': durationMs,
        if (metadata != null) 'metadata': metadata,
      }),
    );
    if (response.statusCode != 201) {
      throw ImSendException(response.statusCode,
          response.statusCode == 401 ? '登录状态已失效，请重新登录' : '消息发送失败');
    }
    // 201 itself is authoritative, even if a proxy damaged the response body.
    final fallback = <String, dynamic>{
      'conversationId': conversationId,
      'clientId': clientId,
      'text': text,
      'kind': kind,
      'metadata': metadata,
    };
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is Map) {
        return {...fallback, ...Map<String, dynamic>.from(data['message'])};
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> reportImMessage(String token, String conversationId,
      String messageId, String reason) async {
    final response = await _client
        .post(
          _api('/im/conversations/$conversationId/messages/$messageId/report'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic>? body;
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    }
    if (response.statusCode != 201 || body?['reported'] != true) {
      throw Exception(body?['error'] ?? '举报消息失败');
    }
  }

  Future<void> markImConversationRead(
      String token, String conversationId, String messageId) async {
    final response = await _client.post(
      _api('/im/conversations/$conversationId/read'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'messageId': messageId}),
    );
    if (response.statusCode != 200) {
      throw Exception('已读状态更新失败');
    }
  }

  Future<List<DDImMessage>> fetchImMessages(
    String token,
    String conversationId, {
    String? afterId,
    String? beforeId,
  }) async {
    final uri = _api('/im/conversations/$conversationId/messages').replace(
      queryParameters: {
        'limit': '50',
        if (afterId != null && afterId.isNotEmpty) 'afterId': afterId,
        if (beforeId != null && beforeId.isNotEmpty) 'beforeId': beforeId,
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['messages'] is! List) {
      throw Exception('消息加载失败');
    }
    return (data['messages'] as List)
        .whereType<Map>()
        .map((item) => DDImMessage.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchImTimeline(
      String token, String conversationId) async {
    final response = await _client.get(
      _api('/im/conversations/$conversationId/timeline'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('聊天详情请求失败：HTTP ${response.statusCode}');
    }
    if (body.isEmpty) throw Exception('聊天详情返回为空');
    final data = jsonDecode(body);
    if (data is! Map || data['items'] is! List) {
      throw Exception('聊天详情数据格式错误');
    }
    return (data['items'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> syncImMessages(
    String token,
    String conversationId,
    String afterMutationId, {
    int limit = 100,
  }) async {
    final uri = _api('/im/conversations/$conversationId/sync').replace(
      queryParameters: {
        'afterMutationId': afterMutationId,
        'limit': '$limit',
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['messages'] is! List) {
      throw Exception('消息同步失败');
    }
    return {
      'messages': (data['messages'] as List)
          .whereType<Map>()
          .map((item) => DDImMessage.fromJson(item.cast<String, dynamic>()))
          .toList(),
      'nextMutationId': '${data['nextMutationId'] ?? afterMutationId}',
      'hasMore': data['hasMore'] == true,
    };
  }

  Future<Map<String, dynamic>> reconcilePending(
    String token,
    String conversationId,
    String clientId,
  ) async {
    if (token.trim().isEmpty) throw const ImSendException(401, '请先登录');
    final response = await _client.get(
      _api('/im/conversations/$conversationId/messages/by-client/$clientId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw ImSendException(response.statusCode,
          response.statusCode == 401 ? '登录状态已失效，请重新登录' : '消息状态查询失败');
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is Map) {
        return Map<String, dynamic>.from(data['message']);
      }
    } catch (_) {}
    return {'conversationId': conversationId, 'clientId': clientId};
  }

  Future<void> confirmImMessagesSynced(
    String token,
    String conversationId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;
    final response = await _client.post(
      _api('/im/conversations/$conversationId/messages/sync-confirm'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'messageIds': messageIds}),
    );
    if (response.statusCode != 200) {
      throw Exception('消息同步确认失败');
    }
  }

  Future<List<DDNotification>> fetchNotifications(String token) async =>
      <DDNotification>[];

  Future<void> markNotificationsRead(String token) async {}

  Future<List<DDPost>> fetchPosts(
    String token, {
    int offset = 0,
    int limit = 30,
    bool followingFeed = false,
  }) async {
    final uri = _api('/posts').replace(queryParameters: {
      'offset': '$offset',
      'limit': '$limit',
      if (followingFeed) 'following': '1',
    });
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('动态数据格式错误');
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => DDPost.fromJson(row, preserveMediaKeys: true))
        .toList();
  }

  Future<List<DDPost>> fetchNearbyPosts(
    String token, {
    int offset = 0,
    int limit = 30,
  }) async {
    final uri = _api('/posts/local').replace(queryParameters: {
      'offset': '$offset',
      'limit': '$limit',
    });
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('本地动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('本地动态数据格式错误');
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => DDPost.fromJson(row, preserveMediaKeys: true))
        .toList();
  }

  Future<List<DDPost>> fetchFollowingPosts(
    String token, {
    int offset = 0,
    int limit = 30,
  }) =>
      fetchPosts(token, offset: offset, limit: limit, followingFeed: true);

  Future<List<DDPost>> fetchRecommendedPosts(
    String token, {
    int offset = 0,
    int limit = 30,
  }) async {
    final uri = _api('/posts/recommended').replace(queryParameters: {
      'offset': '$offset',
      'limit': '$limit',
    });
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('推荐动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('推荐动态数据格式错误');
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => DDPost.fromJson(row, preserveMediaKeys: true))
        .toList();
  }

  Future<DDPost> fetchPost(String token, int postId) async {
    final response = await _client.get(
      _api('/posts/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded =
          response.body.trim().isEmpty ? null : jsonDecode(response.body);
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] ?? '动态加载失败'
          : '动态加载失败';
      throw Exception('$message（${response.statusCode}）');
    }
    if (response.body.trim().isEmpty) {
      throw Exception('动态加载失败：服务器返回空响应');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['post'] is! Map) {
      throw Exception('动态数据格式错误');
    }
    return DDPost.fromJson((decoded['post'] as Map).cast<String, dynamic>(),
        preserveMediaKeys: true);
  }

  Future<List<DDPost>> fetchMyPosts(String token, {int offset = 0}) async {
    return _fetchProfilePosts(token, '/me/posts', offset: offset);
  }

  Future<List<DDPost>> fetchLikedPosts(String token, {int offset = 0}) async {
    return _fetchProfilePosts(token, '/me/liked-posts', offset: offset);
  }

  Future<List<DDPost>> fetchFavoritedPosts(String token, {int offset = 0}) async {
    return _fetchProfilePosts(token, '/me/favorited-posts', offset: offset);
  }

  Future<List<DDPost>> _fetchProfilePosts(String token, String path, {int offset = 0}) async {
    final response = await _client.get(
      Uri.parse('${_api(path)}?offset=$offset&limit=30'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('我的动态加载失败');
    }
    final rows = decoded['posts'];
    if (rows is! List) throw Exception('动态数据格式错误');
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => DDPost.fromJson(row, preserveMediaKeys: true))
        .toList();
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
      String? videoUrl,
      String? thumbnailUrl,
      int? imageWidth,
      int? imageHeight,
      int? thumbnailWidth,
      int? thumbnailHeight,
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
    if (imageWidth != null) body['imageWidth'] = imageWidth;
    if (imageHeight != null) body['imageHeight'] = imageHeight;
    if (thumbnailWidth != null) body['thumbnailWidth'] = thumbnailWidth;
    if (thumbnailHeight != null) body['thumbnailHeight'] = thumbnailHeight;
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
    if (response.body.trim().isEmpty) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('评论数据格式错误');
    final comments = decoded
        .whereType<Map<String, dynamic>>()
        .map(DDComment.fromJson)
        .toList();
    await Future.wait(comments.map((comment) async {
      final raw = comment.avatar.trim();
      if (raw.isEmpty || raw.startsWith('https://')) return;
      try {
        final signed = await avatarUrl(token, mediaKey(raw));
        final index = comments.indexOf(comment);
        if (index >= 0) {
          comments[index] = DDComment(
            id: comment.id,
            userId: comment.userId,
            parentId: comment.parentId,
            nickname: comment.nickname,
            content: comment.content,
            createdAt: comment.createdAt,
            likes: comment.likes,
            liked: comment.liked,
            city: comment.city,
            avatar: signed,
          );
        }
      } catch (_) {}
    }));
    return comments;
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

  Future<bool> toggleCommentLike(String token, int commentId) async {
    final response = await _client.post(
      _api('/comments/$commentId/like'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '评论点赞失败'}');
    }
    return decoded['liked'] == true;
  }

  Future<void> deleteComment(String token, int commentId) async {
    final response = await _client.delete(
      _api('/comments/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.trim();
      final decoded = body.isEmpty ? null : jsonDecode(body);
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] ?? '删除评论失败'
          : '删除评论失败';
      throw Exception('$message（${response.statusCode}）');
    }
    // 删除接口允许返回 204 空响应，成功时不再解析响应体。
  }

  Future<void> reportComment({
    required String token,
    required int commentId,
    required String reason,
  }) async {
    final response = await _client
        .post(
          _api('/comments/$commentId/report'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
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

  Future<bool> fetchUserBlocked(String token, int userId) async {
    final response = await _client.get(
      _api('/users/$userId/block-status'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['blocked'] is! bool) {
      throw Exception('拉黑状态加载失败');
    }
    return decoded['blocked'] as bool;
  }

  Future<bool> toggleUserBlock(String token, int userId) async {
    final response = await _client.post(
      _api('/users/$userId/block'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['blocked'] is! bool) {
      throw Exception(
          decoded is Map ? '${decoded['error'] ?? '拉黑操作失败'}' : '拉黑操作失败');
    }
    return decoded['blocked'] as bool;
  }

  Future<bool> toggleFollow(String token, int userId) async {
    final response = await _client.post(
      _api('/users/$userId/follow'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('${decoded['error'] ?? '关注操作失败'}');
    }
    return decoded['followed'] == true;
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

  Future<Map<String, dynamic>> fetchUserProfile(
      String token, int userId) async {
    final response = await _client.get(
      _api('/users/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('用户资料加载失败');
    }
    return decoded['user'] is Map<String, dynamic>
        ? decoded['user'] as Map<String, dynamic>
        : decoded;
  }

  Future<List<Map<String, dynamic>>> fetchUsers(String token,
      {required String relation}) async {
    final uri = _api('/users/search').replace(queryParameters: {
      'q': '',
      'relation': relation,
    });
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('用户列表加载失败');
    }
    final rows = decoded['users'];
    if (rows is! List) throw Exception('用户列表数据格式错误');
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchMutualFriends(String token) async {
    final response = await _client.get(
      _api('/users/mutual'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['users'] is! List) {
      throw Exception('互关好友加载失败');
    }
    return (data['users'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }


  Future<List<Map<String, dynamic>>> searchUsers(
      String token, String query) async {
    final uri = _api('/users/search').replace(queryParameters: {
      'q': query,
    });
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['users'] is! List) {
      throw Exception('用户搜索失败');
    }
    return (decoded['users'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

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
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('动态媒体上传地址获取失败');
    }
    return decoded;
  }

  Future<String> mediaUrlForKey(String token, String key) async {
    final uri = _api('/media/url').replace(queryParameters: {'key': key});
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic> ||
        decoded['url'] is! String) {
      throw Exception('动态媒体地址获取失败');
    }
    return decoded['url'] as String;
  }

  Future<Map<String, dynamic>> voiceUploadUrl({
    required String token,
    required String fileName,
    required String contentType,
  }) async {
    final uri = _api('/media/voice/upload-url').replace(queryParameters: {
      'fileName': fileName,
      'contentType': contentType,
    });
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw Exception('声音上传地址获取失败');
    }
    return decoded;
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
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
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
    final uri = _api('/api/media/avatar/url')
        .replace(queryParameters: {'key': objectKey});
    final response =
        await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic> ||
        decoded['url'] is! String) {
      throw Exception('头像地址获取失败');
    }
    return decoded['url'] as String;
  }

  Future<String?> resolveAvatarUrl(String token, Object? avatarKey) async {
    final key = '${avatarKey ?? ''}'.trim();
    if (key.isEmpty) return null;
    return avatarUrl(token, key);
  }

  Future<Map<String, dynamic>> updatePreferences(
      String token, {
      bool? antiHarassment,
      bool? smartBlock,
      bool? matchingEnabled,
      }) async {
    final response = await _client.patch(
      _api('/me/preferences'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (antiHarassment != null) 'antiHarassment': antiHarassment,
        if (smartBlock != null) 'smartBlock': smartBlock,
        if (matchingEnabled != null) 'matchingEnabled': matchingEnabled,
      }),
    );
    return _decodeResponse(response, '设置更新失败');
  }

  Future<Map<String, dynamic>> setPresence(String token, String mode) async {
    final response = await _client.patch(
      _api('/me/presence'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'mode': mode}),
    );
    return _decodeResponse(response, '在线状态更新失败');
  }

  Future<Map<String, dynamic>> presenceHeartbeat(String token) async {
    final response = await _client.post(
      _api('/me/presence/heartbeat'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _decodeResponse(response, '在线状态心跳失败');
  }

  Future<Map<String, dynamic>> fetchMe(String token) async {
    final data = await _fetchObject(token, '/api/me');
    final user = data['user'];
    return user is Map<String, dynamic> ? user : data;
  }

  Future<Map<String, dynamic>> updateMe({
    required String token,
    String? nickname,
    String? signature,
    String? gender,
    String? city,
    String? avatarKey,
    String? voiceKey,
    List<String>? tags,
  }) async {
    final response = await _client.put(
      _base.resolve('/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (nickname != null) 'nickname': nickname,
        if (signature != null) 'signature': signature,
        if (gender != null) 'gender': gender,
        if (city != null) 'city': city,
        if (avatarKey != null) 'avatarKey': avatarKey,
        if (voiceKey != null) 'voiceKey': voiceKey,
        if (tags != null) 'tags': tags,
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

  Future<Map<String, dynamic>> updateLocation(
      {required String token,
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

  Future<List<Map<String, dynamic>>> fetchCharmSources(String token) =>
      fetchObjectList(token, '/api/me/charm-sources', 'sources');

  Future<List<Map<String, dynamic>>> fetchMyGifts(String token) =>
      fetchObjectList(token, '/api/me/gifts', 'gifts');

  Future<List<Map<String, dynamic>>> fetchMyUserGifts(String token) =>
      fetchObjectList(token, '/api/me/user-gifts', 'gifts');

  Future<List<Map<String, dynamic>>> fetchGiftItems(
      String token, {required String scope}) =>
      fetchObjectList(token, '/api/gifts?scope=$scope', 'gifts');

  Future<Map<String, dynamic>> sendUserGift({
    required String token,
    required int userId,
    required int giftId,
    int quantity = 1,
  }) async {
    final response = await _client.post(
      _api('/users/$userId/gifts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'giftId': giftId, 'quantity': quantity}),
    );
    return _decodeResponse(response, '送礼失败');
  }

  Future<List<Map<String, dynamic>>> fetchUserGifts(String token, int userId) =>
      fetchObjectList(token, '/users/$userId/gifts', 'gifts');

  Future<Map<String, dynamic>> sendPostGift({
    required String token,
    required int postId,
    required int giftId,
    int quantity = 1,
  }) async {
    final response = await _client.post(
      _api('/posts/$postId/gifts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'giftId': giftId, 'quantity': quantity}),
    );
    return _decodeResponse(response, '送礼失败');
  }

  Future<List<Map<String, dynamic>>> fetchObjectList(
      String token, String path, String key) async {
    final data = await _fetchObject(token, path);
    final raw = data[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
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
      final decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception('${decoded['error'] ?? '删除动态失败'}');
    }
  }

  Future<void> reportPost(
      {required String token,
      required int postId,
      required String reason}) async {
    final response = await _client
        .post(
          _api('/posts/$postId/report'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
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
