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
    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const SizedBox(width: 20),
                  _DiscoveryFilter(
                    label: options[index],
                    selected: selected == options[index],
                    onTap: () {
                      if (selected != options[index]) {
                        HapticFeedback.selectionClick();
                        onSelected(options[index]);
                      }
                    },
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: onCompose,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '发布动态',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiscoveryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: selected ? 18 : 15,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
