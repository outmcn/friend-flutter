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
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '发现',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: onCompose,
                    icon: const Icon(TIcons.edit, size: 17),
                    label: const Text('发布'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colors.outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
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
                ],
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
