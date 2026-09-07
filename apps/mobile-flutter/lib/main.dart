import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import 'app/cubit/app_language_cubit.dart';
import 'app/cubit/app_language_state.dart';
import 'app/cubit/app_theme_cubit.dart';
import 'app/di/app_dependencies.dart';
import 'app/l10n/app_localizations.dart';
import 'app/router/app_router.dart';
import 'app/router/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'core/services/deep_link_service.dart';
import 'features/auth/domain/repositories/account_history_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/user_backend_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/chat/application/ports/chat_media_repository.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/domain/repositories/live_draft_repository.dart';
import 'features/chat/presentation/cubit/chat_cubit.dart';
import 'features/discover/domain/repositories/discover_repository.dart';
import 'features/discover/presentation/cubit/discover_cubit.dart';
import 'features/feed/presentation/cubit/feed_cubit.dart';
import 'features/notes/application/ports/note_media_repository.dart';
import 'features/notes/domain/repositories/note_repository.dart';
import 'features/post/application/ports/post_media_repository.dart';
import 'features/post/domain/repositories/post_repository.dart';
import 'features/post/presentation/cubit/post_cubit.dart';
import 'features/profile/application/ports/profile_media_repository.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/social/domain/repositories/follow_repository.dart';
import 'features/social/domain/repositories/friend_repository.dart';
import 'features/social/presentation/cubit/friend_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final dependencies = AppDependencies.create();

  DeepLinkService.instance.start(
    openPostRoute: (postId) async {
      await appRouter.push<void>(AppRoutes.postDetailLocation(postId: postId));
    },
  );

  runApp(MyApp(dependencies: dependencies));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: dependencies.authRepository),
        Provider<AccountHistoryRepository>.value(
          value: dependencies.accountHistoryRepository,
        ),
        Provider<UserBackendRepository>.value(
          value: dependencies.userBackendRepository,
        ),
        Provider<ChatRepository>.value(value: dependencies.chatRepository),
        Provider<ChatMediaRepository>.value(
          value: dependencies.chatMediaRepository,
        ),
        Provider<LiveDraftRepository>.value(
          value: dependencies.liveDraftRepository,
        ),
        Provider<DiscoverRepository>.value(
          value: dependencies.discoverRepository,
        ),
        Provider<NoteRepository>.value(value: dependencies.noteRepository),
        Provider<NoteMediaRepository>.value(
          value: dependencies.noteMediaRepository,
        ),
        Provider<PostRepository>.value(value: dependencies.postRepository),
        Provider<PostMediaRepository>.value(
          value: dependencies.postMediaRepository,
        ),
        Provider<ProfileRepository>.value(
          value: dependencies.profileRepository,
        ),
        Provider<ProfileMediaRepository>.value(
          value: dependencies.profileMediaRepository,
        ),
        Provider<FriendRepository>.value(value: dependencies.friendRepository),
        Provider<FollowRepository>.value(value: dependencies.followRepository),
        BlocProvider<AppLanguageCubit>(create: (_) => AppLanguageCubit()),
        BlocProvider<AppThemeCubit>(create: (_) => AppThemeCubit()),
        BlocProvider<auth_cubit.AuthCubit>(
          create: (context) => auth_cubit.AuthCubit(
            authRepository: context.read<AuthRepository>(),
            userRepository: context.read<UserBackendRepository>(),
          )..loadUser(),
        ),
        BlocProvider<ChatCubit>(
          create: (context) => ChatCubit(
            repository: context.read<ChatRepository>(),
            mediaRepository: context.read<ChatMediaRepository>(),
          ),
        ),
        BlocProvider<FriendCubit>(
          create: (context) =>
              FriendCubit(repository: context.read<FriendRepository>()),
        ),
        BlocProvider<DiscoverCubit>(
          create: (context) => DiscoverCubit(
            repository: context.read<DiscoverRepository>(),
            chatRepository: context.read<ChatRepository>(),
            friendRepository: context.read<FriendRepository>(),
          ),
        ),
        BlocProvider<FeedCubit>(
          create: (context) =>
              FeedCubit(repository: context.read<PostRepository>()),
        ),
        BlocProvider<PostCubit>(
          create: (context) => PostCubit(
            repository: context.read<PostRepository>(),
            mediaRepository: context.read<PostMediaRepository>(),
          ),
        ),
      ],
      child: BlocBuilder<AppThemeCubit, AppThemeMode>(
        builder: (context, appThemeMode) {
          return BlocBuilder<AppLanguageCubit, AppLanguageState>(
            builder: (context, languageState) {
              return BlocListener<auth_cubit.AuthCubit, AuthState>(
                listenWhen: (previous, current) {
                  return previous.isInitialized != current.isInitialized ||
                      previous.user?.id != current.user?.id;
                },
                listener: (context, state) {
                  appRouter.refresh();
                },
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context)?.appTitle ?? 'Glyphora',
                  locale: languageState.locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    FlutterQuillLocalizations.delegate,
                  ],
                  localeResolutionCallback: (locale, supportedLocales) {
                    if (locale == null) {
                      return const Locale('zh');
                    }

                    for (final supportedLocale in supportedLocales) {
                      if (supportedLocale.languageCode == locale.languageCode &&
                          supportedLocale.scriptCode == locale.scriptCode) {
                        return supportedLocale;
                      }
                    }

                    for (final supportedLocale in supportedLocales) {
                      if (supportedLocale.languageCode == locale.languageCode &&
                          supportedLocale.scriptCode == null) {
                        return supportedLocale;
                      }
                    }

                    return const Locale('zh');
                  },
                  theme: AppTheme.light,
                  darkTheme: AppTheme.midnight,
                  themeMode: appThemeMode == AppThemeMode.midnight
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  routerConfig: appRouter,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
