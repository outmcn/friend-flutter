import 'package:flutter/material.dart';
import '../models/ui_post.dart';
import '../pages/detail_page.dart';

class PostCard extends StatelessWidget {
  final UiPost post;
  final Future<void> Function()? onActionChanged;
  const PostCard({super.key, required this.post, this.onActionChanged});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetailPage(post: post, onActionChanged: onActionChanged),
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
                    backgroundColor: c.primary,
                    child: Icon(Icons.public, size: 21, color: c.onPrimary),
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
                          post.time,
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  Text('0', style: TextStyle(color: c.onSurfaceVariant)),
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
