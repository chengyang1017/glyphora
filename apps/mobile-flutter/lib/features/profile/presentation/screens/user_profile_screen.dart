import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../post/domain/models/post_model.dart';
import '../../../post/domain/repositories/post_repository.dart';
import '../../../social/domain/models/friend_relationship_status.dart';
import '../../../social/domain/repositories/friend_repository.dart';
import '../../../social/presentation/widgets/follow_button.dart';
import '../../../social/presentation/widgets/follow_stats.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/profile_language_section.dart';
import '../widgets/profile_post_sliver_list.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final ProfileRepository _profileRepository;
  late final PostRepository _postRepository;
  late final FriendRepository _friendRepository;
  late final ChatCubit _chatCubit;

  String? _currentUserId;
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isBlockedByMe = false;
  bool _interactionBlocked = false;
  FriendRelationshipStatus _relationshipStatus = FriendRelationshipStatus.none;

  @override
  void initState() {
    super.initState();
    _profileRepository = context.read<ProfileRepository>();
    _postRepository = context.read<PostRepository>();
    _friendRepository = context.read<FriendRepository>();
    _chatCubit = context.read<ChatCubit>();
    _currentUserId = context.read<auth_cubit.AuthCubit>().user?.id;
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    await Future.wait([_loadProfile(), _loadBlockState(), _loadRelationship()]);
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _profileRepository.getProfile(widget.uid);
      if (!mounted) return;
      setState(() {
        _userProfile = user;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Profile load failed: $error');
      if (!mounted) return;
      setState(() {
        _userProfile = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBlockState() async {
    if (_currentUserId == null || _currentUserId == widget.uid) return;

    try {
      final results = await Future.wait([
        _friendRepository.isBlockedByMe(widget.uid),
        _friendRepository.isInteractionBlocked(widget.uid),
      ]);
      if (!mounted) return;
      setState(() {
        _isBlockedByMe = results[0];
        _interactionBlocked = results[1];
      });
    } catch (error) {
      debugPrint('Block state load failed: $error');
    }
  }

  Future<void> _loadRelationship() async {
    if (_currentUserId == null || _currentUserId == widget.uid) return;

    try {
      final status = await _friendRepository.getRelationship(widget.uid);
      if (!mounted) return;
      setState(() => _relationshipStatus = status);
    } catch (error) {
      debugPrint('Friend relationship load failed: $error');
    }
  }

  Future<void> _sendFriendRequest() async {
    if (await _friendRepository.isInteractionBlocked(widget.uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.get('blockedInteraction'),
          ),
        ),
      );
      return;
    }

    try {
      await _friendRepository.sendRequest(widget.uid);
      if (!mounted) return;
      setState(() {
        _relationshipStatus = FriendRelationshipStatus.requestSent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.get('friendRequestSent')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.get('friendRequestSendFailed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptFriendRequest(String displayName) async {
    try {
      await _friendRepository.acceptRequest(widget.uid);
      if (!mounted) return;
      setState(() {
        _relationshipStatus = FriendRelationshipStatus.friends;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.getWithArgs('friendRequestAccepted', {'name': displayName}),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.get('operationFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startChat(String displayName) async {
    if (await _friendRepository.isInteractionBlocked(widget.uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.get('blockedInteraction'),
          ),
        ),
      );
      return;
    }

    try {
      final chatId = await _chatCubit.getOrCreateChat(widget.uid);
      if (!mounted) return;
      context.push(AppRoutes.chatLocation(chatId: chatId), extra: displayName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.get('createChatFailed')),
        ),
      );
    }
  }

  Future<void> _toggleBlock(String displayName) async {
    final l10n = AppLocalizations.of(context)!;

    if (_isBlockedByMe) {
      try {
        await _friendRepository.unblockUser(widget.uid);
        if (!mounted) return;
        setState(() {
          _isBlockedByMe = false;
          _interactionBlocked = false;
        });
        await _loadRelationship();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.get('userUnblocked'))));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.get('operationFailed'))));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.get('blockUserConfirmTitle')),
        content: Text(
          l10n.getWithArgs('blockUserConfirmDesc', {'name': displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.get('blockUser')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _friendRepository.blockUser(widget.uid);
      if (!mounted) return;
      setState(() {
        _isBlockedByMe = true;
        _interactionBlocked = true;
        _relationshipStatus = FriendRelationshipStatus.none;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('userBlocked'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('operationFailed'))));
    }
  }

  Stream<List<PostModel>> _watchUserPosts() {
    return _postRepository.watchUserPosts(widget.uid);
  }

  int _totalLikesOf(List<PostModel> posts) {
    return posts.fold<int>(0, (total, post) => total + post.likeCount);
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool _isDefaultBirthday(DateTime? date) {
    return date == null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }

    final user = _userProfile;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.get('userNotFound')),
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            l10n.get('userNotFound'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final username = user.username.isNotEmpty
        ? user.username
        : l10n.get('unknownUser');

    final locale = Localizations.localeOf(context);

    final resolvedName = user
        .displayNameFor(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode ?? '',
        )
        .trim();

    final displayName = resolvedName.isNotEmpty
        ? resolvedName
        : username;
    final avatarUrl = user.avatarUrl;
    final bio = user.bioText;
    final tags = user.tagsList;
    final languages = user.languageList;
    final isMe = _currentUserId == widget.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        centerTitle: true,
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!isMe)
            PopupMenuButton<String>(
              tooltip: l10n.get('moreActions'),
              onSelected: (_) => _toggleBlock(displayName),
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: _isBlockedByMe ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        _isBlockedByMe ? Icons.lock_open : Icons.block,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isBlockedByMe
                            ? l10n.get('unblockUser')
                            : l10n.get('blockUser'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPageData,
        child: StreamBuilder<List<PostModel>>(
          stream: _watchUserPosts(),
          builder: (context, postSnapshot) {
            final posts = _interactionBlocked
                ? const <PostModel>[]
                : postSnapshot.data ?? const <PostModel>[];
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    theme: theme,
                    user: user,
                    username: username,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    postCount: posts.length,
                    totalLikes: _totalLikesOf(posts),
                    isMe: isMe,
                  ),
                ),
                if (bio.isNotEmpty || tags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildBioTagsSection(bio: bio, tags: tags),
                  ),
                if (languages.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ProfileLanguageSection(
                      languages: languages,
                      l10n: l10n,
                      onTap: null,
                    ),
                  ),
                if (_currentUserId != null && !isMe && !_interactionBlocked)
                  SliverToBoxAdapter(
                    child: _buildSharedNotesEntry(displayName),
                  ),
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dynamic_feed_rounded,
                          size: 20,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMe
                              ? l10n.get('myActivity')
                              : l10n.get('theirActivity'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_interactionBlocked)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.get('blockedInteraction'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ProfilePostSliverList(snapshot: postSnapshot, l10n: l10n),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({
    required ThemeData theme,
    required UserModel user,
    required String username,
    required String displayName,
    required String avatarUrl,
    required int postCount,
    required int totalLikes,
    required bool isMe,
  }) {
    final birthday = user.birthday;
    final showPublicAge =
        user.showAge && birthday != null && !_isDefaultBirthday(birthday);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildAvatar(avatarUrl, displayName, theme),
          const SizedBox(height: 16),
          Text(
              displayName,
              style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@$username',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          
          if (showPublicAge) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cake, size: 14, color: Colors.pink[300]),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!.getWithArgs('ageYears', {
                    'age': '${_calculateAge(birthday)}',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FollowStats(
            userId: widget.uid,
            postCount: postCount,
            totalLikes: totalLikes,
          ),
          if (!isMe) ...[
            const SizedBox(height: 20),
            if (_interactionBlocked)
              OutlinedButton.icon(
                onPressed: _isBlockedByMe
                    ? () => _toggleBlock(displayName)
                    : null,
                icon: const Icon(Icons.block, size: 18),
                label: Text(
                  _isBlockedByMe
                      ? AppLocalizations.of(context)!.get('unblockUser')
                      : AppLocalizations.of(context)!.get('blockedInteraction'),
                ),
              )
            else
              _buildActionButtons(displayName),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String displayName, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        if (avatarUrl.isEmpty) return;
        showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.person, size: 200, color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
      child: Hero(
        tag: 'avatar_${widget.uid}',
        child: CircleAvatar(
          radius: 46,
          backgroundColor: Colors.blue.shade50,
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? Text(
                  displayName.isNotEmpty
                      ? displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBioTagsSection({
    required String bio,
    required List<String> tags,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.isNotEmpty)
            Text(
              bio,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          if (bio.isNotEmpty && tags.isNotEmpty) const SizedBox(height: 16),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text('# $tag'),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSharedNotesEntry(String displayName) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.note_alt_outlined),
        title: Text(AppLocalizations.of(context)!.get('sharedNotes')),
        subtitle: Text(
          AppLocalizations.of(
            context,
          )!.getWithArgs('viewSharedNotesWithUser', {'name': displayName}),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push(
            AppRoutes.userNotesLocation(uid: widget.uid),
            extra: displayName,
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(String displayName) {
    final friendAction = _buildFriendAction(displayName);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              Expanded(child: FollowButton(userId: widget.uid, expanded: true)),
              const SizedBox(width: 12),
              Expanded(child: friendAction),
            ],
          );
        }

        return Column(
          children: [
            FollowButton(userId: widget.uid, expanded: true),
            const SizedBox(height: 10),
            friendAction,
          ],
        );
      },
    );
  }

  Widget _buildFriendAction(String displayName) {
    switch (_relationshipStatus) {
      case FriendRelationshipStatus.friends:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _startChat(displayName),
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: Text(
              AppLocalizations.of(context)!.get('friendMessageAction'),
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        );
      case FriendRelationshipStatus.requestSent:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(
              AppLocalizations.of(context)!.get('friendRequestPending'),
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        );
      case FriendRelationshipStatus.requestReceived:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _acceptFriendRequest(displayName),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              AppLocalizations.of(context)!.get('acceptFriendRequest'),
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        );
      case FriendRelationshipStatus.none:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sendFriendRequest,
            icon: const Icon(Icons.group_add_rounded, size: 18),
            label: Text(AppLocalizations.of(context)!.addFriend),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        );
    }
  }
}
