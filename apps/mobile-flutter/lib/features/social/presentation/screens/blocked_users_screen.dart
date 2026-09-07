import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/repositories/friend_repository.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friendRepository = context.read<FriendRepository>();
    final profileRepository = context.read<ProfileRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockList), centerTitle: true),
      body: StreamBuilder<List<String>>(
        stream: friendRepository.watchBlockedUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.get('operationFailed')));
          }

          final userIds = snapshot.data ?? const <String>[];
          if (userIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.get('blockedUsersEmpty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: userIds.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final userId = userIds[index];

              return FutureBuilder<UserModel?>(
                future: profileRepository.getProfile(userId),
                builder: (context, profileSnapshot) {
                  final user = profileSnapshot.data;
                  final locale = Localizations.localeOf(context);

                  final displayName = user
                      ?.displayNameFor(
                        languageCode: locale.languageCode,
                        scriptCode: locale.scriptCode ?? '',
                      )
                      .trim();

                  final title = displayName == null || displayName.isEmpty
                      ? l10n.get('unknownUser')
                      : displayName;
                  final username = user?.username.trim() ?? '';
                  final avatarUrl = user?.avatarUrl ?? '';
                  final avatarText = title.runes.isEmpty
                      ? '?'
                      : String.fromCharCode(title.runes.first);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty ? Text(avatarText) : null,
                    ),
                    title: Text(title),
                    subtitle: username.isEmpty ? null : Text('@$username'),
                    onTap: () => context.push(
                      AppRoutes.userProfileLocation(uid: userId),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await friendRepository.unblockUser(userId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.get('userUnblocked'))),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.get('operationFailed')),
                            ),
                          );
                        }
                      },
                      child: Text(l10n.get('unblockUser')),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
