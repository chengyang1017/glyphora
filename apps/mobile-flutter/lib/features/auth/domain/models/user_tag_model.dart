class UserTagTranslationModel {
  final String languageCode;
  final String scriptCode;
  final String value;

  const UserTagTranslationModel({
    required this.languageCode,
    this.scriptCode = '',
    required this.value,
  });

  factory UserTagTranslationModel.fromMap(Map<String, dynamic> map) {
    return UserTagTranslationModel(
      languageCode: map['languageCode']?.toString().trim() ?? '',
      scriptCode: map['scriptCode']?.toString().trim() ?? '',
      value: map['value']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageCode': languageCode,
      'scriptCode': scriptCode,
      'value': value,
    };
  }
}

class UserTagModel {
  final String? id;

  /// 使用者真正輸入的原始標籤。
  final String value;

  /// 原始標籤的語言。
  final String languageCode;

  /// 原始標籤使用的文字系統。
  final String scriptCode;

  /// 標籤作者自己提供的正式翻譯。
  final List<UserTagTranslationModel> translations;

  const UserTagModel({
    this.id,
    required this.value,
    this.languageCode = '',
    this.scriptCode = '',
    this.translations = const [],
  });

  factory UserTagModel.fromMap(Map<String, dynamic> map) {
    final rawTranslations = map['translations'];

    final parsedTranslations = rawTranslations is List
        ? rawTranslations
              .whereType<Map>()
              .map(
                (item) => UserTagTranslationModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (item) => item.languageCode.isNotEmpty && item.value.isNotEmpty,
              )
              .toList(growable: false)
        : const <UserTagTranslationModel>[];

    return UserTagModel(
      id: map['id']?.toString(),
      value: map['value']?.toString().trim() ?? '',
      languageCode: map['languageCode']?.toString().trim() ?? '',
      scriptCode: map['scriptCode']?.toString().trim() ?? '',
      translations: parsedTranslations,
    );
  }

  Map<String, dynamic> toApiMap() {
    return {
      'value': value,
      'languageCode': languageCode,
      'scriptCode': scriptCode,
      'translations': translations
          .map((item) => item.toMap())
          .toList(growable: false),
    };
  }

  /// 作者翻譯顯示優先級：
  ///
  /// 1. 完全匹配 language + script
  /// 2. 同語言、無 script
  /// 3. 該語言只有一個翻譯
  /// 4. 原文
  String displayFor({required String languageCode, String scriptCode = ''}) {
    final targetLanguage = languageCode.trim().toLowerCase();

    final targetScript = scriptCode.trim().toLowerCase();

    if (targetLanguage.isEmpty) {
      return value;
    }

    // 1. 完全匹配語言 + 文字系統
    if (targetScript.isNotEmpty) {
      for (final translation in translations) {
        if (translation.languageCode.trim().toLowerCase() == targetLanguage &&
            translation.scriptCode.trim().toLowerCase() == targetScript) {
          return translation.value;
        }
      }
    }

    // 2. 同語言，沒有指定文字系統
    for (final translation in translations) {
      if (translation.languageCode.trim().toLowerCase() == targetLanguage &&
          translation.scriptCode.trim().isEmpty) {
        return translation.value;
      }
    }

    // 3. 這個語言只有一種翻譯時直接使用
    final sameLanguage = translations
        .where(
          (translation) =>
              translation.languageCode.trim().toLowerCase() == targetLanguage,
        )
        .toList(growable: false);

    if (sameLanguage.length == 1) {
      return sameLanguage.first.value;
    }

    // 4. 作者沒有翻譯 → 原文
    return value;
  }
}
