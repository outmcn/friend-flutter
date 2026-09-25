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
      title: SegmentedButton<String>(
        segments: [
          for (final option in options)
            ButtonSegment<String>(value: option, label: Text(option)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (values) {
          if (values.isNotEmpty) {
            HapticFeedback.selectionClick();
            onSelected(values.first);
          }
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant;
          }),
        ),
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
