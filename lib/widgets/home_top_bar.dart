import 'package:flutter/material.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 12, 5),
          child: Row(
            children: [
              Text(
                '主页',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('二维码'),
                    content: SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Icon(
                          Icons.qr_code_2,
                          size: 190,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                tooltip: '二维码',
                icon: const Icon(Icons.qr_code_2_outlined),
              ),
              IconButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const SafeArea(
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('设置'),
                      subtitle: Text('设置功能正在完善'),
                    ),
                  ),
                ),
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
