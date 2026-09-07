import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../post/domain/models/post_model.dart';
import '../../../post/presentation/widgets/post_item_card.dart';

class ProfilePostSliverList extends StatelessWidget {
  final AsyncSnapshot<List<PostModel>> snapshot;
  final AppLocalizations l10n;

  const ProfilePostSliverList({
    super.key,
    required this.snapshot,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverToBoxAdapter(
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.all(32),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              '${l10n.error}：${snapshot.error}',
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
      );
    }

    final posts = snapshot.data ?? <PostModel>[];

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 44,
                color: colors.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noDynamic,
                style: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = posts[index];

        return Container(
          color: colors.surface,
          child: Column(
            children: [
              PostItemCard(
                post: post,
                showUserInfo: false,
                showLanguageBadge: true,
              ),
              if (index < posts.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outlineVariant,
                ),
            ],
          ),
        );
      }, childCount: posts.length),
    );
  }
}
