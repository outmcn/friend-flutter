import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friend_app/models/ui_post.dart';

void main() {
  test('UiPost.fromJson normalizes fields and image URL', () {
    final post = UiPost.fromJson({
      'id': 7,
      'userId': 3,
      'content': 'hello',
      'nickname': '小明',
      'createdAt': '2026-01-01T00:00:00Z',
      'likes': 2,
      'favorites': 1,
      'comments': 4,
      'imageURL': '/uploads/a.jpg',
      'following': true,
    });
    expect(post.id, 7);
    expect(post.authorId, 3);
    expect(post.text, 'hello');
    expect(post.likes, 2);
    expect(post.comments, 4);
    expect(post.imageUrl, 'https://friend.outmcn.net/uploads/a.jpg');
    expect(post.following, isTrue);
    expect(post.icon, Icons.image_outlined);
  });
}
