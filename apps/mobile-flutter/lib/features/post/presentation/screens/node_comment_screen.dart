import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../data/services/comment_api.dart';
import '../../domain/models/post_comment_model.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({super.key, required this.postId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final CommentApi _commentApi = CommentApi();

  List<PostCommentModel> _comments = const [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  String? _errorMessage;

  String? replyingToCommentId;
  String? replyingToUser;

  final List<String> _emojis = [
    '😀',
    '😂',
    '🤣',
    '😍',
    '🥰',
    '😘',
    '😜',
    '😎',
    '🤩',
    '🥳',
    '😢',
    '😡',
    '👍',
    '👎',
    '🙏',
    '💪',
    '🔥',
    '❤️',
    '💔',
    '🎉',
    '🌟',
    '💯',
    '✅',
    '❌',
  ];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final comments = await _commentApi.getComments(widget.postId);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _clearReplyState() {
    replyingToCommentId = null;
    replyingToUser = null;
  }

  String _displayNameOf(PostCommentModel comment) {
    final locale = Localizations.localeOf(context);

    return comment
        .displayNameFor(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode ?? '',
        )
        .trim();
  }

  void _showSendError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context)!.get('sendFailed')}: $error',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> sendComment() async {
    final text = controller.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final comment = await _commentApi.createComment(
        postId: widget.postId,
        text: text,
      );

      if (!mounted) return;

      setState(() {
        _comments = [comment, ..._comments];
        _clearReplyState();
      });

      controller.clear();
      focusNode.unfocus();
    } catch (error) {
      _showSendError(error);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> sendImageComment() async {
    if (_isUploading || _isSending) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'comment_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      final comment = await _commentApi.createComment(
        postId: widget.postId,
        imageUrl: url,
      );

      if (!mounted) return;

      setState(() {
        _comments = [comment, ..._comments];
        _clearReplyState();
      });
    } catch (error) {
      _showSendError(error);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> sendReply(String commentId) async {
    final text = controller.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final reply = await _commentApi.createReply(
        postId: widget.postId,
        commentId: commentId,
        text: text,
      );

      if (!mounted) return;

      setState(() {
        _comments = _comments
            .map(
              (comment) => comment.id == commentId
                  ? comment.copyWith(replies: [...comment.replies, reply])
                  : comment,
            )
            .toList(growable: false);

        _clearReplyState();
      });

      controller.clear();
      focusNode.unfocus();
    } catch (error) {
      _showSendError(error);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () {
                        controller.text += emoji;
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _avatar(PostCommentModel comment, {double radius = 18}) {
    final avatarUrl = comment.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }

    final name = _displayNameOf(comment);

    final first = name.isEmpty
        ? 'G'
        : name.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        first,
        style: TextStyle(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
          fontSize: radius <= 10 ? 10 : null,
        ),
      ),
    );
  }

  Widget buildReplies(PostCommentModel comment) {
    final replies = comment.replies;
    final parentDisplayName = _displayNameOf(comment);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (replies.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(left: 46, top: 4, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: replies.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final reply = replies[index];
            final replyDisplayName = _displayNameOf(reply);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(reply, radius: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: reply.imageUrl != null && reply.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: reply.imageUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: '$replyDisplayName ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (parentDisplayName.isNotEmpty) ...[
                                  TextSpan(
                                    text: '${l10n.reply} ',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '@$parentDisplayName ',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              TextSpan(text: reply.text),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.get('commentLoadFailed')}\n$_errorMessage',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadComments,
                child: Text(l10n.get('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadComments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.get('noCommentsYet'),
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _comments.length,
        itemBuilder: (context, index) {
          final comment = _comments[index];
          final imageUrl = comment.imageUrl;
          final commentDisplayName = _displayNameOf(comment);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(comment),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commentDisplayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Text(
                              comment.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          replyingToCommentId = comment.id;
                          replyingToUser = commentDisplayName;
                        });
                        focusNode.requestFocus();
                      },
                      child: Text(
                        l10n.reply,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                buildReplies(comment),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isUploading || _isSending;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => focusNode.unfocus(),
      child: Column(
        children: [
          Expanded(child: _buildCommentList()),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyingToUser != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 6,
                        right: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13),
                              children: [
                                TextSpan(
                                  text: '${l10n.reply} ',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                TextSpan(
                                  text: '@$replyingToUser',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(_clearReplyState),
                            child: Icon(
                              Icons.cancel,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 26,
                        ),
                        color: Colors.grey[600],
                        onPressed: _showEmojiPicker,
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined, size: 26),
                        color: Colors.grey[600],
                        onPressed: busy ? null : sendImageComment,
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: replyingToUser != null
                                ? l10n.get('replyHint')
                                : l10n.get('commentHint'),
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (busy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.send_rounded, size: 26),
                          color: Colors.blue,
                          onPressed: () {
                            final commentId = replyingToCommentId;

                            if (commentId == null) {
                              sendComment();
                            } else {
                              sendReply(commentId);
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
