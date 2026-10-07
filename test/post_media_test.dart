import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dd/post_service.dart';

void main() {
  test('缓存中的媒体对象使用认证接口重新签名', () async {
    final requests = <http.Request>[];
    final service = DDPostService(client: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode({
            'url':
                'https://media.test/${request.url.queryParameters['key']}?signed=1'
          }),
          200);
    }));
    final post = DDPost.fromJson({
      'id': 1,
      'avatar': 'avatars/me.png',
      'imageUrl': 'posts/photo.png',
      'videoUrl': 'posts/video.mp4',
      'thumbnailUrl': 'posts/cover.png',
    }, preserveMediaKeys: true);
    final resolved = await service.resolvePostMedia('test-token', post);
    expect(requests.length, 4);
    expect(
        requests
            .every((r) => r.headers['Authorization'] == 'Bearer test-token'),
        isTrue);
    expect(resolved.videoUrl, 'https://media.test/posts/video.mp4?signed=1');
    expect(post.videoUrl, 'posts/video.mp4');
    await service.resolvePostMedia('test-token', resolved);
    expect(requests.length, 4);
    service.dispose();
  });
  test('过期签名恢复对象路径后重新签名', () async {
    String? key;
    final service = DDPostService(client: MockClient((request) async {
      key = request.url.queryParameters['key'];
      return http.Response(
          jsonEncode({'url': 'https://media.test/new.png'}), 200);
    }));
    final post = DDPost.fromJson(
        {'id': 1, 'imageUrl': 'https://media.test/posts/a.png?Expires=1'});
    final resolved = await service.resolvePostMedia('test-token', post);
    expect(key, 'posts/a.png');
    expect(resolved.imageUrl, 'https://media.test/new.png');
    service.dispose();
  });
}
