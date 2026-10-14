part of 'main.dart';

class WerewolfGamePage extends StatefulWidget {
  const WerewolfGamePage({super.key});
  @override
  State<WerewolfGamePage> createState() => _WerewolfGamePageState();
}

class _WerewolfGamePageState extends State<WerewolfGamePage> {
  final roomController = TextEditingController();
  final service = DDPostService();
  String? roomId;
  String? roomCode;
  bool matching = false, ready = false, loading = false;
  String? error;
  List<Map<String, dynamic>> seats = [];

  @override
  void dispose() {
    roomController.dispose();
    service.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('friend.auth.token') ?? '';
    if (t.isEmpty) throw Exception('请先登录');
    return t;
  }

  Future<void> _enterRoom(Map<String, dynamic> d) async {
    if (!mounted) return;
    setState(() {
      roomId = '${d['roomId'] ?? ''}';
      roomCode = '${d['roomCode'] ?? ''}';
      seats = (d['seats'] as List? ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    });
  }

  Future<void> _createRoom() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      await _enterRoom(await service.createWerewolfRoom(await _token()));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = roomController.text.trim();
    if (code.isEmpty) {
      setState(() => error = '请输入房间号');
      return;
    }
    try {
      setState(() {
        loading = true;
        error = null;
      });
      await _enterRoom(await service.joinWerewolfRoom(await _token(), code));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleSeat(int seat) async {
    if (roomId == null) return;
    try {
      await _enterRoom(
          await service.takeWerewolfSeat(await _token(), roomId!, seat));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggleReady() async {
    if (roomId == null) return;
    try {
      await _enterRoom(
          await service.readyWerewolfRoom(await _token(), roomId!, !ready));
      if (mounted) setState(() => ready = !ready);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _toggleMatching() async {
    try {
      if (matching) {
        await service.stopWerewolfMatch(await _token());
      } else {
        final d = await service.startWerewolfMatch(await _token());
        if ('${d['roomId'] ?? ''}'.isNotEmpty) await _enterRoom(d);
      }
      if (mounted) setState(() => matching = !matching);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Widget _seat(int index) {
    final item = seats
        .cast<Map<String, dynamic>?>()
        .firstWhere((e) => e?['seat'] == index, orElse: () => null);
    final name = item?['nickname']?.toString();
    return Card(
        child: InkWell(
            onTap: name == null ? () => _toggleSeat(index) : null,
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  CircleAvatar(child: _tdIcon('user')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(name ?? '点击入座',
                          overflow: TextOverflow.ellipsis)),
                  if (item?['ready'] == true)
                    const Icon(Icons.check_circle, color: Colors.green)
                ]))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('狼人杀')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('狼人杀游戏',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: loading ? null : _toggleMatching,
              child: Text(matching ? '停止匹配' : '在线匹配')),
          OutlinedButton(
              onPressed: loading ? null : _createRoom,
              child: const Text('创建房间')),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: '房间号'))),
            const SizedBox(width: 8),
            FilledButton(onPressed: _joinRoom, child: const Text('进入房间'))
          ]),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (roomCode != null) ...[
            const SizedBox(height: 18),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('房间号：$roomCode',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(
                                        children:
                                            List.generate(6, (i) => _seat(i)))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        children: List.generate(
                                            6, (i) => _seat(i + 6))))
                              ]),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _toggleReady,
                              child: Text(ready ? '取消准备' : '准备')),
                        ])))
          ],
        ]),
      );
}
