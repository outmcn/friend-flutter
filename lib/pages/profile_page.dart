import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ui_post.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../widgets/post_card.dart';
import '../widgets/profile_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/home_top_bar.dart';

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
  static const avatarIcons = [
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
  bool loading = true;
  int section = 0;
  List<UiPost> ownPosts = [];
  List<UiPost> favoritePosts = [];
  List<UiPost> likedPosts = [];
  late final ApiClient _api;
  final _location = LocationService();

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
      if (value == null || value.isEmpty) {
        return;
      }
      await _api.put('/api/me', body: {'city': value});
      if (mounted) setState(() => city = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('城市更新失败')));
      }
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

          ownPosts = _posts(data['posts']);
          favoritePosts = _posts(data['favorited']);
          likedPosts = _posts(data['liked']);
          loading = false;
        });
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
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
            itemCount: 10,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) => GestureDetector(
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
    if (chosen == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('friend.selected.avatar', chosen);
    try {
      await _api.put('/api/me', body: {'avatarId': chosen});
      if (mounted) setState(() => selectedAvatar = chosen);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像更新失败')));
      }
    }
  }

  Color _avatarColor(int index) => [
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
    if (value == null || value.isEmpty) {
      return;
    }
    try {
      await _api.put('/api/me', body: {'nickname': value});
      if (mounted) setState(() => nickname = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('昵称更新失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = section == 0
        ? ownPosts
        : (section == 1 ? favoritePosts : likedPosts);
    return Column(
      children: [
        const HomeTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              ProfileCard(
                nickname: loading ? '加载中…' : nickname,
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
                actions: null,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ProfileTab(
                      text: '动态',
                      selected: section == 0,
                      onTap: () => setState(() => section = 0),
                    ),
                  ),
                  Expanded(
                    child: _ProfileTab(
                      text: '收藏',
                      selected: section == 1,
                      onTap: () => setState(() => section = 1),
                    ),
                  ),
                  Expanded(
                    child: _ProfileTab(
                      text: '点赞',
                      selected: section == 2,
                      onTap: () => setState(() => section = 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (visiblePosts.isEmpty)
                EmptyState(
                  text: section == 0
                      ? '还没有动态'
                      : (section == 1 ? '还没有收藏' : '还没有点赞'),
                ),
              ...visiblePosts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PostCard(
                    post: post,
                    onActionChanged: refreshFromServer,
                    canDelete: section == 0,
                    hideAuthor: true,
                    onDeleted: () => _confirmDelete(post),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const _ProfileTab({required this.text, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? c.onPrimary : c.onSurface,
          ),
        ),
      ),
    );
  }
}
