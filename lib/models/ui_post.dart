import 'package:flutter/material.dart';

const imageOrigin = 'https://friend.outmcn.net';

class UiPost {
  final int id;
  final int authorId;
  final int authorAvatarId;
  final double? latitude, longitude;
  final String text, author, time;
  final String city;
  final bool following;
  final IconData icon;
  final int likes, favorites, comments;
  final String? imageUrl;
  UiPost(
    this.text,
    this.author,
    this.time,
    this.icon,
    this.likes,
    this.favorites, {
    this.authorId = 0,
    this.authorAvatarId = 0,
    this.latitude,
    this.longitude,
    this.comments = 0,
    this.id = 0,
    this.imageUrl,
    this.city = '',
    this.following = false,
  });
  factory UiPost.fromJson(Map<String, dynamic> json) => UiPost(
    json['content']?.toString() ?? '',
    json['nickname']?.toString() ?? '',
    json['createdAt']?.toString() ?? '',
    Icons.image_outlined,
    (json['likes'] as num?)?.toInt() ?? 0,
    (json['favorites'] as num?)?.toInt() ?? 0,
    comments: (json['comments'] as num?)?.toInt() ?? 0,
    id: (json['id'] as num?)?.toInt() ?? 0,
    imageUrl: _normalizeImage(json['imageURL']),
    authorId:
        (json['userId'] as num?)?.toInt() ??
        (json['authorId'] as num?)?.toInt() ??
        0,
    authorAvatarId: (json['avatarId'] as num?)?.toInt() ?? 0,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    city: json['city']?.toString() ?? '',
    following: json['following'] == true,
  );
  static String? _normalizeImage(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : 'https://friend.outmcn.net$raw';
  }
}
