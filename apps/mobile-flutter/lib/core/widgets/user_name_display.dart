import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

class UserNameDisplay extends StatelessWidget {
  final String uid;

  const UserNameDisplay({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return const _AnonymousUserDisplay();
    }

    final repository = context.read<ProfileRepository>();

    return StreamBuilder<UserModel?>(
      stream: repository.watchProfile(normalizedUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AnonymousUserDisplay();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const _AnonymousUserDisplay();
        }

        final locale = Localizations.localeOf(context);

        final username = user.username.trim();
        final avatar = user.avatarUrl.trim();

        final displayName = user
            .displayNameFor(
              languageCode: locale.languageCode,
              scriptCode: locale.scriptCode ?? '',
            )
            .trim();

        final resolvedDisplayName = displayName.isNotEmpty
            ? displayName
            : username.isNotEmpty
            ? '@$username'
            : '匿名用户';

        final avatarLetter = resolvedDisplayName.isNotEmpty
            ? resolvedDisplayName.characters.first.toUpperCase()
            : '匿';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            context.push(AppRoutes.userProfileLocation(uid: normalizedUid));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: ClipOval(
                  child: avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          placeholder: (_, _) {
                            return Container(
                              width: 16,
                              height: 16,
                              color: Colors.blue.shade50,
                            );
                          },
                          errorWidget: (_, _, _) {
                            return _AvatarFallback(letter: avatarLetter);
                          },
                        )
                      : _AvatarFallback(letter: avatarLetter),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  resolvedDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String letter;

  const _AvatarFallback({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      color: Colors.blue.shade50,
      alignment: Alignment.center,
      child: Text(
        letter,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

class _AnonymousUserDisplay extends StatelessWidget {
  const _AnonymousUserDisplay();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircleAvatar(
            radius: 8,
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.person, size: 11, color: Colors.blue),
          ),
        ),
        SizedBox(width: 6),
        Text(
          '匿名用户',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
