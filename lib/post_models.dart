part of 'post_service.dart';

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

String _mediaValue(Object? value, bool preserveKeys) {
  final raw = '${value ?? ''}';
  return preserveKeys ? raw : DDPostService.mediaUrl(raw);
}

String? _nullableMediaValue(Object? value, bool preserveKeys) {
  if (value == null) return null;
  final raw = '$value';
  return raw.trim().isEmpty
      ? null
      : (preserveKeys ? raw : DDPostService.mediaUrl(raw));
}

class DDPost {
  const DDPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.nickname,
    required this.avatar,
    this.gender = '',
    required this.likes,
    required this.favorites,
    required this.comments,
    required this.following,
    this.followedByViewer = false,
    this.distanceKm,
    this.authorCity,
    required this.liked,
    required this.favorited,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    required this.views,
    this.imageWidth,
    this.imageHeight,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.reviewStatus = 'approved',
  });

  final int id;
  final int? userId;
  final String content;
  final String createdAt;
  final String nickname;
  final String avatar;
  final String gender;
  final int likes;
  final int favorites;
  final int comments;
  final bool following;
  final bool followedByViewer;
  final double? distanceKm;
  final String? authorCity;
  final bool liked;
  final bool favorited;
  final String? imageUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int views;
  final int? imageWidth;
  final int? imageHeight;
  final int? thumbnailWidth;
  final int? thumbnailHeight;
  final String reviewStatus;

  DDPost copyWith({
    bool? following,
    bool? liked,
    int? likes,
    bool? favorited,
    int? favorites,
    String? nickname,
    String? avatar,
    String? gender,
  }) =>
      DDPost(
        id: id,
        userId: userId,
        content: content,
        createdAt: createdAt,
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        gender: gender ?? this.gender,
        likes: likes ?? this.likes,
        favorites: favorites ?? this.favorites,
        comments: comments,
        following: following ?? this.following,
        followedByViewer: followedByViewer,
        distanceKm: distanceKm,
        authorCity: authorCity,
        liked: liked ?? this.liked,
        favorited: favorited ?? this.favorited,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        views: views,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        reviewStatus: reviewStatus,
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
        'followedByViewer': followedByViewer,
        'distanceKm': distanceKm,
        'authorCity': authorCity,
        'liked': liked,
        'favorited': favorited,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'views': views,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'thumbnailWidth': thumbnailWidth,
        'thumbnailHeight': thumbnailHeight,
        'reviewStatus': reviewStatus,
      };

  factory DDPost.fromJson(
    Map<String, dynamic> json, {
    bool preserveMediaKeys = false,
  }) =>
      DDPost(
        id: _intValue(json['id']) ?? 0,
        userId: _intValue(json['userId']),
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        nickname: '${json['nickname'] ?? '用户'}',
        avatar: _mediaValue(json['avatar'], preserveMediaKeys),
        gender: '${json['gender'] ?? ''}',
        likes: _intValue(json['likes']) ?? 0,
        favorites: _intValue(json['favorites']) ?? 0,
        comments: _intValue(json['comments']) ?? 0,
        following: json['following'] == true,
        followedByViewer: json['followedByViewer'] == true,
        distanceKm: _doubleValue(json['distanceKm']),
        authorCity: '${json['authorCity'] ?? json['author_city'] ?? ''}',
        liked: json['liked'] == true,
        favorited: json['favorited'] == true,
        imageUrl: _nullableMediaValue(json['imageUrl'], preserveMediaKeys),
        videoUrl: _nullableMediaValue(json['videoUrl'], preserveMediaKeys),
        thumbnailUrl:
            _nullableMediaValue(json['thumbnailUrl'], preserveMediaKeys),
        views: _intValue(json['views']) ?? 0,
        imageWidth: _intValue(json['imageWidth']),
        imageHeight: _intValue(json['imageHeight']),
        thumbnailWidth: _intValue(json['thumbnailWidth']),
        thumbnailHeight: _intValue(json['thumbnailHeight']),
        reviewStatus: '${json['reviewStatus'] ?? json['review_status'] ?? 'approved'}',
      );
}

class DDComment {
  const DDComment(
      {required this.id,
      required this.userId,
      required this.parentId,
      required this.nickname,
      required this.content,
      required this.createdAt,
      this.likes = 0,
      this.liked = false,
      this.city = '',
      this.avatar = ''});
  final int id;
  final int? userId;
  final int? parentId;
  final String nickname;
  final String content;
  final String createdAt;
  final int likes;
  final bool liked;
  final String city;
  final String avatar;
  factory DDComment.fromJson(Map<String, dynamic> json) => DDComment(
        id: _intValue(json['id']) ?? 0,
        userId: _intValue(json['userId']),
        parentId: _intValue(json['parentId']),
        nickname: '${json['nickname'] ?? '用户'}',
        content: '${json['content'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        likes: _intValue(json['likes']) ?? 0,
        liked: json['liked'] == true,
        city: '${json['city'] ?? ''}',
        avatar: '${json['avatar'] ?? json['avatarUrl'] ?? ''}',
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
