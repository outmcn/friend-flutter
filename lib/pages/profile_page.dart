import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/ui_post.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_state.dart';
import 'user_list_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    refreshFromServer();
    _updateCity();
  }

  Future<void> _updateCity() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('friend.location.cachedAt') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedLat = prefs.getDouble('friend.location.latitude');
    final cachedLon = prefs.getDouble('friend.location.longitude');
    Position? position;
    if (cachedLat != null &&
        cachedLon != null &&
        now - cachedAt < 6 * 60 * 60 * 1000) {
      position = Position(
        latitude: cachedLat,
        longitude: cachedLon,
        timestamp: DateTime.fromMillisecondsSinceEpoch(cachedAt),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    if (position == null) {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      position = await Geolocator.getCurrentPosition();
      await prefs.setDouble('friend.location.latitude', position.latitude);
      await prefs.setDouble('friend.location.longitude', position.longitude);
      await prefs.setInt('friend.location.cachedAt', now);
    }
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places.isEmpty) return;
    final value =
        (places.first.locality ?? places.first.administrativeArea ?? '')
            .replaceAll('市', '');
    if (value.isEmpty || !mounted) return;
    setState(() => city = value);
    await http.put(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'city': value}),
    );
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
      final response = await http.get(
        Uri.parse('https://friend.outmcn.net/api/me/summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
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
    final response = await http.delete(
      Uri.parse('https://friend.outmcn.net/api/posts/${post.id}'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true) await refreshFromServer();
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
    if (chosen == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('friend.selected.avatar', chosen);
    final response = await http.put(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'avatarId': chosen}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true && mounted) setState(() => selectedAvatar = chosen);
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
    if (value == null || value.isEmpty) return;
    final response = await http.put(
      Uri.parse('https://friend.outmcn.net/api/me'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nickname': value}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] == true && mounted) setState(() => nickname = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [colors.surfaceContainer, colors.primaryContainer],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  loading ? '加载中…' : nickname,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _editNickname,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                                tooltip: '修改名字',
                                visualDensity: VisualDensity.compact,
                              ),
                              if (city.isNotEmpty)
                                Flexible(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'IP：$city',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onPrimaryContainer,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserListPage(
                                      token: widget.token,
                                      title: '关注',
                                      relation: 'following',
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '关注 $following',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserListPage(
                                      token: widget.token,
                                      title: '粉丝',
                                      relation: 'followers',
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '粉丝 $followers',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '获赞 $likes     动态 $postCount',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: _avatarColor(selectedAvatar),
                        child: Icon(
                          avatarIcons[selectedAvatar],
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
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
