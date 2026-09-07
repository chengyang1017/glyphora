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

  static final Map<String, List<ProfileTagTranslationResult>>
      _profileTagCache = {};

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
    required List<String> tags,
    required String targetLanguageCode,
    required String targetLanguageName,
    String profileContext = '',
  }) async {
    if (tags.isEmpty) {
      return const <ProfileTagTranslationResult>[];
    }

    final cacheKey = [
      targetLanguageCode,
      targetLanguageName,
      profileContext,
      ...tags,
    ].join('\u001F');

    final cached = _profileTagCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final data = await _apiClient.post(
      '/translations/profile-tags',
      data: {
        'tags': tags,
        'targetLanguageCode': targetLanguageCode,
        'targetLanguageName': targetLanguageName,
        'profileContext': profileContext,
      },
    );

    final rawTranslations = data['translations'];

    if (rawTranslations is! List) {
      return tags
          .map(
            (tag) => ProfileTagTranslationResult(
              original: tag,
              translated: tag,
            ),
          )
          .toList(growable: false);
    }

    final results = rawTranslations
        .whereType<Map>()
        .map(
          (item) => ProfileTagTranslationResult(
            original: item['original']?.toString() ?? '',
            translated: item['translated']?.toString() ?? '',
          ),
        )
        .where((item) => item.original.isNotEmpty)
        .toList(growable: false);

    _profileTagCache[cacheKey] = results;

    return results;
  }
}
