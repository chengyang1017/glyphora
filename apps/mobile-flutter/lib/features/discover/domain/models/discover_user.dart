class DiscoverUser {
  const DiscoverUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    this.localizedNames = const <Map<String, dynamic>>[],
  });

  final String id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final List<Map<String, dynamic>> localizedNames;

  String get displayName =>
      nickname.isNotEmpty ? nickname : username;

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

    return displayName;
  }
}