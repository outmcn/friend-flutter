part of 'main.dart';

class GameClubApplyPage extends StatefulWidget {
  const GameClubApplyPage({super.key});
  @override
  State<GameClubApplyPage> createState() => _GameClubApplyPageState();
}

class _GameClubApplyPageState extends State<GameClubApplyPage> {
  final description = TextEditingController();
  bool submitting = false;
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (description.text.trim().isEmpty) {
      _showTopNotice(context, const Text('请填写申请说明'));
      return;
    }
    setState(() => submitting = true);
    try {
      final api = GameClubBackendClient();
      await api.post('/api/game-club/applications',
          {'description': description.text.trim()});
      api.dispose();
      if (mounted) _showTopNotice(context, const Text('申请已提交，请等待俱乐部审核'));
    } catch (e) {
      if (mounted) _showTopNotice(context, Text('$e'));
    }
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('申请陪玩')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('申请成为陪玩',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const Text('提交申请后，俱乐部管理员会审核你的陪玩资料。'),
          const SizedBox(height: 24),
          TextField(
              controller: description,
              decoration: const InputDecoration(
                  labelText: '申请说明',
                  hintText: '介绍你的游戏经验、擅长地图和陪玩风格',
                  border: OutlineInputBorder()),
              maxLines: 5),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: submitting ? null : submit,
              child: Text(submitting ? '提交中…' : '提交申请')),
        ]),
      );
}
