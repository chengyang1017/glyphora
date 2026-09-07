import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../social/domain/repositories/friend_repository.dart';
import '../../domain/models/chat_thread.dart';
import '../cubit/chat_cubit.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProfileRepository _profileRepository;
  late final FriendRepository _friendRepository;

  final Map<String, UserModel?> _userCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profileRepository = context.read<ProfileRepository>();
    _friendRepository = context.read<FriendRepository>();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<UserModel?> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    final user = await _profileRepository.getProfile(userId);
    _userCache[userId] = user;
    return user;
  }

  String _displayNameOf(BuildContext context, UserModel? user) {
    if (user != null) {
      final locale = Localizations.localeOf(context);

      final displayName = user
          .displayNameFor(
            languageCode: locale.languageCode,
            scriptCode: locale.scriptCode ?? '',
          )
          .trim();

      if (displayName.isNotEmpty) {
        return displayName;
      }
    }

    final email = user?.email?.trim() ?? '';

    return email.isNotEmpty
        ? email
        : AppLocalizations.of(context)!.get('unknownUser');
  }

  String _formatTime(DateTime? date, AppLocalizations l10n) {
    if (date == null) return '';

    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}${l10n.minutesAgo}';
    if (diff.inDays < 1) return '${diff.inHours}${l10n.hoursAgo}';
    if (diff.inDays < 7) return '${diff.inDays}${l10n.daysAgo}';
    return '${localDate.month}/${localDate.day}';
  }

  void _showUserProfile(String userId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FutureBuilder<UserModel?>(
          future: _getUser(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: LoadingIndicator());
            }

            final user = snapshot.data;
            final displayName = _displayNameOf(context, user);
            final username = user?.username ?? '';
            final avatarUrl = user?.avatarUrl ?? '';
            final bio = user?.bioText ?? '';
            final tags = user?.tagsList ?? const <String>[];

            return SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    UserAvatar(
                      imageUrl: avatarUrl,
                      displayName: displayName,
                      radius: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (username.isNotEmpty && username != displayName) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade200),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: AppLocalizations.of(
                              context,
                            )!.get('sendMessage'),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _openChat(userId, displayName);
                            },
                          ),
                          _buildAction(
                            icon: Icons.person_outline_rounded,
                            label: AppLocalizations.of(
                              context,
                            )!.get('viewProfile'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              context.push(
                                AppRoutes.userProfileLocation(uid: userId),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(String otherUserId, String displayName) async {
    try {
      final chatCubit = context.read<ChatCubit>();
      final chatId = await chatCubit.getOrCreateChat(otherUserId);
      if (!mounted) return;

      context.push(AppRoutes.chatLocation(chatId: chatId), extra: displayName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.createChatFailed}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = context.watch<auth_cubit.AuthCubit>().user?.id;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.messages), centerTitle: true),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          l10n.messages,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.person_add_rounded,
                    size: 26,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip: l10n.get('friendRequests'),
                  onPressed: () => context.push(AppRoutes.friendRequests),
                ),
                StreamBuilder<int>(
                  stream: _friendRepository.watchIncomingRequestCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count <= 0) {
                      return const SizedBox();
                    }

                    return Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: l10n.get('chats')),
            Tab(text: l10n.get('friends')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatList(currentUserId), _buildFriendsList()],
      ),
    );
  }

  Widget _buildChatList(String currentUserId) {
    final chatCubit = context.watch<ChatCubit>();
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<ChatThread>>(
      stream: chatCubit.watchChats(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${l10n.loadFailed}：${snapshot.error}'));
        }

        final chats = snapshot.data ?? const <ChatThread>[];
        if (chats.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline,
            title: l10n.get('noChats'),
            subtitle: l10n.get('startConversation'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: chats.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 76,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final otherUserId = chat.otherParticipantId(currentUserId);
            final unreadCount = chatCubit.getUnreadCount(chat, currentUserId);

            return FutureBuilder<UserModel?>(
              future: _getUser(otherUserId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState != ConnectionState.done) {
                  return _buildSkeletonTile();
                }

                final user = userSnapshot.data;
                final displayName = _displayNameOf(context, user);
                final avatarUrl = user?.avatarUrl ?? '';
                final hasMessage = chat.lastMessage.trim().isNotEmpty;

                return InkWell(
                  onTap: () {
                    chatCubit.markAsRead(chat.id, currentUserId);
                    context.push(
                      AppRoutes.chatLocation(chatId: chat.id),
                      extra: displayName,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          imageUrl: avatarUrl,
                          displayName: displayName,
                          radius: 24,
                          onTap: otherUserId.isEmpty
                              ? null
                              : () => _showUserProfile(otherUserId),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasMessage
                                    ? chat.lastMessage
                                    : l10n.get('noMessagesYet'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasMessage
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(chat.updatedAt, l10n),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<List<String>>(
      stream: _friendRepository.watchFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        final friendIds = snapshot.data ?? const <String>[];
        if (friendIds.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return EmptyState(
            icon: Icons.people_alt_outlined,
            title: l10n.get('noFriends'),
            subtitle: l10n.get('findFriendsPrompt'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friendIds.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 76,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            final friendId = friendIds[index];

            return FutureBuilder<UserModel?>(
              future: _getUser(friendId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState != ConnectionState.done) {
                  return _buildSkeletonTile();
                }

                final user = userSnapshot.data;
                final displayName = _displayNameOf(context, user);
                final email = user?.email ?? '';
                final avatarUrl = user?.avatarUrl ?? '';

                return InkWell(
                  onTap: () => _showUserProfile(friendId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          imageUrl: avatarUrl,
                          displayName: displayName,
                          radius: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                          ),
                          color: Theme.of(context).primaryColor,
                          splashRadius: 24,
                          onPressed: () => _openChat(friendId, displayName),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade100),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 150,
                  height: 11,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
