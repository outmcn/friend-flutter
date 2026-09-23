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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _openDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            avatarColors[p.authorAvatarId.clamp(0, 9)],
                        child: Icon(
                          avatarIcons[p.authorAvatarId.clamp(0, 9)],
                          size: 21,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.author,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.onSurface,
                              ),
                            ),
                            Text(
                              [
                                _relativeTime(),
                                if (distance != null) distance,
                              ].join(' · '),
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.canDelete)
                        IconButton(
                          onPressed: widget.onDeleted,
                          icon: Icon(
                            Icons.delete_outline,
                            color: c.onSurfaceVariant,
                          ),
                        )
                      else
                        Icon(Icons.more_horiz, color: c.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (p.text.isNotEmpty)
                    Text(
                      p.text,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: c.onSurface,
                      ),
                    ),
                  if (p.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Hero(
                        tag: 'post-image-${p.id}',
                        child: GestureDetector(
                          onTap: () => _showFullImage(context, p.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: SizedBox(
                              height: 240,
                              width: double.infinity,
                              child: Image.network(
                                p.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 19,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${p.likes}',
                        style: TextStyle(color: c.onSurfaceVariant),
                      ),
                      const SizedBox(width: 20),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${p.comments}',
                        style: TextStyle(color: c.onSurfaceVariant),
                      ),
                      const SizedBox(width: 20),
                      Icon(
                        Icons.star_border,
                        size: 19,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${p.favorites}',
                        style: TextStyle(color: c.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: double.infinity,
              color: const Color(0xff303238),
              padding: EdgeInsets.fromLTRB(16, 10, 16, expanded ? 14 : 10),
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '空间',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '发布时间：${_relativeTime()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            '距离：$distance',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: const [
                        Text(
                          '空间',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 20,
                        ),
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
