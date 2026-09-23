import 'package:flutter/material.dart';

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
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChips(selected: selected, onSelected: onSelected),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCompose,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: c.primary,
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
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: ['推荐', '附近', '关注']
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: text == selected
                        ? c.primary
                        : c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: text == selected ? c.onPrimary : c.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
