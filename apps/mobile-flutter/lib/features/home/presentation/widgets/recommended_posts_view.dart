import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import '../../../post/domain/models/post_model.dart';
import '../../../post/domain/repositories/post_repository.dart';
import '../../../post/presentation/widgets/post_item_card.dart';

class RecommendedPostsView extends StatelessWidget {
  const RecommendedPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<auth_cubit.AuthCubit>();
    final l10n = AppLocalizations.of(context)!;

    if (authProvider.user == null) {
      return _InterestEmptyState(
        icon: Icons.login_rounded,
        title: l10n.get('recommendedLoginTitle'),
        description: l10n.get('recommendedLoginDescription'),
      );
    }

    if (!authProvider.interestsLoaded) {
      if (authProvider.interestsError != null) {
        return _InterestEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.get('interestsLoadFailed'),
          description: l10n.get('interestsLoadFailedDescription'),
          actionLabel: l10n.get('retry'),
          onAction: authProvider.retryLoadInterests,
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    final interests = authProvider.interests;

    if (interests.isEmpty) {
      return _InterestEmptyState(
        icon: Icons.favorite_border_rounded,
        title: l10n.get('noInterestsTitle'),
        description: l10n.get('noInterestsDescription'),
      );
    }

    return _InterestedPostList(interests: interests);
  }
}

class _InterestedPostList extends StatefulWidget {
  final Set<String> interests;

  const _InterestedPostList({required this.interests});

  @override
  State<_InterestedPostList> createState() => _InterestedPostListState();
}

class _InterestedPostListState extends State<_InterestedPostList> {
  Timer? _refreshTimer;

  List<PostModel>? _posts;
  Object? _error;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _refresh(showLoading: true);

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant _InterestedPostList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interestsChanged =
        oldWidget.interests.length != widget.interests.length ||
        !oldWidget.interests.containsAll(widget.interests);

    if (interestsChanged) {
      _refresh(showLoading: true);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<PostModel>> _loadPosts() async {
    final repository = context.read<PostRepository>();
    final orderedInterests = widget.interests.toList()..sort();
    final requests = <Future<List<PostModel>>>[];

    for (final interest in orderedInterests) {
      final separatorIndex = interest.indexOf('::');

      if (separatorIndex <= 0 || separatorIndex >= interest.length - 2) {
        continue;
      }

      final languageCode = interest.substring(0, separatorIndex).trim();
      final category = interest.substring(separatorIndex + 2).trim();

      if (languageCode.isEmpty || category.isEmpty) {
        continue;
      }

      requests.add(
        repository.getPosts(category: category, languageCode: languageCode),
      );
    }

    if (requests.isEmpty) {
      return const <PostModel>[];
    }

    final batches = await Future.wait(requests);
    final byPostId = <String, PostModel>{};

    for (final batch in batches) {
      for (final post in batch) {
        byPostId.putIfAbsent(post.id, () => post);
      }
    }

    final posts = byPostId.values.toList();

    posts.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return posts;
  }

  Future<void> _refresh({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final posts = await _loadPosts();

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = posts;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Widget _refreshableState({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: constraints.maxHeight, child: child)],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _posts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _posts == null) {
      return _refreshableState(
        child: _InterestEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.get('postsLoadFailed'),
          description: '$_error',
        ),
      );
    }

    final posts = _posts ?? const <PostModel>[];

    if (posts.isEmpty) {
      return _refreshableState(
        child: _InterestEmptyState(
          icon: Icons.inbox_outlined,
          title: l10n.get('noRecommendedPostsTitle'),
          description: l10n.get('noRecommendedPostsDescription'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: posts.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) {
          return PostItemCard(
            post: posts[index],
            showUserInfo: true,
            showLanguageBadge: true,
          );
        },
      ),
    );
  }
}

class _InterestEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InterestEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.primary, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.56),
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
