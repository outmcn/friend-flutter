part of 'main.dart';

class GameClubBackendClient {
  GameClubBackendClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ??
            Uri.parse(const String.fromEnvironment('FRIEND_API_BASE_URL',
                defaultValue: 'https://friend.outmcn.com'));
  final http.Client _client;
  final Uri _baseUri;
  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body);
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);
  Future<Map<String, dynamic>> _request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final request = http.Request(method, _baseUri.resolve(path))
      ..headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final response = await _client.send(request);
    final text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          data = decoded.cast<String, dynamic>();
        }
      } catch (_) {
        // A proxy or stale deployment may return an HTML error page.
      }
      throw Exception(data?['error']?.toString() ??
          'Game 俱乐部服务暂不可用（HTTP ${response.statusCode}）');
    }
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('后端返回格式错误');
    return decoded.cast<String, dynamic>();
  }

  void dispose() => _client.close();
}

class GameClubAdminPage extends StatefulWidget {
  const GameClubAdminPage({super.key});
  @override
  State<GameClubAdminPage> createState() => _GameClubAdminPageState();
}

class _GameClubAdminPageState extends State<GameClubAdminPage> {
  final api = GameClubBackendClient();
  int tab = 0;
  bool loading = true;
  String? error;
  List<dynamic> companions = [];
  List<dynamic> categories = [];
  List<dynamic> projects = [];
  List<dynamic> orders = [];
  List<dynamic> myOrders = [];
  List<dynamic> myCompanions = [];
  List<dynamic> banners = [];
  List<dynamic> applications = [];
  List<dynamic> games = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        api.get('/api/game-club/companions'),
        api.get('/api/game-club/categories'),
        api.get('/api/game-club/projects'),
        api.get('/api/game-club/orders'),
        api.get('/api/game-club/banners'),
        api.get('/api/game-club/applications'),
        api.get('/api/game-club/manage/games')
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        companions = values[0]['companions'] as List? ?? [];
        categories = values[1]['categories'] as List? ?? [];
        projects = values[2]['projects'] as List? ?? [];
        myOrders = values[3]['orders'] as List? ?? [];
        banners = values[4]['banners'] as List? ?? [];
        applications = values[5]['applications'] as List? ?? [];
        games = values[6]['games'] as List? ?? [];
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Game 俱乐部后台'), actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : Column(children: [
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: [
                          '陪玩管理',
                          '申请列表',
                          '订单管理',
                          '玩法管理',
                          '推广管理',
                          '游戏管理'
                        ]
                                .asMap()
                                .entries
                                .map((e) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: ChoiceChip(
                                        label: Text(e.value),
                                        selected: tab == e.key,
                                        showCheckmark: false,
                                        onSelected: (_) =>
                                            setState(() => tab = e.key))))
                                .toList())),
                    Expanded(
                        child: [
                      _companions(),
                      _applications(),
                      _orders(),
                      _playbook(),
                      _promotion(),
                      _games()
                    ][tab])
                  ]),
      );
  Widget _companions() => ListView(
        children: [
          ...companions.map((c) => ListTile(
                title: Text('${c['nickname'] ?? '用户'}  #${c['user_id']}'),
                subtitle: Text(
                    '价格：${c['price']}  标签：${(c['tags'] as List? ?? []).join('、')}'),
                trailing: Wrap(
                  children: [
                    if (c['is_star'] == true) const Chip(label: Text('明星陪玩')),
                    if (c['is_king'] == true) const Chip(label: Text('魔王技术')),
                    IconButton(
                        onPressed: () => _editCompanion(c),
                        icon: const Icon(Icons.edit)),
                    IconButton(
                        onPressed: () => _delete(
                            '/api/game-club/companions/${c['user_id']}'),
                        icon: const Icon(Icons.delete_outline)),
                  ],
                ),
              )),
        ],
      );
  Widget _applications() => ListView(
        padding: const EdgeInsets.all(16),
        children: applications.isEmpty
            ? const [
                ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('暂无申请'),
                ),
              ]
            : applications
                .map((a) => ListTile(
                      title: Text(
                          '${a['nickname'] ?? a['username'] ?? '用户'} · ${a['status']}'),
                      subtitle:
                          Text('联系方式：${a['contact']}\n${a['description']}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) => _patch(
                            '/api/game-club/applications/${a['id']}',
                            {'status': status}),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'approved', child: Text('通过')),
                          PopupMenuItem(value: 'rejected', child: Text('拒绝')),
                        ],
                      ),
                    ))
                .toList(),
      );

  Widget _promotion() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
              leading: Icon(Icons.campaign_outlined), title: Text('推广管理')),
          ListTile(
              title: const Text('明星陪玩推广'),
              subtitle: Text(
                  '当前 ${companions.where((c) => c['is_star'] == true).length} 人')),
          ListTile(
              title: const Text('魔王技术推广'),
              subtitle: Text(
                  '当前 ${companions.where((c) => c['is_king'] == true).length} 人')),
          const Divider(),
          const Text('主页横幅'),
          ...banners.map((b) => ListTile(
              title: Text('${b['title']}'),
              subtitle: Text('${b['subtitle']}'))),
        ],
      );

  Widget _games() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
              onPressed: _addGame,
              icon: const Icon(Icons.add),
              label: const Text('增加游戏')),
          ...games.map((g) => Card(
                  child: ExpansionTile(
                title: Text('${g['title']}'),
                trailing: IconButton(
                    onPressed: () =>
                        _delete('/api/game-club/manage/games/${g['id']}'),
                    icon: const Icon(Icons.delete_outline)),
                children: [
                  ListTile(
                      title: const Text('俱乐部管理员'),
                      trailing: IconButton(
                          onPressed: () => _addGameManager(g),
                          icon: const Icon(Icons.person_add_outlined))),
                ],
              )))
        ],
      );

  Widget _playbook() => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add),
                label: const Text('增加一级分类')),
          ),
          ...categories.map((c) {
            final categoryProjects = projects
                .where((p) => '${p['category_id']}' == '${c['id']}')
                .toList();
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ExpansionTile(
                title: Text('${c['title']}'),
                subtitle: Text('${c['description'] ?? ''}'),
                trailing: Wrap(
                  children: [
                    IconButton(
                        tooltip: '增加二级玩法',
                        onPressed: () => _addProject(c),
                        icon: const Icon(Icons.add_circle_outline)),
                    IconButton(
                        tooltip: '删除一级分类',
                        onPressed: () =>
                            _delete('/api/game-club/categories/${c['id']}'),
                        icon: const Icon(Icons.delete_outline)),
                  ],
                ),
                children: [
                  if (categoryProjects.isEmpty)
                    const ListTile(title: Text('暂无二级玩法')),
                  ...categoryProjects.map((p) => ListTile(
                        title: Text('${p['title']}'),
                        subtitle: Text(
                            '${p['description'] ?? ''}\n价格：${p['price'] ?? ''}${p['unit'] ?? ''}  标签：${(p['tags'] as List? ?? []).join('、')}'),
                        isThreeLine: true,
                        trailing: Wrap(children: [
                          IconButton(
                              tooltip: '修改玩法',
                              onPressed: () => _editProject(p),
                              icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                              tooltip: '删除玩法',
                              onPressed: () =>
                                  _delete('/api/game-club/projects/${p['id']}'),
                              icon: const Icon(Icons.delete_outline)),
                        ]),
                      )),
                ],
              ),
            );
          }),
        ],
      );
  Widget _orders() => ListView(
      children: myOrders
          .map((o) => ListTile(
              title: Text('订单 #${o['id']} · ${o['status']}'),
              subtitle: Text(
                  '${o['buyer_nickname']} → ${o['companion_nickname']} · ${o['project_title'] ?? ''}'),
              trailing: PopupMenuButton<String>(
                  onSelected: (s) =>
                      _patch('/api/game-club/orders/${o['id']}', {'status': s}),
                  itemBuilder: (_) => const [
                        PopupMenuItem(value: 'accepted', child: Text('接受')),
                        PopupMenuItem(value: 'completed', child: Text('完成')),
                        PopupMenuItem(value: 'cancelled', child: Text('取消')),
                        PopupMenuItem(value: 'refunded', child: Text('退款'))
                      ])))
          .toList());
  Future<void> _delete(String path) async {
    await api.delete(path);
    await load();
  }

  Future<void> _patch(String path, Map<String, dynamic> body) async {
    await api.patch(path, body);
    await load();
  }

  Future<void> _addProject(dynamic category) async {
    final title = await _input('二级玩法名称');
    if (title == null || title.trim().isEmpty) return;
    final description = await _input('玩法简介');
    final price = await _input('价格');
    final unit = await _input('单位', initial: '/局');
    final tagsText = await _input('标签（用逗号分隔）');
    await api.post('/api/game-club/projects', {
      'categoryId': category['id'],
      'title': title,
      'description': description ?? '',
      'price': price ?? '',
      'unit': unit ?? '',
      'tags': (tagsText ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    });
    await load();
  }

  Future<void> _editProject(dynamic project) async {
    final title = await _input('玩法名称', initial: '${project['title']}');
    if (title == null || title.trim().isEmpty) return;
    final description =
        await _input('玩法简介', initial: '${project['description'] ?? ''}');
    final price = await _input('价格', initial: '${project['price'] ?? ''}');
    final unit = await _input('单位', initial: '${project['unit'] ?? ''}');
    final oldTags = (project['tags'] as List? ?? const []).join(',');
    final tagsText = await _input('标签（用逗号分隔）', initial: oldTags);
    await _patch('/api/game-club/projects/${project['id']}', {
      'title': title,
      'description': description ?? '',
      'price': price ?? '',
      'unit': unit ?? '',
      'tags': (tagsText ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    });
  }

  Future<void> _addGame() async {
    final title = await _input('游戏名称');
    if (title != null && title.trim().isNotEmpty) {
      await api.post('/api/game-club/manage/games', {'title': title});
      await load();
    }
  }

  Future<void> _addGameManager(dynamic game) async {
    final phone = await _input('管理员手机号');
    if (phone != null && phone.trim().isNotEmpty) {
      await api.post('/api/game-club/manage/games/${game['id']}/managers',
          {'phone': phone});
      await load();
    }
  }

  Future<void> _addCategory() async {
    final title = await _input('分类名称');
    if (title != null && title.trim().isNotEmpty) {
      await api.post('/api/game-club/categories', {'title': title});
      await load();
    }
  }

  Future<void> _editCompanion(dynamic c) async {
    final price = await _input('价格', initial: '${c['price']}');
    if (price != null) {
      await _patch(
          '/api/game-club/companions/${c['user_id']}', {'price': price});
    }
  }

  Future<String?> _input(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(title),
                content: TextField(controller: controller, autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('确定'))
                ]));
  }
}

