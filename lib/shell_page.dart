part of 'main.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int? selectedChat;
  final messageController = TextEditingController();
  final conversations = const [
    _ChatPreview(
        'HermesChat', '开始一段新的聊天', 'assets/figma/profile-portrait-2.jpg', '1'),
    _ChatPreview('好友消息', '暂无新的消息', 'assets/figma/profile-portrait-3.jpg', '2'),
    _ChatPreview(
        '群组消息', '创建或加入一个群组', 'assets/figma/profile-portrait-4.jpg', '3'),
  ];

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () {},
            icon: Icon(TIcons.setting),
          ),
          IconButton(
            tooltip: '新建聊天',
            onPressed: () {},
            icon: Icon(TIcons.add_circle),
          ),
          IconButton(
            tooltip: '好友申请',
            onPressed: () {},
            icon: Icon(TIcons.user_add),
          ),
        ],
      ),
      body: _conversationList(context),
    );
  }

  /*
   * 聊天列表页统一使用 AppBar；此处只保留会话列表内容，避免自定义顶栏
   * 与其他页面的系统安全区、标题高度和操作按钮间距产生差异。
   */
  Widget _conversationList(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (_, index) {
            final chat = conversations[index];
            return _chatPreviewTile(context, chat, index);
          },
        ),
      );

  Widget _chatPreviewTile(BuildContext context, _ChatPreview chat, int index) =>
      InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _ChatDetailPage(chat: chat)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundImage: AssetImage(chat.avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(chat.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        Text('刚刚',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(chat.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ignore: unused_element
  Widget _chatDetail(BuildContext context, _ChatPreview chat) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => setState(() => selectedChat = null),
                    icon: const Icon(Icons.arrow_back)),
                CircleAvatar(
                    radius: 20, backgroundImage: AssetImage(chat.avatar)),
                const SizedBox(width: 8),
                Text(chat.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.more_horiz)),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('选择一个聊天开始交流', style: TextStyle(color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 12),
            child: Row(
              children: [
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.attach_file)),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: '输入消息',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      );
}

class _ChatPreview {
  const _ChatPreview(this.name, this.preview, this.avatar, this.conversationId);
  final String name;
  final String preview;
  final String avatar;
  final String conversationId;
}

class _ChatDetailPage extends StatefulWidget {
  const _ChatDetailPage({required this.chat});
  final _ChatPreview chat;
  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final messageController = TextEditingController();
  FriendImSocket? imSocket;
  final messages = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    unawaited(_connectIm());
  }

  @override
  void dispose() {
    messageController.dispose();
    imSocket?.dispose();
    super.dispose();
  }

  Future<void> _connectIm() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('friend.auth.token') ?? '';
    if (token.isEmpty) throw Exception('请先登录');
    final socket = FriendImSocket(token: token);
    imSocket = socket;
    await socket.connect();
    socket.events.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      if (type == 'message:new' || type == 'message:accepted') {
        final message = event['message'];
        if (message is Map) {
          setState(() => messages.add(message.cast<String, dynamic>()));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            CircleAvatar(
                radius: 20, backgroundImage: AssetImage(widget.chat.avatar)),
            const SizedBox(width: 8),
            Text(widget.chat.name),
          ]),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
          ],
        ),
        body: Column(children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('选择一个聊天开始交流',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, index) => Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${messages[index]['text'] ?? ''}'),
                      ),
                    ),
                  ),
          ),
          SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 18, 12),
                child: Row(children: [
                  IconButton(
                      onPressed: () {}, icon: const Icon(Icons.attach_file)),
                  Expanded(
                      child: TextField(
                          controller: messageController,
                          decoration: InputDecoration(
                              hintText: '输入消息',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22))))),
                  IconButton(
                    onPressed: () {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      imSocket?.sendText(
                        conversationId: widget.chat.conversationId,
                        text: text,
                        clientId:
                            DateTime.now().microsecondsSinceEpoch.toString(),
                      );
                      messageController.clear();
                    },
                    icon: const Icon(Icons.send),
                  ),
                ]),
              )),
        ]),
      );
}

class DDShell extends StatefulWidget {
  const DDShell({super.key});
  @override
  State<DDShell> createState() => _DDShellState();
}

class _DDShellState extends State<DDShell> {
  int index = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [
      HomePage(),
      DiscoverPage(),
      ChatPage(),
      DDProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            _VideoPlaybackRegistry.stopAll();
            setState(() => index = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: '娱乐',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: '聊天',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      );
}

class _PageErrorState extends StatelessWidget {
  const _PageErrorState(
      {required this.title, required this.subtitle, this.onRetry});
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
        ),
      );
}
