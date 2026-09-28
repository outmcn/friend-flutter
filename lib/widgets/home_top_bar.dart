import 'package:flutter/material.dart';

class HomeTopBar extends StatelessWidget {
  final bool showTitle;
  const HomeTopBar({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 48,
      title: showTitle ? const Text('主页') : null,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('二维码'),
              content: const SizedBox(
                width: 220,
                height: 220,
                child: Center(child: Icon(Icons.qr_code_2, size: 190)),
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
    );
  }
}
