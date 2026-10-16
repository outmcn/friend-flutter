import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'post_service.dart';

// 每个标签独立持有请求状态和滚动位置，切换不销毁列表。
class DiscoverFeed extends ChangeNotifier {
  DiscoverFeed(this.fetch, {this.cacheKey});
  final Future<List<DDPost>> Function(int offset) fetch;
  final String? cacheKey;
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

  void updateFavorite(DDPost post) {
    final index = posts.indexWhere((item) => item.id == post.id);
    if (disposed || index < 0) return;
    final updated = posts[index].copyWith(
      favorited: post.favorited,
      favorites: post.favorites,
    );
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
  bool restoring = false;

  Future<void> restoreCache() async {
    if (cacheKey == null || disposed) return;
    restoring = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey!);
    if (raw == null || raw.isEmpty) {
      restoring = false;
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => DDPost.fromJson(item, preserveMediaKeys: true))
          .toList();
      if (restored.isEmpty || disposed) return;
      posts
        ..clear()
        ..addAll(restored);
      offset = restored.length;
      initialized = true;
      hasMore = true;
      notifyListeners();
    } catch (_) {
    } finally {
      restoring = false;
      if (!disposed) notifyListeners();
    }
  }

  Future<void> _saveCache() async {
    if (cacheKey == null || disposed || posts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cacheKey!,
      jsonEncode(posts.map((post) => post.toJson()).toList()),
    );
  }

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
      await _saveCache();
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
