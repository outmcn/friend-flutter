import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ui_post.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/post_card.dart';
import '../widgets/profile_card.dart';

class ProfilePage extends StatefulWidget {
  final String token;

  const ProfilePage({super.key, required this.token});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String nickname = '';
  int following = 0;
  int followers = 0;
  int likes = 0;
  int postCount = 0;
  int activeDays = 0;
  int selectedAvatar = 0;
  String city = '';
  bool loading = true;
  int section = 0;
  List<UiPost> ownPosts = [];
  List<UiPost> favoritePosts = [];
  List<UiPost> likedPosts = [];
  late final ApiClient _api;
  final _location = LocationService();

  static const avatarIcons = <IconData>[
    Icons.public,
    Icons.auto_awesome,
    Icons.favorite,
    Icons.bolt,
    Icons.nightlight_round,
    Icons.local_florist,
    Icons.pets,
    Icons.music_note,
    Icons.rocket_launch,
    Icons.face,
  ];

  @override
  void initState() {
    super.initState();
    _api = ApiClient(token: widget.token);
    _loadAvatar();
    refreshFromServer();
    _updateCity();
  }

  Future<void> _updateCity() async {
    try {
      final value = await _location.city();
      if (value == null || value.isEmpty) return;
      await _api.put('/api/me', body: {'city': value});
      if (mounted) setState(() => city = value);
    } catch (_) {
      if (mounted) _showMessage('城市更新失败');
    }
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => selectedAvatar = prefs.getInt('friend.selected.avatar') ?? 0,
      );
    }
  }

  Future<void> refreshFromServer() async {
    try {
      final body = await _api.get('/api/me/summary');
      final data = body['data'];
      if (body['ok'] == true && data is Map<String, dynamic> && mounted) {
        final profile = data['profile'] as Map<String, dynamic>;
        setState(() {
          nickname =
              (profile['nickname']?.toString().trim().isNotEmpty == true
                      ? profile['nickname']
                      : profile['username'])
                  .toString();
          following = (profile['following'] as num?)?.toInt() ?? 0;
          followers = (profile['followers'] as num?)?.toInt() ?? 0;
          likes = (profile['likes'] as num?)?.toInt() ?? 0;
          postCount = (profile['posts'] as num?)?.toInt() ?? 0;
          activeDays = (profile['activeDays'] as num?)?.toInt() ?? 0;
          city = profile['city']?.toString() ?? city;
          selectedAvatar =
              (profile['avatarId'] as num?)?.toInt() ?? selectedAvatar;
          ownPosts = _posts(data['posts']);
          favoritePosts = _posts(data['favorited']);
          likedPosts = _posts(data['liked']);
          loading = false;
        });
      } else if (mounted) {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  List<UiPost> _posts(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().map(UiPost.fromJson).toList()
      : <UiPost>[];

  Future<void> _confirmDelete(UiPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除动态'),
        content: const Text('确定要删除这条动态吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deletePost(post);
  }

  Future<void> _deletePost(UiPost post) async {
    try {
      await _api.delete('/api/posts/${post.id}');
      await refreshFromServer();
    } catch (_) {
      if (mounted) _showMessage('删除失败');
    }
  }

  Future<void> _pickAvatar() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择头像'),
        content: SizedBox(
          width: 320,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: avatarIcons.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) => InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context, index),
              child: CircleAvatar(
                backgroundColor: _avatarColor(index),
                child: Icon(avatarIcons[index], color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await _api.put('/api/me', body: {'avatarId': chosen});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('friend.selected.avatar', chosen);
      if (mounted) setState(() => selectedAvatar = chosen);
    } catch (_) {
      if (mounted) _showMessage('头像更新失败');
    }
  }

  Color _avatarColor(int index) => <Color>[
    const Color(0xff376bd6),
    const Color(0xff7c4dff),
    const Color(0xffe64a75),
    const Color(0xff00897b),
    const Color(0xff3949ab),
    const Color(0xff43a047),
    const Color(0xfffb8c00),
    const Color(0xff8e24aa),
    const Color(0xff039be5),
    const Color(0xff546e7a),
  ][index];

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: nickname);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '输入新的名字'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _api.put('/api/me', body: {'nickname': value});
      if (mounted) setState(() => nickname = value);
    } catch (_) {
      if (mounted) _showMessage('昵称更新失败');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = section == 0
        ? ownPosts
        : section == 1
        ? favoritePosts
        : likedPosts;

    return Column(
      children: [
        const HomeTopBar(showTitle: false),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refreshFromServer,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ProfileCard(
                  nickname: loading
                      ? '加载中…'
                      : (nickname.isEmpty ? 'Friend 用户' : nickname),
                  city: city,
                  following: following,
                  followers: followers,
                  likes: likes,
                  posts: postCount,
                  activeDays: activeDays,
                  avatarId: selectedAvatar,
                  onAvatarTap: _pickAvatar,
                  showEdit: true,
                  onEdit: _editNickname,
                ),
                const SizedBox(height: 14),
                _profileMenuSection(context, [
                  _profileMenuItem(
                    context,
                    Icons.dynamic_feed_outlined,
                    '动态',
                    () => _showSection(0),
                  ),
                  _profileMenuItem(
                    context,
                    Icons.bookmark_border,
                    '收藏',
                    () => _showSection(1),
                  ),
                  _profileMenuItem(
                    context,
                    Icons.thumb_up_alt_outlined,
                    '点赞',
                    () => _showSection(2),
                  ),
                ]),
                const SizedBox(height: 12),
                _profileMenuSection(context, [
                  _profileMenuItem(
                    context,
                    Icons.sports_esports_outlined,
                    '好友游戏',
                    () => _showNotReady('好友游戏'),
                  ),
                  _profileMenuItem(
                    context,
                    Icons.account_balance_wallet_outlined,
                    '卡包',
                    () => _showNotReady('卡包'),
                  ),
                  _profileMenuItem(
                    context,
                    Icons.emoji_emotions_outlined,
                    '表情',
                    () => _showNotReady('表情'),
                  ),
                ]),
                const SizedBox(height: 12),
                _profileMenuSection(context, [
                  _profileMenuItem(
                    context,
                    Icons.settings_outlined,
                    '设置',
                    () => _showNotReady('设置'),
                  ),
                ]),
                const SizedBox(height: 20),
                Text(
                  section == 0
                      ? '我的动态'
                      : section == 1
                      ? '我的收藏'
                      : '我的点赞',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('动态')),
                    ButtonSegment(value: 1, label: Text('收藏')),
                    ButtonSegment(value: 2, label: Text('点赞')),
                  ],
                  selected: {section},
                  onSelectionChanged: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() => section = selected.first);
                  },
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                if (visiblePosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: EmptyState(
                      text: section == 0
                          ? '还没有动态'
                          : section == 1
                          ? '还没有收藏'
                          : '还没有点赞',
                    ),
                  ),
                ...visiblePosts.asMap().entries.expand(
                  (entry) => <Widget>[
                    PostCard(
                      post: entry.value,
                      onActionChanged: refreshFromServer,
                      canDelete: section == 0,
                      hideAuthor: true,
                      onDeleted: () => _confirmDelete(entry.value),
                    ),
                    if (entry.key < visiblePosts.length - 1)
                      const Divider(height: 1),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileMenuSection(BuildContext context, List<Widget> children) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _profileMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 23, color: c.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: c.onSurface),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showSection(int nextSection) {
    HapticFeedback.selectionClick();
    setState(() => section = nextSection);
  }

  void _showNotReady(String name) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name功能尚未接入')));
  }
}
