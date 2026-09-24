import 'package:flutter/material.dart';
import 'post_card.dart';

class CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final ColorScheme colors;
  final bool isSelf;
  final VoidCallback onAvatarTap;
  final VoidCallback onLongPress;
  final EdgeInsets padding;
  const CommentTile({
    super.key,
    required this.comment,
    required this.colors,
    required this.isSelf,
    required this.onAvatarTap,
    required this.onLongPress,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) {
    final avatarId = ((comment['avatarId'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                backgroundColor: avatarColors[avatarId],
                child: Icon(avatarIcons[avatarId], color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                comment['nickname']?.toString() ?? '评论',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isSelf ||
                                (comment['city']?.toString() ?? '').isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  isSelf ? '我' : comment['city'].toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment['content']?.toString() ?? '', softWrap: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
