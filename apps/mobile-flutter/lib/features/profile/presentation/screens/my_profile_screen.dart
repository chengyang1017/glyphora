import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../post/domain/models/post_model.dart';
import '../../../post/domain/repositories/post_repository.dart';
import '../../../post/presentation/widgets/post_item_card.dart';
import '../../application/ports/profile_media_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/birthday_editor_dialog.dart';
import '../widgets/language_editor_sheet.dart';
import '../widgets/nickname_editor_sheet.dart';
import '../widgets/profile_bio_tags_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_language_section.dart';
import '../widgets/tag_editor_sheet.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final String? _userId;
  late final String _userEmail;
  late final ProfileCubit _profileCubit;

  final List<String> _presetTags = [
    'Flutter',
    'Python',
    'JavaScript',
    'Java',
    'C++',
    'Go',
    'Rust',
    '前端',
    '后端',
    '全栈',
    'AI',
    '机器学习',
    '深度学习',
    'Android',
    'iOS',
    'Web',
    '小程序',
    '游戏开发',
    '摄影',
    '旅行',
    '美食',
    '音乐',
    '电影',
    '读书',
    '健身',
    '篮球',
    '足球',
    '跑步',
    '游泳',
    '学生',
    '上班族',
    '创业者',
    '自由职业',
  ];

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthCubit>().user;
    _userId = authUser?.id;
    _userEmail = authUser?.email ?? '';

    _profileCubit = ProfileCubit(
      postRepository: context.read<PostRepository>(),
      profileRepository: context.read<ProfileRepository>(),
      mediaRepository: context.read<ProfileMediaRepository>(),
    );
    loadProfile();
  }

  @override
  void dispose() {
    _profileCubit.close();
    super.dispose();
  }

  Future<void> loadProfile() async {
    final userId = _userId;
    if (userId == null) return;
    await _profileCubit.loadProfile(userId);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _editTags() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final result = await showTagEditorSheet(
      context: context,
      selectedTags: _profileCubit.state.tagDetails,
      presetTags: _presetTags,
    );

    if (result == null) {
      return;
    }

    try {
      await _profileCubit.updateTags(userId, result);

      if (!mounted) {
        return;
      }

      _showSuccess(context.l10n.tagsUpdated);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  Future<void> _editLanguages() async {
    final userId = _userId;
    if (userId == null) return;

    final result = await showLanguageEditorSheet(
      context: context,
      selectedLanguages: _profileCubit.state.languages,
    );

    if (result == null) return;

    try {
      await _profileCubit.updateLanguages(userId, result);
      _showSuccess(context.l10n.languagesUpdated);
    } catch (e) {
      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  Future<void> _editAge() async {
    final userId = _userId;
    if (userId == null) return;

    final profile = _profileCubit.state;
    final result = await showBirthdayEditorDialog(
      context: context,
      birthday: profile.birthday,
      showAge: profile.showAge,
    );

    if (result == null) return;

    try {
      await _profileCubit.updateBirthday(
        userId,
        result.birthday,
        result.showAge,
      );
      _showSuccess(context.l10n.birthdayUpdated);
    } catch (e) {
      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  Future<void> changeAvatar() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image == null) return;

      await _profileCubit.updateAvatar(userId, File(image.path));
      _showSuccess(context.l10n.avatarUpdated);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.galleryPermission}: ${e.message}'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _showError('${context.l10n.avatarFailed}: $e');
    }
  }

  Future<void> editNickname() async {
    final userId = _userId;
    if (userId == null) return;

    final profile = _profileCubit.state;

    final result = await showNicknameEditorSheet(
      context: context,
      nickname: profile.nickname,
      localizedNames: profile.localizedNames,
    );

    // 取消、点击外面、按返回键都会得到 null
    if (!mounted || result == null) return;

    final nicknameChanged = result.nickname != profile.nickname;

    final localizedNamesChanged = !_localizedNamesEqual(
      result.localizedNames,
      profile.localizedNames,
    );

    try {
      if (nicknameChanged) {
        await _profileCubit.updateNickname(userId, result.nickname);
      }

      if (localizedNamesChanged) {
        await _profileCubit.updateLocalizedNames(userId, result.localizedNames);
      }

      _showSuccess(context.l10n.nicknameUpdated);
    } catch (e) {
      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  bool _localizedNamesEqual(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    String keyOf(Map<String, dynamic> item) {
      final languageCode =
          item['languageCode']?.toString().trim().toLowerCase() ?? '';

      final scriptCode =
          item['scriptCode']?.toString().trim().toLowerCase() ?? '';

      final name = item['name']?.toString().trim() ?? '';

      return '$languageCode|$scriptCode|$name';
    }

    final firstKeys = first.map(keyOf).toList()..sort();

    final secondKeys = second.map(keyOf).toList()..sort();

    for (var i = 0; i < firstKeys.length; i++) {
      if (firstKeys[i] != secondKeys[i]) {
        return false;
      }
    }

    return true;
  }

  Future<void> editUsername() async {
    final userId = _userId;
    if (userId == null) return;

    final controller = TextEditingController(
      text: _profileCubit.state.username,
    );
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editUsernameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.newUsernameLabel,
            hintText: context.l10n.usernameHint,
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (newUsername == null || newUsername.isEmpty) return;

    try {
      await _profileCubit.updateUsername(userId, newUsername);
      _showSuccess(context.l10n.usernameUpdated);
    } catch (e) {
      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  Future<void> _editBio() async {
    final userId = _userId;
    if (userId == null) return;

    final controller = TextEditingController(text: _profileCubit.state.bio);
    final newBio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editBioTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.bioHint,
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 200,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (newBio == null) return;

    try {
      await _profileCubit.updateBio(userId, newBio);
      _showSuccess(context.l10n.bioUpdated);
    } catch (e) {
      _showError('${context.l10n.updateFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      bloc: _profileCubit,
      builder: _buildBody,
    );
  }

  Widget _buildBody(BuildContext context, ProfileState profile) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userId = _userId;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile), centerTitle: true),
        body: Center(
          child: Text(
            l10n.notLoggedIn,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (profile.loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,
        title: Text(
          profile.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadProfile,
        child: StreamBuilder<List<PostModel>>(
          stream: _profileCubit.watchUserPosts(userId),
          builder: (context, postSnapshot) {
            final posts = postSnapshot.data ?? const <PostModel>[];
            final postCount = posts.length;
            final totalLikes = _profileCubit.totalLikesOf(posts);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ProfileHeader(
                    profile: profile,
                    email: _userEmail,
                    postCount: postCount,
                    totalLikes: totalLikes,
                    l10n: l10n,
                    onAvatarTap: changeAvatar,
                    onNicknameTap: editNickname,
                    onUsernameTap: editUsername,
                    onBirthdayTap: _editAge,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProfileBioTagsSection(
                    profileUserId: userId,
                    bio: profile.bio,
                    tags: profile.tagDetails,
                    l10n: l10n,
                    onEditBio: _editBio,
                    onEditTags: _editTags,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProfileLanguageSection(
                    languages: profile.languages,
                    l10n: l10n,
                    onTap: _editLanguages,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.note_alt_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        context.l10n.myNotes,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(context.l10n.myNotesDescription),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.allNotes),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.bookmark_outline_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      title: Text(
                        context.l10n.bookmarksTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(context.l10n.bookmarksDescription),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.bookmarkedPosts),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dynamic_feed_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.myPosts,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (postSnapshot.connectionState == ConnectionState.waiting)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  )
                else if (postSnapshot.hasError)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 45,
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 44,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.postsLoadFailed,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${postSnapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (posts.isEmpty)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Column(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              context.l10n.noPosts,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) {
                        return Divider(height: 1, thickness: 1);
                      }

                      final post = posts[index ~/ 2];
                      return ColoredBox(
                        color: theme.colorScheme.surface,
                        child: PostItemCard(
                          post: post,
                          showUserInfo: false,
                          showLanguageBadge: true,
                        ),
                      );
                    }, childCount: posts.length * 2 - 1),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
