import 'package:flutter/material.dart';

import '../models/ui_post.dart';
import '../widgets/empty_state.dart';
import '../widgets/post_card.dart';

class ProfileContentPage extends StatefulWidget {
  final String title;
  final List<UiPost> posts;
  final bool canDelete;
  final Future<void> Function() onDeleted;

  const ProfileContentPage({
    super.key,
    required this.title,
    required this.posts,
    required this.canDelete,
    required this.onDeleted,
  });

  @override
  State<ProfileContentPage> createState() => _ProfileContentPageState();
}

class _ProfileContentPageState extends State<ProfileContentPage> {
  late List<UiPost> posts;

  @override
  void initState() {
    super.initState();
    posts = List<UiPost>.of(widget.posts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 40, title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.onDeleted();
        },
        child: posts.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: EmptyState(text: '${widget.title}为空'),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => PostCard(
                  post: posts[index],
                  canDelete: widget.canDelete,
                  hideAuthor: true,
                  onDeleted: () async {
                    await widget.onDeleted();
                    if (mounted) {
                      setState(() => posts.removeAt(index));
                    }
                  },
                ),
              ),
      ),
    );
  }
}
