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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 5),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChips(selected: selected, onSelected: onSelected),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCompose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                visualDensity: VisualDensity.compact,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 29,
                ),
              ),
            ],
          ),
        ),
      ),
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
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}
