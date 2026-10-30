part of 'main.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback? onPresenceTap;
  final VoidCallback? onCheckinTap;

  const SettingsPage({
    super.key,
    this.onPresenceTap,
    this.onCheckinTap,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('账户设置'),
          actions: [
            IconButton(
              tooltip: '签到',
              onPressed: onCheckinTap ??
                  () => _showTopNotice(context, const Text('普通签到功能暂未接入')),
              icon: const Icon(TIcons.calendar_1),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _SettingsGroup(
              title: '账号与安全',
              showTitle: false,
              items: const ['手机号', '手势安全', '注销账号'],
              onItemTap: (item) {
                if (item == '手机号' || item == '手势安全' || item == '注销账号') {
                  _showTopNotice(context, Text('$item功能暂未接入'));
                } else if (item == '修改密码') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PasswordSetupPage(),
                    ),
                  );
                }
              },
            ),
            _SettingsGroup(
              title: '隐私与通知',
              items: const ['隐私设置', '通知设置'],
              onItemTap: (item) {
                if (item == '通知设置') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  );
                }
              },
            ),
            _SettingsGroup(
              title: '其他',
              items: const ['清理缓存', '关于软件', '退出登录'],
              onItemTap: (item) async {
                if (item == '清理缓存') {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    _showTopNotice(context, const Text('缓存已清理'));
                  }
                } else if (item == '关于软件') {
                  showAboutDialog(
                    context: context,
                    applicationName: 'DD',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Friend',
                  );
                } else if (item == '退出登录') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出当前账号吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('退出'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    final navigator = Navigator.of(context);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('friend.auth.token');
                    await prefs.remove('friend.auth.userId');
                    if (!context.mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      );
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool likes = true;
  bool comments = true;
  bool follows = true;
  bool system = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('通知设置')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SwitchListTile(
              title: const Text('点赞通知'),
              subtitle: const Text('有人点赞你的内容时通知'),
              value: likes,
              onChanged: (v) => setState(() => likes = v),
            ),
            SwitchListTile(
              title: const Text('评论通知'),
              subtitle: const Text('有人评论你的内容时通知'),
              value: comments,
              onChanged: (v) => setState(() => comments = v),
            ),
            SwitchListTile(
              title: const Text('关注通知'),
              subtitle: const Text('有人关注你时通知'),
              value: follows,
              onChanged: (v) => setState(() => follows = v),
            ),
            SwitchListTile(
              title: const Text('系统通知'),
              subtitle: const Text('接收 DD 系统消息'),
              value: system,
              onChanged: (v) => setState(() => system = v),
            ),
          ],
        ),
      );
}

class AccountSwitchPage extends StatelessWidget {
  const AccountSwitchPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('切换账户')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('DD 用户'),
              trailing: Icon(Icons.check_circle),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add)),
              title: const Text('添加其他账户'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ],
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.items,
    this.onItemTap,
    this.showTitle = true,
  });
  final String title;
  final List<String> items;
  final ValueChanged<String>? onItemTap;
  final bool showTitle;

  IconData _iconFor(String item) {
    switch (item) {
      case '手机号':
        return Icons.phone_outlined;
      case '手势安全':
        return Icons.gesture;
      case '注销账号':
        return Icons.person_remove_outlined;
      case '修改密码':
        return Icons.lock_outline;
      case '隐私设置':
        return Icons.privacy_tip_outlined;
      case '通知设置':
        return Icons.notifications_none;
      case '清理缓存':
        return Icons.cleaning_services_outlined;
      case '关于软件':
        return Icons.info_outline;
      case '退出登录':
        return Icons.logout;
      default:
        return Icons.settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 14, bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Card(
            child: Column(
              children: items
                  .map(
                    (item) => ListTile(
                      onTap: onItemTap == null ? null : () => onItemTap!(item),
                      leading: Icon(_iconFor(item)),
                      title: Text(item),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
}

class _SimpleListPage extends StatelessWidget {
  const _SimpleListPage({required this.title, required this.items});
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(items[index]),
              subtitle: const Text('内容'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
}
