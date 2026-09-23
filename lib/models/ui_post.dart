import 'package:flutter/material.dart';

const imageOrigin = 'https://friend.outmcn.net';

class UiPost {
  final int id;
  final String text, author, time;
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
    this.comments = 0,
    this.id = 0,
    this.imageUrl,
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
  );
  static String? _normalizeImage(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : 'https://friend.outmcn.net$raw';
  }
}
