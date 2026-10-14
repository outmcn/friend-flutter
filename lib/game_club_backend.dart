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
        api.get('/api/game-club/orders')
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        companions = values[0]['companions'] as List? ?? [];
        categories = values[1]['categories'] as List? ?? [];
        projects = values[2]['projects'] as List? ?? [];
        orders = values[3]['orders'] as List? ?? [];
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
                            children: ['陪玩管理', '玩法管理', '订单管理']
                                .asMap()
                                .entries
                                .map((e) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: ChoiceChip(
                                        label: Text(e.value),
                                        selected: tab == e.key,
                                        onSelected: (_) =>
                                            setState(() => tab = e.key))))
                                .toList())),
                    Expanded(
                        child: [_companions(), _playbook(), _orders()][tab])
                  ]),
      );
  Widget _companions() => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _addCompanion,
              icon: const Icon(Icons.person_add),
              label: const Text('从 App 用户添加陪玩'),
            ),
          ),
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
  Widget _playbook() => ListView(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add),
                label: const Text('增加分类'))),
        ...categories.map((c) => ListTile(
            title: Text('${c['title']}'),
            subtitle: Text('${c['description'] ?? ''}'),
            trailing: IconButton(
                onPressed: () =>
                    _delete('/api/game-club/categories/${c['id']}'),
                icon: const Icon(Icons.delete_outline)))),
        const Divider(),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('玩法项目：${projects.length}'))
      ]);
  Widget _orders() => ListView(
      children: orders
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

  Future<void> _addCompanion() async {
    final id = await _input('App 用户 ID');
    if (id != null) {
      await api.post('/api/game-club/companions', {'userId': int.tryParse(id)});
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
