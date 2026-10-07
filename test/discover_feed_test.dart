import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dd/discover_feed.dart';
import 'package:dd/post_service.dart';

DDPost post(int id) => DDPost.fromJson({'id': id});

void main() {
  test('标签独立加载，重复请求被合并，切换不丢弃响应', () async {
    final response = Completer<List<DDPost>>();
    var calls = 0;
    final first = DiscoverFeed((_) {
      calls++;
      return response.future;
    });
    final second = DiscoverFeed((_) async => [post(2)]);
    final loading = first.load();
    await first.load();
    await second.load();
    response.complete([post(1)]);
    await loading;
    expect(calls, 1);
    expect(first.posts.single.id, 1);
    expect(second.posts.single.id, 2);
    expect(identical(first.scroll, second.scroll), isFalse);
    first.dispose();
    second.dispose();
  });

  test('去重后按响应数量分页，刷新失败保留已有内容', () async {
    final offsets = <int>[];
    var fail = false;
    final feed = DiscoverFeed((offset) async {
      offsets.add(offset);
      if (fail) throw Exception('网络错误');
      return offset == 0 ? List.generate(30, post) : [post(29), post(30)];
    });
    await feed.load();
    await feed.load();
    expect(offsets, [0, 30]);
    expect(feed.offset, 32);
    expect(feed.posts.length, 31);
    expect(feed.hasMore, isFalse);
    fail = true;
    await feed.load(refresh: true);
    expect(feed.posts.length, 31);
    expect(feed.error, '网络错误');
    fail = false;
    await feed.load(refresh: true);
    expect(feed.offset, 30);
    expect(feed.hasMore, isTrue);
    feed.dispose();
  });

  test('销毁后收到响应不会更新状态或发送通知', () async {
    final response = Completer<List<DDPost>>();
    final feed = DiscoverFeed((_) => response.future);
    final loading = feed.load();
    feed.dispose();
    response.complete([post(1)]);
    await loading;
    expect(feed.posts, isEmpty);
  });
}
