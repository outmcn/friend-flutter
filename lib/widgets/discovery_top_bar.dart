import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tdesign_flutter_icons/tdesign_flutter_icons.dart' show TIcons;

class DiscoveryTopBar extends StatelessWidget {
  const DiscoveryTopBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCompose,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCompose;

  static const options = ['推荐', '附近', '关注'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '发现',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCompose,
                    icon: const Icon(TIcons.edit, size: 18),
                    label: const Text('发布'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(92, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colors.outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  for (final option in options)
                    ButtonSegment<String>(value: option, label: Text(option)),
                ],
                selected: {selected},
                onSelectionChanged: (value) {
                  final next = value.first;
                  if (next != selected) {
                    HapticFeedback.selectionClick();
                    onSelected(next);
                  }
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
