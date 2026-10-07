part of 'main.dart';

class FateMatchPage extends StatefulWidget {
  const FateMatchPage({super.key});
  @override
  State<FateMatchPage> createState() => _FateMatchPageState();
}

class _FateMatchPageState extends State<FateMatchPage> {
  bool matching = false;
  bool matched = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff191019),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('缘分匹配'),
          actions: [
            IconButton(
              tooltip: '分享',
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能暂未接入')),
                );
              },
            ),
          ],
        ),
        body: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.4,
                  colors: [Color(0xffff6f9a), Color(0xff191019)],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('缘分匹配',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 36),
                    Stack(alignment: Alignment.center, children: [
                      for (final size in [250.0, 190.0, 132.0])
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    Colors.pinkAccent.withValues(alpha: .36)),
                          ),
                        ),
                      CircleAvatar(
                        radius: 53,
                        backgroundColor: const Color(0xffff5f8f),
                        child: Icon(
                          matched ? Icons.favorite : Icons.auto_awesome,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 36),
                    Text(
                      matched
                          ? '遇见了 林小满'
                          : (matching ? '正在寻找有缘人…' : '开启一段新的缘分'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      matched ? '音乐 · 旅行 · 聊得来' : '填写兴趣后，寻找默契的聊天伙伴',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
                    if (matched)
                      Wrap(spacing: 10, children: [
                        FilledButton(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text(''))),
                          child: const Text('开始聊天'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            matched = false;
                            matching = false;
                          }),
                          child: const Text('重新匹配'),
                        ),
                      ])
                    else
                      FilledButton.icon(
                        onPressed: matching
                            ? null
                            : () => setState(() {
                                  matching = true;
                                  matched = true;
                                }),
                        icon: const Icon(Icons.favorite_outline),
                        label: Text(matching ? '匹配中…' : '开始匹配'),
                      ),
                  ]),
            ),
          ),
        ]),
      );
}

class _GameFilterRow extends StatelessWidget {
  const _GameFilterRow(
      {required this.labels,
      required this.selected,
      required this.onSelected,
      this.icon});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(
            scrollDirection: Axis.horizontal,
            children: labels
                .asMap()
                .entries
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: icon != null && entry.key == selected
                            ? Icon(icon, size: 15)
                            : null,
                        label: Text(entry.value),
                        selected: selected == entry.key,
                        onSelected: (_) => onSelected(entry.key),
                      ),
                    ))
                .toList()),
      );
}

class _GameProfileStat extends StatelessWidget {
  const _GameProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _GameProfileServiceRow extends StatelessWidget {
  const _GameProfileServiceRow(
      {required this.game, required this.title, required this.price});
  final String game;
  final String title;
  final String price;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: const Icon(Icons.sports_esports_outlined),
        title: Text(title),
        subtitle: Text(game),
        trailing: Text('¥$price 起',
            style: const TextStyle(
                color: Color(0xffff4d6a), fontWeight: FontWeight.w800)),
      ));
}

class _GameReview extends StatelessWidget {
  const _GameReview({required this.name, required this.text});
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: Text(text),
        trailing: const Text('★ 5.0'),
      );
}
