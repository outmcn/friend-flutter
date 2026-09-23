import 'package:flutter/material.dart';
import 'post_card.dart';

class ProfileCard extends StatelessWidget {
  final String nickname;
  final String city;
  final int following, followers, likes, posts, activeDays, avatarId;
  final VoidCallback? onAvatarTap;
  final Widget? actions;
  final bool showEdit;
  final VoidCallback? onEdit;
  const ProfileCard({
    super.key,
    required this.nickname,
    required this.city,
    required this.following,
    required this.followers,
    required this.likes,
    required this.posts,
    required this.activeDays,
    required this.avatarId,
    this.onAvatarTap,
    this.actions,
    this.showEdit = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final avatar = avatarId.clamp(0, 9);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [c.surfaceContainer, c.primaryContainer],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                    if (showEdit)
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: c.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (city.isNotEmpty)
                      _badge(
                        context,
                        city,
                        c.primaryContainer,
                        c.onPrimaryContainer,
                      ),
                    const SizedBox(width: 6),
                    _badge(
                      context,
                      '$activeDays天',
                      c.secondaryContainer,
                      c.onSecondaryContainer,
                    ),
                  ],
                ),
                if (actions != null) ...[const SizedBox(height: 8), actions!],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '关注 $following',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '粉丝 $followers',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '获赞 $likes',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '动态 $posts',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: avatarColors[avatar],
              child: Icon(avatarIcons[avatar], size: 48, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
