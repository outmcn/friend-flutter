import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DiscoveryTopBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCompose;

  const DiscoveryTopBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCompose,
  });

  static const options = ['推荐', '附近', '关注'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _TabText(
                text: option,
                selected: option == selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(option);
                },
                color: colors,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onCompose,
          icon: const Icon(Icons.add_circle_outline),
          tooltip: '发布动态',
        ),
      ],
    );
  }
}

class _TabText extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme color;

  const _TabText({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: selected ? color.primary : color.onSurfaceVariant,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: selected ? 24 : 0,
              color: color.primary,
            ),
          ],
        ),
      ),
    );
  }
}
