class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? nickname;
  final String? avatar;
  final String? bio;
  final List<String>? friends;
  final List<String>? friendRequests;
  final List<String>? tags;
  final List<Map<String, dynamic>>? languages;
  final List<Map<String, dynamic>>? localizedNames;
  final DateTime? birthday;
  final bool showAge;
  final DateTime? createdAt;
  final DateTime? lastActive;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.displayName,
    this.photoUrl,
    this.nickname,
    this.avatar,
    this.bio,
    this.friends,
    this.friendRequests,
    this.tags,
    this.languages,
    this.localizedNames,
    this.birthday,
    this.showAge = true,
    this.createdAt,
    this.lastActive,
  });

  String get avatarUrl {
    final avatarValue = avatar ?? '';
    if (avatarValue.isNotEmpty) {
      return avatarValue;
    }
    return photoUrl ?? '';
  }

  String get profileDisplayName {
    final nicknameValue = nickname ?? '';
    if (nicknameValue.isNotEmpty) {
      return nicknameValue;
    }

    final displayNameValue = displayName ?? '';
    if (displayNameValue.isNotEmpty) {
      return displayNameValue;
    }

    return username;
  }

  String displayNameFor({
    required String languageCode,
    String scriptCode = '',
  }) {
    final names = localizedNames ?? const <Map<String, dynamic>>[];

    final normalizedLanguage = languageCode.trim().toLowerCase();

    final normalizedScript = scriptCode.trim().toLowerCase();

    // 1. 精确匹配：语言 + 文字系统
    if (normalizedScript.isNotEmpty) {
      for (final item in names) {
        final itemLanguage =
            item['languageCode']?.toString().trim().toLowerCase() ?? '';

        final itemScript =
            item['scriptCode']?.toString().trim().toLowerCase() ?? '';

        if (itemLanguage == normalizedLanguage &&
            itemScript == normalizedScript) {
          final name = item['name']?.toString().trim() ?? '';

          if (name.isNotEmpty) {
            return name;
          }
        }
      }
    }

    // 喃字界面：没有 vi-Hani 名称时，优先回退到越南语拉丁字母名称。
    if (normalizedLanguage == 'vi' && normalizedScript == 'hani') {
      for (final item in names) {
        final itemLanguage =
            item['languageCode']?.toString().trim().toLowerCase() ?? '';

        final itemScript =
            item['scriptCode']?.toString().trim().toLowerCase() ?? '';

        if (itemLanguage == 'vi' && itemScript == 'latn') {
          final name = item['name']?.toString().trim() ?? '';

          if (name.isNotEmpty) {
            return name;
          }
        }
      }
    }

    // 2. 同语言、没有指定文字系统
    for (final item in names) {
      final itemLanguage =
          item['languageCode']?.toString().trim().toLowerCase() ?? '';

      final itemScript = item['scriptCode']?.toString().trim() ?? '';

      if (itemLanguage == normalizedLanguage && itemScript.isEmpty) {
        final name = item['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    // 3. 当前语言只有一个名字时，可直接使用
    final sameLanguageNames = names
        .where((item) {
          return item['languageCode']?.toString().trim().toLowerCase() ==
              normalizedLanguage;
        })
        .toList(growable: false);

    if (sameLanguageNames.length == 1) {
      final name = sameLanguageNames.first['name']?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    // 4. 找不到就回退到主要昵称
    return profileDisplayName;
  }

  String get nicknameText => nickname ?? '';
  String get bioText => bio ?? '';
  List<String> get tagsList => tags ?? const <String>[];
  List<Map<String, dynamic>> get languageList =>
      languages ?? const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get localizedNameList =>
      localizedNames ?? const <Map<String, dynamic>>[];

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? photoUrl,
    String? nickname,
    String? avatar,
    String? bio,
    List<String>? friends,
    List<String>? friendRequests,
    List<String>? tags,
    List<Map<String, dynamic>>? languages,
    List<Map<String, dynamic>>? localizedNames,
    DateTime? birthday,
    bool clearBirthday = false,
    bool? showAge,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      tags: tags ?? this.tags,
      languages: languages ?? this.languages,
      localizedNames: localizedNames ?? this.localizedNames,
      birthday: clearBirthday ? null : birthday ?? this.birthday,
      showAge: showAge ?? this.showAge,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
