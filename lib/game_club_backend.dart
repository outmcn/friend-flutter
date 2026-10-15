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
  const GameClubAdminPage({super.key, required this.gameId});
  final int gameId;
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
        api.get('/api/game-club/companions?gameId=${widget.gameId}'),
        api.get('/api/game-club/page-config/${widget.gameId}'),
        api.get('/api/game-club/orders?gameId=${widget.gameId}'),
        api.get('/api/game-club/banners?gameId=${widget.gameId}'),
        api.get('/api/game-club/applications?gameId=${widget.gameId}')
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        companions = values[0]['companions'] as List? ?? [];
        categories = const [];
        projects = const [];
        myOrders = values[2]['orders'] as List? ?? [];
        banners = values[3]['banners'] as List? ?? [];
        applications = values[4]['applications'] as List? ?? [];
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
                            children: ['陪玩管理', '申请列表', '订单管理', '售后管理']
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
                      _afterSale()
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
                        onPressed: () => _editCompanionLabel(c),
                        icon: const Icon(Icons.edit_outlined)),
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
                      trailing: Wrap(spacing: 4, children: [
                        OutlinedButton(
                            onPressed: () => _patch(
                                '/api/game-club/applications/${a['id']}?gameId=${widget.gameId}',
                                {'status': 'assessed'}),
                            child: const Text('考核')),
                        OutlinedButton(
                            onPressed: () => _patch(
                                '/api/game-club/applications/${a['id']}?gameId=${widget.gameId}',
                                {'status': 'approved', 'gameId': widget.gameId}),
                            child: const Text('通过')),
                        TextButton(
                            onPressed: () => _patch(
                                '/api/game-club/applications/${a['id']}?gameId=${widget.gameId}',
                                {'status': 'rejected'}),
                            child: const Text('拒绝')),
                      ]),
                    ))
                .toList(),
      );

  Widget _afterSale() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
              leading: Icon(Icons.support_agent_outlined), title: Text('售后管理')),
          const SizedBox(height: 8),
          const Text('处理订单取消、退款和售后申请。'),
          const SizedBox(height: 16),
          ...myOrders.map((o) => Card(
                child: ListTile(
                  title: Text('订单 #${o['id']} · ${o['status']}'),
                  subtitle: Text(
                      '${o['companion_nickname'] ?? ''} · ${o['project_title'] ?? ''}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (status) => _patch(
                        '/api/game-club/orders/${o['id']}', {'status': status}),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'cancelled', child: Text('取消订单')),
                      PopupMenuItem(value: 'refunded', child: Text('退款处理')),
                    ],
                  ),
                ),
              )),
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
  Future<void> _editCompanionLabel(dynamic c) async {
    final controller = TextEditingController(text: '${c['card_label'] ?? ''}');
    final label = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('陪玩卡片标签'),
                content: TextField(
                    controller: controller,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '最多6个字')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('保存'))
                ]));
    controller.dispose();
    if (label != null) {
      await api.patch('/api/admin/game-club/companions/${c['user_id']}/label',
          {'cardLabel': label});
      await load();
    }
  }

  Future<void> _delete(String path) async {
    await api.delete(path);
    await load();
  }

  Future<void> _patch(String path, Map<String, dynamic> body) async {
    await api.patch(path, body);
    await load();
  }
}

class GameClubOrdersPage extends StatefulWidget {
  const GameClubOrdersPage({super.key});
  @override
  State<GameClubOrdersPage> createState() => _GameClubOrdersPageState();
}

class _GameClubOrdersPageState extends State<GameClubOrdersPage> {
  List<dynamic> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = GameClubBackendClient();
      final data = await api.get('/api/game-club/my-orders');
      api.dispose();
      if (mounted)
        setState(() {
          orders = data['orders'] as List? ?? [];
          loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _showTopNotice(context, Text('$e'));
      }
    }
  }

  Future<void> _openDetail(dynamic order) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GameClubOrderDetailPage(orderId: int.parse('${order['id']}')),
        ));
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的订单')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  children: orders
                      .map((o) => ListTile(
                            onTap: () => _openDetail(o),
                            title: Text('订单 #${o['id']} · ${o['status']}'),
                            subtitle: Text(
                                '${o['companion_nickname'] ?? ''} · ${o['project_title'] ?? ''}\n备注：${o['note'] ?? ''}'),
                            isThreeLine: true,
                            trailing: Text('${o['amount'] ?? '0'} 钻石'),
                          ))
                      .toList(),
                ),
              ),
      );
}

class GameClubOrderDetailPage extends StatefulWidget {
  const GameClubOrderDetailPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<GameClubOrderDetailPage> createState() =>
      _GameClubOrderDetailPageState();
}

class _GameClubOrderDetailPageState extends State<GameClubOrderDetailPage> {
  Map<String, dynamic>? order;
  List<dynamic> events = [];
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = GameClubBackendClient();
      final data = await api.get('/api/game-club/orders/${widget.orderId}');
      api.dispose();
      if (mounted)
        setState(() {
          order = data['order'] as Map<String, dynamic>?;
          events = data['events'] as List? ?? [];
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _action(String action) async {
    try {
      final api = GameClubBackendClient();
      await api.post(
          '/api/game-club/orders/${widget.orderId}/action', {'action': action});
      api.dispose();
      await load();
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      body: error != null
          ? Center(child: Text(error!))
          : o == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('订单 #${o['id']}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text('陪玩：${o['companion_nickname'] ?? ''}'),
                    Text('服务：${o['project_title'] ?? '陪玩服务'}'),
                    Text('金额：${o['amount'] ?? '0'} 钻石'),
                    Text('状态：${o['status'] ?? ''}'),
                    Text('备注：${o['note'] ?? ''}'),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (o['status'] == 'pending' ||
                            o['status'] == 'accepted')
                          OutlinedButton(
                              onPressed: () => _action('cancel'),
                              child: const Text('取消订单')),
                        if (o['status'] == 'awaiting_confirm')
                          FilledButton(
                              onPressed: () => _action('confirm'),
                              child: const Text('确认完成')),
                        if (['accepted', 'in_progress', 'awaiting_confirm']
                            .contains(o['status']))
                          OutlinedButton(
                              onPressed: () => _action('after_sale'),
                              child: const Text('申请售后')),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text('订单记录',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    ...events.map((e) => ListTile(
                          dense: true,
                          title:
                              Text('${e['from_status']} → ${e['to_status']}'),
                          subtitle: Text('${e['action']}  ${e['note'] ?? ''}'),
                        )),
                  ],
                ),
    );
  }
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
