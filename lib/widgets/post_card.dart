import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ui_post.dart';
import '../pages/detail_page.dart';

const avatarIcons = [
  Icons.public,
  Icons.auto_awesome,
  Icons.favorite,
  Icons.bolt,
  Icons.nightlight_round,
  Icons.local_florist,
  Icons.pets,
  Icons.music_note,
  Icons.rocket_launch,
  Icons.face,
];
const avatarColors = [
  Color(0xff376bd6),
  Color(0xff7c4dff),
  Color(0xffe64a75),
  Color(0xff00897b),
  Color(0xff3949ab),
  Color(0xff43a047),
  Color(0xfffb8c00),
  Color(0xff8e24aa),
  Color(0xff039be5),
  Color(0xff546e7a),
];

class PostCard extends StatefulWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  final bool canDelete;
  final Future<void> Function()? onDeleted;
  final String token;
  final double? currentLatitude, currentLongitude;
  final int currentUserId;
  final bool hideAuthor;
  const PostCard({
    super.key,
    required this.post,
    this.onActionChanged,
    this.canDelete = false,
    this.onDeleted,
    this.token = '',
    this.currentLatitude,
    this.currentLongitude,
    this.currentUserId = 0,
    this.hideAuthor = false,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool expanded = false;
  String? _distanceLabel() {
    final p = widget.post;
    if (p.authorId == widget.currentUserId ||
        p.latitude == null ||
        p.longitude == null ||
        widget.currentLatitude == null ||
        widget.currentLongitude == null) {
      return null;
    }
    final latScale = 111.2;
    final lonScale = 111.2 * math.cos(widget.currentLatitude! * math.pi / 180);
    final d = math.sqrt(
      math.pow((p.latitude! - widget.currentLatitude!) * latScale, 2) +
          math.pow((p.longitude! - widget.currentLongitude!) * lonScale, 2),
    );
    if (d > 100) return null;
    return '相距${d < 1 ? d.toStringAsFixed(2) : d.round()}km';
  }

  String _relativeTime() {
    final date = DateTime.tryParse(widget.post.time)?.toLocal();
    if (date == null) return widget.post.time;
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _openDetail() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DetailPage(
        post: widget.post,
        token: widget.token,
        onActionChanged: widget.onActionChanged,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = widget.post;
    final distance = _distanceLabel();

    if (!widget.hideAuthor) {
      return _buildDiscoveryCard(context, c, p, distance);
    }

    return _buildProfileRow(context, c, p, distance);
  }

  Widget _buildDiscoveryCard(
    BuildContext context,
    ColorScheme colors,
    UiPost post,
    String? distance,
  ) {
    final hasImage = post.imageUrl?.isNotEmpty == true;
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openDetail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                GestureDetector(
                  onTap: () => _showFullImage(context, post.imageUrl!),
                  child: Hero(
                    tag: 'post-image-${post.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 170,
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: colors.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                _textCover(colors),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.text.trim().isNotEmpty)
                      Text(
                        post.text.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    if (post.text.trim().isEmpty)
                      Text(
                        hasImage ? '图片动态' : '分享新鲜事',
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              avatarColors[post.authorAvatarId.clamp(0, 9)],
                          child: Icon(
                            avatarIcons[post.authorAvatarId.clamp(0, 9)],
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (post.city.isNotEmpty || distance != null)
                                Text(
                                  [
                                    post.city,
                                    if (distance != null) distance,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.favorite_border,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.likes}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textCover(ColorScheme colors) => Container(
    height: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [colors.primaryContainer, colors.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Icon(
      Icons.format_quote_rounded,
      size: 32,
      color: colors.onPrimaryContainer,
    ),
  );

  Widget _buildProfileRow(
    BuildContext context,
    ColorScheme colors,
    UiPost post,
    String? distance,
  ) {
    return ClipRect(
      child: Column(
        children: [
          GestureDetector(
            onTap: _openDetail,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            _relativeTime(),
                            if (distance != null) distance,
                          ].join(' · '),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (post.text.trim().isNotEmpty)
                    Text(
                      post.text.trim(),
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.35,
                        color: colors.onSurface,
                      ),
                    ),
                  if (post.imageUrl?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: GestureDetector(
                        onTap: () => _showFullImage(context, post.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: Image.network(
                              post.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Hero(
          tag: 'post-image-${widget.post.id}',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}