class GameClubOrdersPage extends StatefulWidget {
  const GameClubOrdersPage({super.key});
  @override
  State<GameClubOrdersPage> createState() => _GameClubOrdersPageState();
}

class _GameClubOrdersPageState extends State<GameClubOrdersPage> {
  List<dynamic> orders = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final a = GameClubBackendClient();
      final d = await a.get('/api/game-club/my-orders');
      a.dispose();
      if (mounted) setState(() => orders = d['orders'] as List? ?? []);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('我的订单')),
      body: ListView(
          children: orders
              .map((o) => ListTile(
                  title: Text('订单 #${o['id']} · ${o['status']}'),
                  subtitle: Text(
                      '${o['companion_nickname'] ?? ''} · ${o['project_title'] ?? ''}')))
              .toList()));
}

class GameClubFavoritesPage extends StatefulWidget {
  const GameClubFavoritesPage({super.key});
  @override
  State<GameClubFavoritesPage> createState() => _GameClubFavoritesPageState();
}

class _GameClubFavoritesPageState extends State<GameClubFavoritesPage> {
  List<dynamic> people = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final a = GameClubBackendClient();
      final d = await a.get('/api/game-club/my-companions');
      a.dispose();
      if (mounted) setState(() => people = d['companions'] as List? ?? []);
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('收藏的陪玩')),
      body: ListView(
          children: people
              .map((p) => ListTile(
                  title: Text('${p['nickname'] ?? '用户'}'),
                  subtitle: Text('价格：${p['price']}')))
              .toList()));
}
