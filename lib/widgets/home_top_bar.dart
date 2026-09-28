import 'package:flutter/cupertino.dart';

class HomeTopBar extends StatelessWidget {
  final VoidCallback? onQrCode;
  final VoidCallback? onSettings;
  final List<Widget> trailingActions;
  final bool showTitle;
  final bool showDefaultActions;

  const HomeTopBar({
    super.key,
    this.onQrCode,
    this.onSettings,
    this.trailingActions = const [],
    this.showTitle = true,
    this.showDefaultActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoNavigationBar(
      automaticallyImplyLeading: false,
      middle: showTitle ? const Text('主页') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDefaultActions)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed:
                  onQrCode ??
                  () => showCupertinoDialog<void>(
                    context: context,
                    builder: (_) => const CupertinoAlertDialog(
                      title: Text('二维码'),
                      content: Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Icon(CupertinoIcons.qrcode, size: 190),
                      ),
                    ),
                  ),
              child: const Icon(CupertinoIcons.qrcode, size: 22),
            ),
          if (showDefaultActions)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed:
                  onSettings ??
                  () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (_) => CupertinoActionSheet(
                      title: const Text('设置'),
                      message: const Text('设置功能正在完善'),
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  ),
              child: const Icon(CupertinoIcons.gear, size: 22),
            ),
          ...trailingActions,
        ],
      ),
    );
  }
}
