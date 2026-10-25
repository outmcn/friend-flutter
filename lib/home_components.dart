part of 'main.dart';

// ignore: unused_element
class _ScrollStateCard extends StatelessWidget {
  const _ScrollStateCard();

  @override
  Widget build(BuildContext context) => const _ContentPreviewCard(
        title: '继续浏览',
        subtitle: '向下滑动查看更多推荐内容',
        icon: Icons.keyboard_arrow_down,
      );
}

class _HomeCartoonCard extends StatelessWidget {
  const _HomeCartoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -18,
                child: Icon(icon,
                    size: 112, color: Colors.white.withValues(alpha: .16)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: colors.first,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _HomeFolderCard extends StatelessWidget {
  const _HomeFolderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.tabLabel,
    required this.colors,
    required this.tabAlignment,
    required this.borderRadius,
    this.height = 132,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final String tabLabel;
  final List<Color> colors;
  final Alignment tabAlignment;
  final BorderRadius borderRadius;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = _FolderShape(borderRadius: borderRadius);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Ink(
              height: height,
              decoration: ShapeDecoration(
                gradient: LinearGradient(colors: colors),
                shape: shape,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 24, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, color: Colors.white, size: 27),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: tabAlignment,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: colors.first.withValues(alpha: .96),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .14),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              tabLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeNormalCard extends StatelessWidget {
  const _HomeNormalCard({
    required this.icon,
    required this.title,
    // ignore: unused_element_parameter
    this.subtitle,
    required this.colors,
    required this.height,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Color> colors;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(icon, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      );
}

class _FolderShape extends ShapeBorder {
  const _FolderShape({required this.borderRadius});
  final BorderRadius borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = borderRadius.resolve(textDirection);
    final path = Path();
    path.moveTo(rect.left + 20, rect.top);
    path.lineTo(rect.left + 82, rect.top);
    path.quadraticBezierTo(
        rect.left + 92, rect.top, rect.left + 99, rect.top + 9);
    path.lineTo(rect.right - 24, rect.top + 9);
    path.quadraticBezierTo(rect.right, rect.top + 9, rect.right, rect.top + 33);
    path.lineTo(rect.right, rect.bottom - r.bottomRight.y);
    path.quadraticBezierTo(
        rect.right, rect.bottom, rect.right - r.bottomRight.x, rect.bottom);
    path.lineTo(rect.left + r.bottomLeft.x, rect.bottom);
    path.quadraticBezierTo(
        rect.left, rect.bottom, rect.left, rect.bottom - r.bottomLeft.y);
    path.lineTo(rect.left, rect.top + r.topLeft.y);
    path.quadraticBezierTo(rect.left, rect.top, rect.left + 20, rect.top);
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _FolderShape(borderRadius: borderRadius * t);
}
