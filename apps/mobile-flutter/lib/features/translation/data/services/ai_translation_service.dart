import '../../../../core/network/api_client.dart';

class AiTranslationResult {
  final String title;
  final String content;

  const AiTranslationResult({required this.title, required this.content});
}

class ProfileTagTranslationResult {
  final String original;
  final String translated;

  const ProfileTagTranslationResult({
    required this.original,
    required this.translated,
  });
}

class AiTranslationService {
  AiTranslationService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AiTranslationResult> translatePost({
    required String title,
    required String content,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    final data = await _apiClient.post(
      '/translations/posts',
      data: {
        'title': title,
        'content': content,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'targetLanguageName': targetLanguageName,
      },
    );

    return AiTranslationResult(
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
    );
  }

  Future<List<ProfileTagTranslationResult>> translateProfileTags({
    required String profileUserId,
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    if (profileUserId.trim().isEmpty) {
      return const <ProfileTagTranslationResult>[];
    }

    final data = await _apiClient.post(
      '/translations/profile-tags',
      data: {
        'profileUserId': profileUserId.trim(),

        'targetLanguageCode': targetLanguageCode,

        'targetLanguageName': targetLanguageName,
      },
    );

    final rawTranslations = data['translations'];

    if (rawTranslations is! List) {
      return const <ProfileTagTranslationResult>[];
    }

    return rawTranslations
        .whereType<Map>()
        .map(
          (item) => ProfileTagTranslationResult(
            original: item['original']?.toString().trim() ?? '',
            translated: item['translated']?.toString().trim() ?? '',
          ),
        )
        .where((item) => item.original.isNotEmpty)
        .toList(growable: false);
  }
}
