class PostCommentModel {
  final String id;
  final String? userId;
  final String userName;
  final List<Map<String, dynamic>> localizedNames;
  final String? avatarUrl;
  final String text;
  final String? imageUrl;
  final String? replyTo;
  final DateTime? createdAt;
  final List<PostCommentModel> replies;

  const PostCommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.localizedNames,
    required this.avatarUrl,
    required this.text,
    required this.imageUrl,
    required this.replyTo,
    required this.createdAt,
    required this.replies,
  });

  PostCommentModel copyWith({List<PostCommentModel>? replies}) {
    return PostCommentModel(
      id: id,
      userId: userId,
      userName: userName,
      localizedNames: localizedNames,
      avatarUrl: avatarUrl,
      text: text,
      imageUrl: imageUrl,
      replyTo: replyTo,
      createdAt: createdAt,
      replies: replies ?? this.replies,
    );
  }

  String displayNameFor({
    required String languageCode,
    String scriptCode = '',
  }) {
    final normalizedLanguage =
        languageCode.trim().toLowerCase();

    final normalizedScript =
        scriptCode.trim().toLowerCase();

    if (normalizedScript.isNotEmpty) {
      for (final item in localizedNames) {
        final itemLanguage =
            item['languageCode']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final itemScript =
            item['scriptCode']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (itemLanguage == normalizedLanguage &&
            itemScript == normalizedScript) {
          final name =
              item['name']?.toString().trim() ?? '';

          if (name.isNotEmpty) {
            return name;
          }
        }
      }
    }

    // 喃字界面：没有 vi-Hani 名称时，优先回退到 vi-Latn。
    if (normalizedLanguage == 'vi' &&
        normalizedScript == 'hani') {
      for (final item in localizedNames) {
        final itemLanguage =
            item['languageCode']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final itemScript =
            item['scriptCode']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (itemLanguage == 'vi' &&
            itemScript == 'latn') {
          final name =
              item['name']?.toString().trim() ?? '';

          if (name.isNotEmpty) {
            return name;
          }
        }
      }
    }

    for (final item in localizedNames) {
      final itemLanguage =
          item['languageCode']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final itemScript =
          item['scriptCode']?.toString().trim() ?? '';

      if (itemLanguage == normalizedLanguage &&
          itemScript.isEmpty) {
        final name =
            item['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    final sameLanguageNames =
        localizedNames.where((item) {
      return item['languageCode']
              ?.toString()
              .trim()
              .toLowerCase() ==
          normalizedLanguage;
    }).toList(growable: false);

    if (sameLanguageNames.length == 1) {
      final name =
          sameLanguageNames.first['name']
                  ?.toString()
                  .trim() ??
              '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    return userName.trim().isNotEmpty
        ? userName.trim()
        : 'Guest';
  }

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'];
    final rawLocalizedNames = json['localizedNames'];

    final localizedNames = rawLocalizedNames is List
        ? rawLocalizedNames
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return PostCommentModel(
      id: json['id']?.toString() ?? '',
      userId: json['uid']?.toString(),
      userName: json['user']?.toString() ?? 'Guest',
      localizedNames: localizedNames,
      avatarUrl: json['avatarUrl']?.toString(),
      text: json['text']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      replyTo: json['replyTo']?.toString(),
      createdAt: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map(
                  (item) => PostCommentModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}
