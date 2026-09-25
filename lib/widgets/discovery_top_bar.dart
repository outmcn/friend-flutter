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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      title: ChoiceChips(selected: selected, onSelected: onSelected),
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

class ChoiceChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const ChoiceChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const options = ['推荐', '附近', '关注'];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final text in options)
          ButtonSegment<String>(value: text, label: Text(text)),
      ],
      selected: {selected},
      onSelectionChanged: (values) {
        if (values.isNotEmpty) {
          HapticFeedback.selectionClick();
          onSelected(values.first);
        }
      },
      multiSelectionEnabled: false,
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
