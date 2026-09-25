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
      title: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: colors.primary,
        indicatorWeight: 2,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: [
          for (final option in options)
            Tab(
              text: option,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(option);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(option),
                ),
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

// Kept as a compatibility wrapper for existing imports.
class ChoiceChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const ChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
