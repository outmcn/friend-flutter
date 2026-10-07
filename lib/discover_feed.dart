import 'package:flutter/widgets.dart';
import 'post_service.dart';

// 每个标签独立持有请求状态和滚动位置，切换不销毁列表。
class DiscoverFeed extends ChangeNotifier {
  DiscoverFeed(this.fetch);
  final Future<List<DDPost>> Function(int offset) fetch;
  final scroll = ScrollController();
  final posts = <DDPost>[];
  final postChanges = ValueNotifier<DDPost?>(null);

  void updateLike(DDPost post) {
    final index = posts.indexWhere((item) => item.id == post.id);
    if (disposed || index < 0) return;
    final updated = posts[index].copyWith(liked: post.liked, likes: post.likes);
    posts[index] = updated;
    postChanges.value = updated;
  }

  void markChanged() {
    if (!disposed) notifyListeners();
  }

  int offset = 0;
  bool initialized = false;
  bool busy = false;
  bool hasMore = true;
  bool disposed = false;
  String? error;

  Future<void> load({bool refresh = false}) async {
    if (disposed || busy || (!refresh && initialized && !hasMore)) return;
    busy = true;
    error = null;
    // 分页加载期间保留已有卡片，避免滚动时把整张瀑布流替换成加载状态。
    if (!refresh) notifyListeners();
    try {
      final batch = await fetch(refresh ? 0 : offset);
      if (disposed) return;
      if (refresh) {
        posts.clear();
        offset = 0;
      }
      // 分页游标按服务端返回数量推进，去重不能影响游标。
      offset += batch.length;
      final ids = posts.map((post) => post.id).toSet();
      posts.addAll(batch.where((post) => ids.add(post.id)));
      hasMore = batch.length == 30;
      initialized = true;
    } catch (e) {
      if (!disposed) error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    scroll.dispose();
    postChanges.dispose();
    super.dispose();
  }
}
