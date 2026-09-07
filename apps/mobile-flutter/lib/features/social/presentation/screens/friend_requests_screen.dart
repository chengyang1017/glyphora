import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/models/friend_request.dart';
import '../../domain/repositories/friend_repository.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friendRepository = context.read<FriendRepository>();
    final profileRepository = context.read<ProfileRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('friendRequests')),
        centerTitle: true,
      ),
      body: StreamBuilder<List<FriendRequest>>(
        stream: friendRepository.watchIncomingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('${l10n.loadFailed}: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? const <FriendRequest>[];
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add_disabled,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('noFriendRequests'),
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return FutureBuilder<UserModel?>(
                future: profileRepository.getProfile(request.fromUserId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: const CircularProgressIndicator(),
                      title: Text(l10n.get('loading')),
                    );
                  }

                  final user = userSnapshot.data;
                  final locale = Localizations.localeOf(context);

                  final resolvedName = user
                      ?.displayNameFor(
                        languageCode: locale.languageCode,
                        scriptCode: locale.scriptCode ?? '',
                      )
                      .trim();

                  final displayName =
                      resolvedName != null && resolvedName.isNotEmpty
                      ? resolvedName
                      : l10n.get('unknownUser');
                  final avatarUrl = user?.avatarUrl ?? '';
                  final initial = displayName.isEmpty
                      ? '?'
                      : displayName.substring(0, 1).toUpperCase();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.get('friendRequestDescription'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await friendRepository.acceptRequest(
                                      request.fromUserId,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.getWithArgs(
                                            'friendRequestAccepted',
                                            {'name': displayName},
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${l10n.get('operationFailed')}: $error',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(l10n.get('accept')),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await friendRepository.rejectRequest(
                                      request.fromUserId,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.get('friendRequestRejected'),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${l10n.get('operationFailed')}: $error',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(l10n.get('reject')),
                              ),
                            ],
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
      ),
    );
  }
}
