import 'package:flutter/material.dart';
import '../models/ui_post.dart';
import '../pages/detail_page.dart';
import 'dart:math' as math;

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

class PostCard extends StatelessWidget {
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
  String? _distanceLabel() {
    if (post.authorId == currentUserId ||
        post.latitude == null ||
        post.longitude == null ||
        currentLatitude == null ||
        currentLongitude == null) {
      return null;
    }
    final latScale = 111.2;
    final lonScale = 111.2 * math.cos(currentLatitude! * math.pi / 180);
    final distance = math.sqrt(
      math.pow((post.latitude! - currentLatitude!) * latScale, 2) +
          math.pow((post.longitude! - currentLongitude!) * lonScale, 2),
    );
    return '相距${distance < 1 ? distance.toStringAsFixed(2) : distance.round()}km';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPage(
            post: post,
            token: token,
            onActionChanged: onActionChanged,
          ),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor:
                        avatarColors[post.authorAvatarId.clamp(0, 9)],
                    child: Icon(
                      avatarIcons[post.authorAvatarId.clamp(0, 9)],
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
                          post.author,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.onSurface,
                          ),
                        ),
                        Text(
                          [
                            post.time,
                            if (_distanceLabel() != null) _distanceLabel()!,
                          ].join(' · '),
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      onPressed: onDeleted,
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
              Text(
                post.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: c.onSurface,
                ),
              ),
              if (post.imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
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
                    '${post.likes}',
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
                    '${post.comments}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.star_border, size: 19, color: c.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    '${post.favorites}',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
