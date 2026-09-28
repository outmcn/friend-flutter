import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Row(
            children: [
              for (final option in options) ...[
                _FilterPill(
                  label: option,
                  selected: option == selected,
                  onTap: () {
                    if (option != selected) {
                      HapticFeedback.selectionClick();
                      onSelected(option);
                    }
                  },
                ),
                if (option != options.last) const SizedBox(width: 8),
              ],
              const Spacer(),
              IconButton(
                onPressed: onCompose,
                tooltip: '发布动态',
                icon: const Icon(Icons.loupe_outlined, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(76, 36),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        backgroundColor: selected ? colors.primary : colors.surface,
        foregroundColor: selected ? colors.onPrimary : colors.onSurface,
        side: BorderSide(color: selected ? colors.primary : colors.outline),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
