import 'package:flutter/material.dart';
import 'package:glyphora_mobile/app/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import 'node_comment_screen.dart';
import '../cubit/post_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;
import '../../../../core/widgets/user_name_display.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../application/models/local_post_image.dart';
import '../../application/models/post_edit_media_cleanup_plan.dart';
import '../../application/ports/post_media_repository.dart';
import '../../domain/models/post_model.dart';
import '../../domain/repositories/post_repository.dart';
import 'package:glyphora_language_core/glyphora_language_core.dart';
import '../../../translation/presentation/screens/post_translation_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../widgets/post_report_dialog.dart';

class PostDetailRouteScreen extends StatefulWidget {
  final String postId;
  final PostModel? initialPost;

  const PostDetailRouteScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailRouteScreen> createState() => _PostDetailRouteScreenState();
}

class _PostDetailRouteScreenState extends State<PostDetailRouteScreen> {
  Future<PostModel>? _postFuture;

  PostRepository get _postRepository => context.read<PostRepository>();

  @override
  void initState() {
    super.initState();
    _preparePost();
  }

  @override
  void didUpdateWidget(covariant PostDetailRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId != widget.postId ||
        oldWidget.initialPost != widget.initialPost) {
      _preparePost();
    }
  }

  void _preparePost() {
    if (widget.initialPost != null) {
      _postFuture = null;
      return;
    }

    _postFuture = _postRepository.getPost(widget.postId);
  }

  void _retry() {
    setState(() {
      _postFuture = _postRepository.getPost(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialPost = widget.initialPost;

    if (initialPost != null) {
      return PostDetailScreen(postId: widget.postId, post: initialPost);
    }

    final future = _postFuture ??= _postRepository.getPost(widget.postId);

    return FutureBuilder<PostModel>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.postDetail)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 52),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.postsLoadFailed,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final post = snapshot.data;

        if (post == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.postDetail)),
            body: Center(child: Text(context.l10n.postNotFound)),
          );
        }

        return PostDetailScreen(postId: widget.postId, post: post);
      },
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final PostModel post;

  const PostDetailScreen({super.key, required this.postId, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // ✅ 所有字段改为带默认值，不再使用 late
  PostModel _post = PostModel(
    id: '',
    userId: '',
    content: '',
    category: '',
    languageCode: 'zh',
    imageUrls: [],
    likes: [],
    likeCount: 0,
    commentCount: 0,
  );

  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isBookmarkBusy = false;
  bool _isReportBusy = false;
  List<String> _likes = [];
  int _likeCount = 0;
  List<String> _images = [];
  int _currentIndex = 0;
  bool _isUploadingImage = false;
  bool _isEditingImages = false;
  String? _currentUserId;
  DateTime? _currentVersionCreatedAt;

  PostRepository get _postRepository => context.read<PostRepository>();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // ✅ 安全初始化
    _post = widget.post;
    _currentUserId = context.read<auth_cubit.AuthCubit>().user?.id;
    _likes = List<String>.from(_post.likes ?? []);
    _likeCount = _post.likeCount;
    _images = List<String>.from(_post.imageUrls ?? []);
    _isLiked = _currentUserId != null && _likes.contains(_currentUserId);

    final postProvider = context.read<PostCubit>();

    postProvider.seedBookmarkState(_post.id, _post.isBookmarked);

    _isBookmarked = postProvider.bookmarkState(
      _post.id,
      fallback: _post.isBookmarked,
    );

    _post = _post.copyWith(isBookmarked: _isBookmarked);

    _loadCurrentVersionCreatedAt();
  }

  Future<void> _loadCurrentVersionCreatedAt() async {
    final currentLanguageCode = _post.languageCode;

    final primaryLanguageCode =
        _post.primaryLanguageCode ??
        widget.post.primaryLanguageCode ??
        widget.post.languageCode;

    if (currentLanguageCode == null) {
      return;
    }

    if (currentLanguageCode == primaryLanguageCode) {
      _currentVersionCreatedAt = _post.createdAt;
      return;
    }

    try {
      final version = await _postRepository.getLanguageVersion(
        postId: widget.postId,
        languageCode: currentLanguageCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentVersionCreatedAt = version.createdAt;
      });
    } catch (e) {
      debugPrint('加载语言版本发布时间失败: $e');
    }
  }

  String _formatVersionTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString();

    final month = dateTime.month.toString().padLeft(2, '0');

    final day = dateTime.day.toString().padLeft(2, '0');

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return context.l10n.justNow;
    if (difference.inHours < 1)
      return '${difference.inMinutes}${context.l10n.minutesAgo}';
    if (difference.inDays < 1)
      return '${difference.inHours}${context.l10n.hoursAgo}';
    if (difference.inDays < 7)
      return '${difference.inDays}${context.l10n.daysAgo}';
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // 编辑帖子
  // ============================================================
  Future<void> _editPost() async {
    final currentLanguageCode = _post.languageCode ?? _post.primaryLanguageCode;

    if (currentLanguageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.currentLanguageUnavailable)),
      );

      return;
    }

    final previousTitle = _post.title ?? '';
    final previousContent = _post.content ?? '';
    final previousBodyDelta = List<dynamic>.from(_post.bodyDelta);
    final previousImageUrls = List<String>.from(_images);

    final result = await Navigator.push<_PostEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _PostRichEditPage(
          postId: widget.postId,
          languageCode: currentLanguageCode,
          title: previousTitle,
          content: previousContent,
          bodyDelta: previousBodyDelta,
          imageUrls: previousImageUrls,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _images = List<String>.from(result.imageUrls);

      if (_currentIndex >= _images.length) {
        _currentIndex = 0;
      }

      _post = _post.copyWith(
        title: result.title,
        content: result.content,
        bodyDelta: result.bodyDelta,
        imageUrls: _images,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.postUpdated),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // 点赞
  // ============================================================
  Future<void> _toggleLike() async {
    if (_currentUserId == null) return;

    final previousLiked = _isLiked;
    final previousLikeCount = _likeCount;
    final nextLiked = !previousLiked;

    setState(() {
      _isLiked = nextLiked;
      _likeCount = nextLiked
          ? previousLikeCount + 1
          : (previousLikeCount > 0 ? previousLikeCount - 1 : 0);

      _likes = nextLiked ? <String>[_currentUserId!] : <String>[];
    });

    try {
      final postProvider = context.read<PostCubit>();

      final confirmedLikeCount = await postProvider.toggleLike(
        widget.postId,
        liked: nextLiked,
      );

      if (!mounted) return;

      setState(() {
        _likeCount = confirmedLikeCount;

        _post = _post.copyWith(
          likes: List<String>.from(_likes),
          likeCount: confirmedLikeCount,
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLiked = previousLiked;
        _likeCount = previousLikeCount;
        _likes = previousLiked ? <String>[_currentUserId!] : <String>[];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.operationFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 收藏
  // ============================================================
  Future<void> _toggleBookmark() async {
    if (_currentUserId == null || _isBookmarkBusy) {
      return;
    }

    final postProvider = context.read<PostCubit>();

    final previousBookmarked = postProvider.bookmarkState(
      widget.postId,
      fallback: _isBookmarked,
    );

    final nextBookmarked = !previousBookmarked;

    // 乐观更新：先让按钮立即响应。
    setState(() {
      _isBookmarked = nextBookmarked;
      _isBookmarkBusy = true;
      _post = _post.copyWith(isBookmarked: nextBookmarked);
    });

    try {
      final confirmedBookmarked = await postProvider.toggleBookmark(
        widget.postId,
        bookmarked: nextBookmarked,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isBookmarked = confirmedBookmarked;
        _isBookmarkBusy = false;
        _post = _post.copyWith(isBookmarked: confirmedBookmarked);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      // 请求失败：回滚到操作前状态。
      setState(() {
        _isBookmarked = previousBookmarked;
        _isBookmarkBusy = false;
        _post = _post.copyWith(isBookmarked: previousBookmarked);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.bookmarkActionFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 分享
  // ============================================================
  // void _sharePost() {
  //   Share.share(_post.content ?? '');
  // }
  String get _postLink {
    return 'forum://post/${widget.postId}';
  }

  Future<void> _sharePost() async {
    final title = _post.title?.trim() ?? '';
    final content = _post.content?.trim() ?? '';

    final shareText = [
      if (title.isNotEmpty) title,
      if (content.isNotEmpty) content,
      _postLink,
    ].join('\n\n');

    await Share.share(
      shareText,
      subject: title.isNotEmpty ? title : context.l10n.sharePost,
    );
  }

  Future<void> _copyPostLink() async {
    await Clipboard.setData(ClipboardData(text: _postLink));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.postLinkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: Text(context.l10n.sharePost),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _sharePost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(context.l10n.copyLink),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _copyPostLink();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTranslation() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pleaseSignIn)));
      return;
    }

    final existingLanguages = <String>{..._post.availableLanguageCodes};

    final primaryLanguageCode = _post.primaryLanguageCode ?? _post.languageCode;

    if (primaryLanguageCode != null) {
      existingLanguages.add(primaryLanguageCode);
    }

    // 当前正在看的语言
    final currentLanguageCode = _post.languageCode ?? primaryLanguageCode;

    // 翻译入口显示语言库中的全部语言，
    // 只排除当前正在看的语言。
    final targetLanguages = LanguageConfig.allLanguages
        .where((language) => language.code != currentLanguageCode)
        .toList();

    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    final selectedLanguage = await showModalBottomSheet<LanguageConfig>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.selectLanguage,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: targetLanguages.length,
                    itemBuilder: (context, index) {
                      final language = targetLanguages[index];

                      final hasVersion = existingLanguages.contains(
                        language.code,
                      );

                      return ListTile(
                        leading: const Icon(Icons.language_rounded),
                        title: Text(language.nameOf(uiLanguageCode)),
                        subtitle: Text(
                          hasVersion
                              ? context.l10n.languageVersionAvailable
                              : context.l10n.noLanguageVersion,
                        ),
                        trailing: Icon(
                          hasVersion
                              ? Icons.arrow_forward_rounded
                              : Icons.translate_rounded,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext, language);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null || !mounted) {
      return;
    }

    if (existingLanguages.contains(selectedLanguage.code)) {
      await _openExistingLanguageVersion(selectedLanguage);
      return;
    }

    await _chooseTranslationMode(selectedLanguage);
  }

  Future<void> _openExistingLanguageVersion(LanguageConfig language) async {
    await _switchLanguageVersion(language);
  }

  Future<void> _chooseTranslationMode(LanguageConfig language) async {
    final mode = await showModalBottomSheet<TranslationMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.chooseTranslationMethod,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(context.l10n.aiTranslation),
                subtitle: Text(context.l10n.aiTranslationDescription),
                onTap: () {
                  Navigator.pop(sheetContext, TranslationMode.ai);
                },
              ),

              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(context.l10n.manualTranslation),
                subtitle: Text(context.l10n.manualTranslationDescription),
                onTap: () {
                  Navigator.pop(sheetContext, TranslationMode.manual);
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (mode == null || !mounted) {
      return;
    }

    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostTranslationScreen(
          post: _post,
          targetLanguageCode: language.code,
          targetLanguageName: language.nameOf(uiLanguageCode),
          mode: mode,
        ),
      ),
    );

    if (published == true && mounted) {
      setState(() {
        final languages = <String>{
          ..._post.availableLanguageCodes,
          language.code,
        };

        _post = _post.copyWith(availableLanguageCodes: languages.toList());
      });
    }
  }

  List<LanguageConfig> get _availableLanguageVersions {
    final codes = <String>{..._post.availableLanguageCodes};

    final primaryLanguageCode = _post.primaryLanguageCode ?? _post.languageCode;

    if (primaryLanguageCode != null) {
      codes.add(primaryLanguageCode);
    }

    return LanguageConfig.allLanguages
        .where((language) => codes.contains(language.code))
        .toList();
  }

  Future<void> _switchLanguageVersion(LanguageConfig language) async {
    if (_post.languageCode == language.code) {
      return;
    }

    try {
      final primaryLanguageCode =
          _post.primaryLanguageCode ??
          widget.post.primaryLanguageCode ??
          widget.post.languageCode;

      final version = await _postRepository.getLanguageVersion(
        postId: widget.postId,
        languageCode: language.code,
      );

      if (!mounted) return;

      setState(() {
        _post = _post.copyWith(
          title: version.title,
          content: version.content,
          bodyDelta: version.bodyDelta,
          languageCode: language.code,
        );

        _currentVersionCreatedAt = language.code == primaryLanguageCode
            ? _post.createdAt
            : version.createdAt;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.updateFailed}: $e')),
      );
    }
  }

  // ============================================================
  // 删除帖子
  // ============================================================
  Future<void> _deletePost() async {
    if (_currentUserId != _post.userId) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.deletePost,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.l10n.deletePostConfirm,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.l10n.confirmDelete,
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final postProvider = context.read<PostCubit>();
      await postProvider.deletePost(widget.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.postDeleted),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.updateFailed}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================
  // 图片管理
  // ============================================================
  Future<void> _addImages() async {
    if (_images.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.postImageLimit),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1240,
    );
    if (picked.isEmpty || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final postProvider = context.read<PostCubit>();
      final newUrls = await postProvider.uploadImages(widget.postId, picked);

      if (mounted) {
        setState(() {
          _images.addAll(newUrls);
          if (_images.length > 9) _images = _images.sublist(0, 9);
          _isUploadingImage = false;
        });
        _post = _post.copyWith(imageUrls: _images);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.updateFailed}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.deleteImage),
        content: Text(context.l10n.deleteImageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.l10n.delete,
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final targetUrl = _images[index];
      setState(() {
        _images.removeAt(index);
        if (_currentIndex >= _images.length) _currentIndex = 0;
      });

      final postProvider = context.read<PostCubit>();
      await postProvider.removeImage(widget.postId, _images);
      await postProvider.deleteImageFromStorage(targetUrl);
      _post = _post.copyWith(imageUrls: _images);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.updateFailed}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reorderImages(int oldIndex, int newIndex) async {
    setState(() {
      final img = _images.removeAt(oldIndex);
      _images.insert(newIndex, img);
      _currentIndex = newIndex;
    });
    try {
      final postProvider = context.read<PostCubit>();
      await postProvider.updateImages(widget.postId, _images);
      _post = _post.copyWith(imageUrls: _images);
    } catch (e) {
      setState(() {
        final img = _images.removeAt(newIndex);
        _images.insert(oldIndex, img);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.updateFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
              ),
              title: Text(
                context.l10n.deleteThisImage,
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteImage(index);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFF2563EB),
              ),
              title: Text(context.l10n.appendMoreImages),
              onTap: () {
                Navigator.pop(context);
                _addImages();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 评论
  // ============================================================
  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: CommentScreen(postId: widget.postId)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 举报帖子
  // ============================================================
  Future<void> _reportPost() async {
    if (_isReportBusy) {
      return;
    }

    final draft = await showPostReportDialog(context);

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _isReportBusy = true;
    });

    try {
      await _postRepository.reportPost(
        postId: widget.postId,
        reason: draft.reason,
        details: draft.details,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reportSubmitted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReportBusy = false;
        });
      }
    }
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isOwner = _currentUserId == _post.userId;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(isOwner),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_images.isNotEmpty)
                    _isEditingImages
                        ? _buildEditableImageList()
                        : _buildImageViewer(),
                  _buildContent(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isOwner) {
    final globalBookmarked =
        context.watch<PostCubit>().bookmarkState(
          widget.postId,
          fallback: _isBookmarked,
        );

    return AppBar(
      title: Text(
        context.l10n.details,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      actions: [
        IconButton(
          tooltip: context.l10n.bookmark,
          onPressed:
              _isBookmarkBusy ? null : _toggleBookmark,
          icon: Icon(
            globalBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: globalBookmarked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (isOwner && _images.length > 1)
          IconButton(
            icon: Icon(
              _isEditingImages
                  ? Icons.done_all_rounded
                  : Icons.swap_vert_rounded,
              size: 22,
            ),
            color: _isEditingImages
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
            tooltip: _isEditingImages
                ? context.l10n.finishSorting
                : context.l10n.reorderImages,
            onPressed: () =>
                setState(() => _isEditingImages = !_isEditingImages),
          ),
        if (isOwner)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF64748B),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _editPost();
              }

              if (value == 'history') {
                context.push(
                  AppRoutes.postEditHistoryLocation(postId: widget.postId),
                );
              }

              if (value == 'delete') {
                _deletePost();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(context.l10n.editPost),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 8),
                    Text(context.l10n.postEditHistory),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text(
                      context.l10n.deletePost,
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (!isOwner && _currentUserId != null)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF64748B),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabled: !_isReportBusy,
            onSelected: (value) {
              if (value == 'report') {
                _reportPost();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      context.l10n.reportPost,
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ============================================================
  // 小红书风格图片查看器
  // ============================================================
  void _openImagePreview(int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) {
          return _XhsImagePreview(
            images: List<String>.unmodifiable(_images),
            initialIndex: initialIndex,
            postId: widget.postId,
          );
        },
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildImageViewer() {
    return AspectRatio(
      // 小红书常见的竖图展示比例。
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: _images.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openImagePreview(index),
                child: Hero(
                  tag: 'post-${widget.postId}-image-$index',
                  child: Material(
                    color: const Color(0xFFF2F2F2),
                    child: CachedNetworkImage(
                      imageUrl: _images[index],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (_, _) {
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF2442),
                          ),
                        );
                      },
                      errorWidget: (_, _, _) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: Color(0xFF9CA3AF),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          if (_images.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          if (_images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_images.length, (index) {
                  final selected = index == _currentIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: selected ? 13 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2),
                      ],
                    ),
                  );
                }),
              ),
            ),

          if (_isUploadingImage)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF2442)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 可拖拽排序的图片编辑列表
  // ============================================================
  Widget _buildEditableImageList() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.holdDragToReorder,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addImages,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: Text(
                  context.l10n.addMoreImages,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            onReorderItem: _reorderImages,
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              return Container(
                key: ValueKey(_images[index]),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _images[index],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          context.l10n.imageNumber('${index + 1}'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () => _showImageOptions(index),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Icon(
                            Icons.menu_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 帖子内容
  // ============================================================
  Widget _buildContent() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final title = _post.title?.trim() ?? '';
    final content = _post.content?.trim() ?? '';
    final userId = _post.userId ?? '';
    final category = _post.category ?? '';

    final primaryLanguageCode =
        _post.primaryLanguageCode ??
        widget.post.primaryLanguageCode ??
        widget.post.languageCode;

    final currentLanguageCode = _post.languageCode ?? primaryLanguageCode;

    final isPrimaryLanguage = currentLanguageCode == primaryLanguageCode;

    final publishedText = isPrimaryLanguage
        ? _formatTimestamp(_post.createdAt)
        : _currentVersionCreatedAt == null
        ? context.l10n.translationVersion
        : context.l10n.translationPublishedAt(
            _formatVersionTimestamp(_currentVersionCreatedAt!),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================
          // 标签
          // ==========================
          if (category.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '# $category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ==========================
          // 语言版本
          // ==========================
          _buildLanguageVersionSwitcher(),
          const SizedBox(height: 24),

          // ==========================
          // 标题
          // ==========================
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                height: 1.22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 22),
          ],

          // ==========================
          // 作者 + 版本信息
          // ==========================
          // ==========================
          // 作者
          // ==========================
          if (userId.isNotEmpty)
            UserNameDisplay(uid: userId),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    publishedText,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  if (_post.updatedAt != null &&
                      _post.updatedAt != _post.createdAt) ...[
                    const SizedBox(width: 8),

                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: colors.tertiary,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      context.l10n.modifiedAt(
                        _formatTimestamp(_post.updatedAt),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.tertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),

          const SizedBox(height: 26),

          // ==========================
          // 正文
          // ==========================
          if (_post.bodyDelta.isNotEmpty)
            _PostRichBody(
              key: ValueKey(
                '${_post.id}-'
                '${_post.languageCode}-'
                '${_post.bodyDelta.hashCode}',
              ),
              bodyDelta: _post.bodyDelta,
            )
          else
            Text(
              content.isNotEmpty ? content : context.l10n.noContent,
              style: TextStyle(
                fontSize: 16.5,
                height: 1.75,
                letterSpacing: 0.1,
                color: colors.onSurface.withValues(alpha: 0.90),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 底部操作栏
  // ============================================================
  Widget _buildBottomBar() {

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildBottomAction(
                  onTap: _toggleLike,
                  child: _buildAction(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    _likeCount > 0
                        ? '$_likeCount ${context.l10n.like}'
                        : context.l10n.like,
                    _isLiked,
                  ),
                ),
              ),
              Expanded(
                child: _buildBottomAction(
                  onTap: _openComments,
                  child: _buildAction(
                    Icons.mode_comment_outlined,
                    context.l10n.comment,
                    false,
                  ),
                ),
              ),
              Expanded(
                child: _buildBottomAction(
                  onTap: _showShareOptions,
                  child: _buildAction(
                    Icons.ios_share_rounded,
                    context.l10n.share,
                    false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String text, bool active) {
    final colors = Theme.of(context).colorScheme;

    final activeColor = colors.primary;
    final inactiveColor = colors.onSurfaceVariant;

    final color = active ? activeColor : inactiveColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(height: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1,
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageVersionSwitcher() {
  final languages = _availableLanguageVersions;

  if (languages.isEmpty) {
    return const SizedBox.shrink();
  }

  final colors = Theme.of(context).colorScheme;

  final currentLanguageCode =
      _post.languageCode ?? _post.primaryLanguageCode;

  final primaryLanguageCode =
      _post.primaryLanguageCode;

  final uiLanguageCode =
      Localizations.localeOf(context).languageCode;

  // ==========================
  // 排序：
  // 当前语言 -> 主语言 -> 其他语言
  // ==========================
  final orderedLanguages = <LanguageConfig>[];

  void addLanguage(String? code) {
    if (code == null) return;

    for (final language in languages) {
      if (language.code == code &&
          !orderedLanguages.any(
            (item) => item.code == code,
          )) {
        orderedLanguages.add(language);
        return;
      }
    }
  }

  addLanguage(currentLanguageCode);
  addLanguage(primaryLanguageCode);

  for (final language in languages) {
    if (!orderedLanguages.any(
      (item) => item.code == language.code,
    )) {
      orderedLanguages.add(language);
    }
  }

  Widget languageChip(LanguageConfig language) {
    final selected =
        language.code == currentLanguageCode;

    final isPrimary =
        language.code == primaryLanguageCode;

    final name = language.nameOf(uiLanguageCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!selected) {
            _switchLanguageVersion(language);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],

              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : colors.onSurface,
                ),
              ),

              if (isPrimary) ...[
                const SizedBox(width: 7),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(
                            alpha: 0.18,
                          )
                        : colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.mainLanguage,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: colors.outlineVariant.withValues(
          alpha: 0.55,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================
        // 顶部：全部语言 + 翻译
        // ==========================
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(10),
                  onTap: _showLanguageVersionsSheet,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 19,
                          color:
                              colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),

                        Flexible(
                          child: Text(
                            context.l10n.selectLanguage,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors
                                .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${languages.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),

                        const SizedBox(width: 2),

                        Icon(
                          Icons
                              .keyboard_arrow_down_rounded,
                          size: 18,
                          color:
                              colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            FilledButton.tonalIcon(
              onPressed: _openTranslation,
              icon: const Icon(
                Icons.translate_rounded,
                size: 17,
              ),
              label: Text(
                context.l10n.translate,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ==========================
        // 所有语言版本：只横向滑
        // ==========================
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount: orderedLanguages.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return languageChip(
                orderedLanguages[index],
              );
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> _showLanguageVersionsSheet() async {
  final languages = _availableLanguageVersions;

  final currentLanguageCode =
      _post.languageCode ?? _post.primaryLanguageCode;

  final primaryLanguageCode =
      _post.primaryLanguageCode;

  final uiLanguageCode =
      Localizations.localeOf(context).languageCode;

  String query = '';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery =
              query.trim().toLowerCase();

          final filtered = languages.where(
            (language) {
              final name = language
                  .nameOf(uiLanguageCode)
                  .toLowerCase();

              return normalizedQuery.isEmpty ||
                  name.contains(normalizedQuery) ||
                  language.code
                      .toLowerCase()
                      .contains(normalizedQuery);
            },
          ).toList();

          return SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.sizeOf(context).height *
                      0.72,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n
                                .selectLanguage,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                        ),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                          child: Text(
                            '${languages.length}',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setSheetState(() {
                          query = value;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                        ),
                        hintText:
                            context.l10n.selectLanguage,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder:
                          (context, index) {
                        final language =
                            filtered[index];

                        final selected =
                            language.code ==
                                currentLanguageCode;

                        final isPrimary =
                            language.code ==
                                primaryLanguageCode;

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment:
                                Alignment.center,
                            decoration:
                                BoxDecoration(
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(
                                10,
                              ),
                            ),
                            child: Icon(
                              selected
                                  ? Icons
                                      .check_rounded
                                  : Icons
                                      .language_rounded,
                              size: 19,
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),

                          title: Text(
                            language.nameOf(
                              uiLanguageCode,
                            ),
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),

                          subtitle: isPrimary
                              ? Text(
                                  context
                                      .l10n.mainLanguage,
                                )
                              : null,

                          trailing: selected
                              ? Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color: Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .primary,
                                )
                              : null,

                          onTap: () {
                            Navigator.pop(
                              sheetContext,
                            );

                            if (!selected) {
                              _switchLanguageVersion(
                                language,
                              );
                            }
                          },
                        );
                      },
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
}


}

class _PostRichBody extends StatefulWidget {
  final List<dynamic> bodyDelta;

  const _PostRichBody({super.key, required this.bodyDelta});

  @override
  State<_PostRichBody> createState() => _PostRichBodyState();
}

class _PostRichBodyState extends State<_PostRichBody> {
  late final quill.QuillController _controller;

  @override
  void initState() {
    super.initState();

    final document = quill.Document.fromJson(widget.bodyDelta);

    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return quill.QuillEditor.basic(
      controller: _controller,
      config: quill.QuillEditorConfig(
        scrollable: false,
        padding: EdgeInsets.zero,
        showCursor: false,
        autoFocus: false,
        embedBuilders: kIsWeb
            ? FlutterQuillEmbeds.editorWebBuilders()
            : FlutterQuillEmbeds.editorBuilders(),
      ),
    );
  }
}

class _PostEditResult {
  final String title;
  final String content;
  final List<dynamic> bodyDelta;
  final List<String> imageUrls;

  const _PostEditResult({
    required this.title,
    required this.content,
    required this.bodyDelta,
    required this.imageUrls,
  });
}

class _PostRichEditPage extends StatefulWidget {
  final String postId;
  final String languageCode;
  final String title;
  final String content;
  final List<dynamic> bodyDelta;
  final List<String> imageUrls;

  const _PostRichEditPage({
    required this.postId,
    required this.languageCode,
    required this.title,
    required this.content,
    required this.bodyDelta,
    required this.imageUrls,
  });

  @override
  State<_PostRichEditPage> createState() => _PostRichEditPageState();
}

class _PostRichEditPageState extends State<_PostRichEditPage> {
  late final TextEditingController _titleController;
  late final quill.QuillController _controller;
  late final PostRepository _postRepository;
  late final PostMediaRepository _mediaRepository;

  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _uploadingImage = false;
  bool _saving = false;
  bool _didSave = false;
  late List<String> _topImages;
  late final List<String> _originalTopImages;

  final List<String> _newTopImageUrls = [];
  final List<String> _newInlineImageUrls = [];

  @override
  void initState() {
    super.initState();

    _postRepository = context.read<PostRepository>();
    _mediaRepository = context.read<PostMediaRepository>();
    _titleController = TextEditingController(text: widget.title);

    final document = widget.bodyDelta.isNotEmpty
        ? quill.Document.fromJson(widget.bodyDelta)
        : quill.Document.fromJson([
            {'insert': '${widget.content}\n'},
          ]);

    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _originalTopImages = List<String>.from(widget.imageUrls);
    _topImages = List<String>.from(widget.imageUrls);
  }

  int _countInlineImages() {
    final delta = _controller.document.toDelta().toJson();

    return delta.where((operation) {
      final insert = operation['insert'];
      return insert is Map && insert.containsKey('image');
    }).length;
  }

  int get _totalImageCount {
    return _topImages.length + _countInlineImages();
  }

  Future<void> _addTopImages() async {
    if (_uploadingImage || _saving) {
      return;
    }

    final remaining = 9 - _totalImageCount;

    if (remaining <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.postImageLimit)));
      return;
    }

    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked.isEmpty) {
      return;
    }

    final selected = picked.take(remaining).toList();

    setState(() {
      _uploadingImage = true;
    });

    try {
      for (final image in selected) {
        final url = await _mediaRepository.uploadTopImage(
          widget.postId,
          LocalPostImage(path: image.path, name: image.name),
        );

        _newTopImageUrls.add(url);

        if (!mounted) return;

        setState(() {
          _topImages.add(url);
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.updateFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  void _removeTopImage(int index) {
    if (_saving) {
      return;
    }

    setState(() {
      _topImages.removeAt(index);
    });
  }

  void _reorderTopImages(int oldIndex, int newIndex) {
    if (_saving) {
      return;
    }

    setState(() {
      final image = _topImages.removeAt(oldIndex);
      _topImages.insert(newIndex, image);
    });
  }

  Future<void> _insertImage() async {
    if (_uploadingImage || _saving) {
      return;
    }

    if (_totalImageCount >= 9) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.postImageLimit)));
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });

    try {
      final imageUrl = await _mediaRepository.uploadInlineImage(
        widget.postId,
        LocalPostImage(path: image.path, name: image.name),
      );
      _newInlineImageUrls.add(imageUrl);
      final documentLength = _controller.document.length;
      final maximumPosition = documentLength > 0 ? documentLength - 1 : 0;
      final selection = _controller.selection;
      final rawPosition = selection.isValid
          ? selection.baseOffset
          : maximumPosition;
      final insertPosition = rawPosition.clamp(0, maximumPosition).toInt();

      _controller.replaceText(
        insertPosition,
        0,
        quill.BlockEmbed.image(imageUrl),
        TextSelection.collapsed(offset: insertPosition + 1),
      );

      _controller.replaceText(
        insertPosition + 1,
        0,
        '\n',
        TextSelection.collapsed(offset: insertPosition + 2),
      );

      _controller.updateSelection(
        TextSelection.collapsed(offset: insertPosition + 2),
        quill.ChangeSource.local,
      );

      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.updateFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _uploadingImage) {
      return;
    }

    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.titleRequired)));
      return;
    }

    final content = _controller.document.toPlainText().trim();
    final bodyDelta = _controller.document.toDelta().toJson();

    if (content.isEmpty && !_hasImage(bodyDelta)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.contentRequired)));
      return;
    }

    final cleanupPlan = PostEditMediaCleanupPlan.fromEdit(
      originalTopImageUrls: _originalTopImages,
      originalBodyDelta: widget.bodyDelta,
      currentTopImageUrls: _topImages,
      currentBodyDelta: bodyDelta,
      newUploadUrls: [..._newTopImageUrls, ..._newInlineImageUrls],
    );

    setState(() {
      _saving = true;
    });

    try {
      // 保存发生在编辑页内。失败时页面不会被关闭，因此用户可以重试，
      // 新上传的媒体也不会被误删。
      await _postRepository.updateLanguageVersionContent(
        postId: widget.postId,
        languageCode: widget.languageCode,
        title: title,
        content: content,
        bodyDelta: bodyDelta,
        imageUrls: List<String>.from(_topImages),
      );

      _didSave = true;

      for (final imageUrl in cleanupPlan.cleanupAfterSaveUrls) {
        try {
          await _mediaRepository.deleteImage(imageUrl);
        } catch (error) {
          debugPrint('清理帖子编辑媒体失败: $error');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      Navigator.pop(
        context,
        _PostEditResult(
          title: title,
          content: content,
          bodyDelta: bodyDelta,
          imageUrls: List<String>.from(_topImages),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.updateFailed}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _hasImage(List<dynamic> delta) {
    for (final operation in delta) {
      if (operation is! Map) {
        continue;
      }

      final insert = operation['insert'];

      if (insert is Map && insert.containsKey('image')) {
        return true;
      }
    }

    return false;
  }

  void _cleanupNewUploadsAfterCancel() {
    final urls = <String>{..._newTopImageUrls, ..._newInlineImageUrls};

    for (final imageUrl in urls) {
      _mediaRepository.deleteImage(imageUrl).catchError((Object error) {
        debugPrint('清理已取消的帖子编辑媒体失败: $error');
      });
    }
  }

  @override
  void dispose() {
    // 正常取消编辑时，没有任何数据库引用这些本次上传的媒体，可以安全清理。
    // 保存进行中则不抢先删除，避免网络响应不确定时误删可能已提交的对象。
    if (!_didSave && !_saving) {
      _cleanupNewUploadsAfterCancel();
    }

    _titleController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.editPost),
          actions: [
            TextButton(
              onPressed: _uploadingImage || _saving ? null : _save,
              child: Text(_saving ? context.l10n.saving : context.l10n.save),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_uploadingImage || _saving) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _titleController,
                maxLength: 100,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: context.l10n.title,
                  hintText: context.l10n.postTitleHint,
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.topImages,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_topImages.length}/9',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed:
                            _uploadingImage || _saving || _totalImageCount >= 9
                            ? null
                            : _addTopImages,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.add),
                      ),
                    ],
                  ),
                  if (_topImages.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        context.l10n.noTopImages,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    SizedBox(
                      height: 112,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        itemCount: _topImages.length,
                        onReorderItem: _reorderTopImages,
                        itemBuilder: (context, index) {
                          final imageUrl = _topImages[index];

                          return Container(
                            key: ValueKey(imageUrl),
                            width: 104,
                            margin: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _saving
                                        ? null
                                        : () {
                                            _removeTopImage(index);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    enabled: !_saving,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: _saving,
                child: quill.QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: quill.QuillEditorConfig(
                    padding: const EdgeInsets.all(16),
                    placeholder: context.l10n.postContentHint,
                    embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_uploadingImage)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(context.l10n.uploadingInlineImage),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: context.l10n.insertImage,
                        onPressed: _uploadingImage || _saving
                            ? null
                            : _insertImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: IgnorePointer(
                            ignoring: _saving,
                            child: quill.QuillSimpleToolbar(
                              controller: _controller,
                              config: const quill.QuillSimpleToolbarConfig(
                                multiRowsDisplay: false,
                                showFontFamily: false,
                                showFontSize: false,
                                showBoldButton: true,
                                showItalicButton: true,
                                showUnderLineButton: true,
                                showStrikeThrough: false,
                                showColorButton: false,
                                showBackgroundColorButton: false,
                                showClearFormat: true,
                                showAlignmentButtons: false,
                                showHeaderStyle: true,
                                showListNumbers: true,
                                showListBullets: true,
                                showListCheck: true,
                                showCodeBlock: false,
                                showQuote: true,
                                showIndent: false,
                                showLink: false,
                                showUndo: true,
                                showRedo: true,
                                showSearchButton: false,
                                showSubscript: false,
                                showSuperscript: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XhsImagePreview extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String postId;

  const _XhsImagePreview({
    required this.images,
    required this.initialIndex,
    required this.postId,
  });

  @override
  State<_XhsImagePreview> createState() => _XhsImagePreviewState();
}

class _XhsImagePreviewState extends State<_XhsImagePreview> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _showControls = !_showControls);
                },
                child: Center(
                  child: Hero(
                    tag: 'post-${widget.postId}-image-$index',
                    child: Material(
                      color: Colors.transparent,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        boundaryMargin: const EdgeInsets.all(80),
                        clipBehavior: Clip.none,
                        child: CachedNetworkImage(
                          imageUrl: widget.images[index],
                          width: MediaQuery.sizeOf(context).width,
                          height: MediaQuery.sizeOf(context).height,
                          fit: BoxFit.contain,
                          placeholder: (_, _) {
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            );
                          },
                          errorWidget: (_, _, _) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 64,
                                color: Colors.white38,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.l10n.close,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (index) {
                          final selected = index == _currentIndex;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: selected ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
