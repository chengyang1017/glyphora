import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import '../../domain/models/discover_user.dart';
import '../cubit/discover_cubit.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    final authCubit = context.read<auth_cubit.AuthCubit>();
    final user = authCubit.user;
    if (user != null) {
      _currentUserId = user.id;
    }
  }

  String _displayNameOf(DiscoverUser user) {
    final locale = Localizations.localeOf(context);

    final displayName = user
        .displayNameFor(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode ?? '',
        )
        .trim();

    return displayName.isNotEmpty
        ? displayName
        : user.username;
  }

  Future<void> _startChat(DiscoverUser user) async {
    try {
      final discoverCubit = context.read<DiscoverCubit>();
      final chatId = await discoverCubit.getOrCreateChat(user.id);
      if (!mounted) return;
      context.push(
        AppRoutes.chatLocation(chatId: chatId),
        extra: _displayNameOf(user),
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.createChatFailed}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendFriendRequest(DiscoverUser user) async {
    try {
      final discoverCubit = context.read<DiscoverCubit>();
      await discoverCubit.sendFriendRequest(user.id);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.getWithArgs('friendRequestSentTo', {'name': _displayNameOf(user)}),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.get('friendRequestSendFailed')}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToProfile(String userId) {
    context.push(AppRoutes.userProfileLocation(uid: userId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.discover), centerTitle: true),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.discover,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    final discoverCubit = context.watch<DiscoverCubit>();
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<DiscoverUser>>(
      stream: discoverCubit.watchAllUsers(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${l10n.loadFailed}：${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final users = snapshot.data ?? const <DiscoverUser>[];
        if (users.isEmpty) {
          return EmptyState(
            icon: Icons.people_outline,
            title: l10n.noOtherUsers,
            subtitle: l10n.get('inviteFriendsPrompt'),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: users.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            indent: 72,
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            final displayName = _displayNameOf(user);

            return InkWell(
              onTap: () => _navigateToProfile(user.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      imageUrl: user.avatarUrl,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (user.username.isNotEmpty &&
                              displayName != user.username)
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 22,
                      ),
                      color: Colors.blue,
                      tooltip: l10n.startChat,
                      onPressed: () => _startChat(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined, size: 22),
                      color: Colors.green,
                      tooltip: l10n.addFriend,
                      onPressed: () => _sendFriendRequest(user),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
