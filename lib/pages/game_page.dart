import 'package:flutter/material.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('游戏')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GameEntryCard(
            title: '五子棋',
            subtitle: '和朋友一起下五子棋',
            icon: Icons.grid_4x4,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GomokuPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _GameEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primaryContainer,
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class GomokuPage extends StatefulWidget {
  const GomokuPage({super.key});

  @override
  State<GomokuPage> createState() => _GomokuPageState();
}

class _GomokuPageState extends State<GomokuPage> {
  static const boardSize = 15;
  final board = List<int>.filled(boardSize * boardSize, 0);
  int currentPlayer = 1;
  int? winner;

  void _play(int index) {
    if (board[index] != 0 || winner != null) return;
    setState(() {
      board[index] = currentPlayer;
      if (_hasFive(index)) {
        winner = currentPlayer;
      } else if (!board.contains(0)) {
        winner = 3;
      } else {
        currentPlayer = currentPlayer == 1 ? 2 : 1;
      }
    });
  }

  bool _hasFive(int index) {
    final row = index ~/ boardSize;
    final column = index % boardSize;
    for (final direction in const [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ]) {
      final count =
          1 +
          _count(row, column, direction[0], direction[1]) +
          _count(row, column, -direction[0], -direction[1]);
      if (count >= 5) return true;
    }
    return false;
  }

  int _count(int row, int column, int rowStep, int columnStep) {
    var count = 0;
    var nextRow = row + rowStep;
    var nextColumn = column + columnStep;
    while (nextRow >= 0 &&
        nextRow < boardSize &&
        nextColumn >= 0 &&
        nextColumn < boardSize &&
        board[nextRow * boardSize + nextColumn] == currentPlayer) {
      count++;
      nextRow += rowStep;
      nextColumn += columnStep;
    }
    return count;
  }

  void _reset() {
    setState(() {
      board.fillRange(0, board.length, 0);
      currentPlayer = 1;
      winner = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = winner == 1
        ? '黑棋胜利'
        : winner == 2
        ? '白棋胜利'
        : winner == 3
        ? '和棋'
        : currentPlayer == 1
        ? '黑棋回合'
        : '白棋回合';
    return Scaffold(
      appBar: AppBar(title: const Text('五子棋')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text(
              status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1,
            child: Card(
              color: colors.tertiaryContainer,
              clipBehavior: Clip.antiAlias,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(6),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: boardSize,
                ),
                itemCount: board.length,
                itemBuilder: (_, index) => InkWell(
                  onTap: () => _play(index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.onTertiaryContainer.withValues(
                          alpha: .35,
                        ),
                        width: .5,
                      ),
                    ),
                    child: board[index] == 0
                        ? null
                        : Padding(
                            padding: const EdgeInsets.all(2),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: board[index] == 1
                                    ? Colors.black87
                                    : Colors.white,
                                border: board[index] == 2
                                    ? Border.all(color: Colors.black38)
                                    : null,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('重新开始'),
          ),
        ],
      ),
    );
  }
}
