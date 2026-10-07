part of 'main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _unavailable(BuildContext context, String feature) {}

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _HomeFolderCard(
                        icon: Icons.auto_awesome,
                        title: '缘分匹配',
                        subtitle: '遇见聊得来的人',
                        meta: 'FATE',
                        tabLabel: 'FATE',
                        colors: const [Color(0xffff6b9d), Color(0xffa855f7)],
                        tabAlignment: Alignment.topRight,
                        borderRadius: BorderRadius.circular(28),
                        height: 140,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FateMatchPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 9,
                      child: Column(
                        children: [
                          Expanded(
                            child: _HomeFolderCard(
                              icon: Icons.mic_none,
                              title: '语音匹配',
                              subtitle: '遇见懂你的人',
                              meta: '',
                              tabLabel: 'VOICE',
                              colors: const [
                                Color(0xff6e4fe0),
                                Color(0xffd46bc8)
                              ],
                              tabAlignment: Alignment.topLeft,
                              borderRadius: BorderRadius.circular(24),
                              height: 63,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VoiceMatchPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _HomeNormalCard(
                              icon: Icons.sports_esports_outlined,
                              title: 'Game 俱乐部',
                              colors: const [
                                Color(0xffff9a5a),
                                Color(0xffff5f8f),
                              ],
                              height: 63,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const GameCompanionPlazaPage(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _HomeCartoonCard(
                icon: Icons.menu_book_outlined,
                title: '玩剧本',
                subtitle: '拨开迷雾，寻找真相',
                badge: 'GO',
                colors: const [Color(0xff352b62), Color(0xff8b4e9f)],
                onTap: () => _unavailable(context, '玩剧本'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.groups_2_outlined,
                      title: '真人带本',
                      subtitle: '52局等待中',
                      badge: 'LIVE',
                      colors: const [Color(0xff5a315b), Color(0xffd46b82)],
                      onTap: () => _unavailable(context, '真人带本'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.smart_toy_outlined,
                      title: 'AI剧本杀',
                      subtitle: '随时开局',
                      badge: 'AI',
                      colors: const [Color(0xff164b68), Color(0xff3c9fa9)],
                      onTap: () => _unavailable(context, 'AI剧本杀'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.mic_external_on_outlined,
                      title: '嗨歌抢唱',
                      subtitle: '轮到你开唱',
                      badge: 'NEW',
                      colors: const [Color(0xff713b42), Color(0xffe38d57)],
                      onTap: () => _unavailable(context, '嗨歌抢唱'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeCartoonCard(
                      icon: Icons.casino_outlined,
                      title: '骗子酒馆',
                      subtitle: '猜猜谁在说谎',
                      badge: 'NEW',
                      colors: const [Color(0xff254d72), Color(0xff63a5c5)],
                      onTap: () => _unavailable(context, '骗子酒馆'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _HomeCartoonCard(
                icon: Icons.flight_takeoff_outlined,
                title: '飞行棋',
                subtitle: '轻松玩一局',
                badge: 'PLAY',
                colors: const [Color(0xff2c5d3a), Color(0xff83bc67)],
                onTap: () => _unavailable(context, '飞行棋'),
              ),
            ],
          ),
        ),
      );
}
