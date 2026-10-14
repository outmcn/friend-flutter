part of 'main.dart';

class GameClubApplyPage extends StatelessWidget {
  const GameClubApplyPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('申请陪玩')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('申请成为陪玩',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('提交申请后，俱乐部管理员会审核你的陪玩资料。'),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: '申请说明',
                hintText: '介绍你的游戏经验、擅长地图和陪玩风格',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {},
              child: const Text('提交申请'),
            ),
          ],
        ),
      );
}
