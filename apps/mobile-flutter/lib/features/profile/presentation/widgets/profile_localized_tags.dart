import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/domain/models/user_tag_model.dart';
import '../../../translation/data/services/ai_translation_service.dart';

class ProfileLocalizedTags extends StatefulWidget {
  final String profileUserId;
  final List<UserTagModel> tags;
  final VoidCallback? onTap;
  final bool showAddButton;

  const ProfileLocalizedTags({
    super.key,
    required this.profileUserId,
    required this.tags,
    this.onTap,
    this.showAddButton = false,
  });

  @override
  State<ProfileLocalizedTags> createState() => _ProfileLocalizedTagsState();
}

class _ProfileLocalizedTagsState extends State<ProfileLocalizedTags> {
  final AiTranslationService _translationService = AiTranslationService();

  Map<String, String> _aiTranslations = const <String, String>{};

  bool _showAiTranslations = false;
  bool _isTranslating = false;

  String? _localeKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = Localizations.localeOf(context);

    final localeKey = locale.toLanguageTag();

    if (_localeKey != localeKey) {
      _localeKey = localeKey;

      _aiTranslations = const <String, String>{};

      _showAiTranslations = false;
      _isTranslating = false;
    }
  }

  @override
  void didUpdateWidget(covariant ProfileLocalizedTags oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profileUserId != widget.profileUserId ||
        !_sameTags(oldWidget.tags, widget.tags)) {
      _aiTranslations = const <String, String>{};

      _showAiTranslations = false;
      _isTranslating = false;
    }
  }

  bool _sameTags(List<UserTagModel> first, List<UserTagModel> second) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];

      if (a.id != b.id ||
          a.value != b.value ||
          a.languageCode != b.languageCode ||
          a.scriptCode != b.scriptCode) {
        return false;
      }

      if (a.translations.length != b.translations.length) {
        return false;
      }

      for (var j = 0; j < a.translations.length; j++) {
        final at = a.translations[j];

        final bt = b.translations[j];

        if (at.languageCode != bt.languageCode ||
            at.scriptCode != bt.scriptCode ||
            at.value != bt.value) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _toggleTranslation() async {
    if (_isTranslating) {
      return;
    }

    if (_showAiTranslations) {
      setState(() {
        _showAiTranslations = false;
      });

      return;
    }

    if (_aiTranslations.isNotEmpty) {
      setState(() {
        _showAiTranslations = true;
      });

      return;
    }

    await _translateForCurrentLocale();
  }

  Future<void> _translateForCurrentLocale() async {
    if (widget.tags.isEmpty || widget.profileUserId.trim().isEmpty) {
      return;
    }

    final locale = Localizations.localeOf(context);

    final l10n = AppLocalizations.of(context)!;

    final targetLanguageCode = locale.toLanguageTag();

    final targetLanguageName =
        locale.languageCode == 'vi' && locale.scriptCode == 'Hani'
        ? '${l10n.getLanguageName('vi')} · ${l10n.nomWritingSystem}'
        : l10n.getLanguageName(locale.languageCode);

    setState(() {
      _isTranslating = true;
    });

    try {
      final results = await _translationService.translateProfileTags(
        profileUserId: widget.profileUserId,

        targetLanguageCode: targetLanguageCode,

        targetLanguageName: targetLanguageName,
      );

      if (!mounted) {
        return;
      }

      final translations = <String, String>{};

      for (final result in results) {
        final original = result.original.trim();

        final translated = result.translated.trim();

        if (original.isEmpty || translated.isEmpty) {
          continue;
        }

        translations[original] = translated;
      }

      setState(() {
        _aiTranslations = translations;

        _showAiTranslations = true;
      });
    } catch (_) {
      // 翻译失败时继续显示作者版本 / 原文。
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tagBackgroundColor =
        isDark ? colors.outlineVariant : colors.primaryContainer;

    final tagForegroundColor =
        isDark ? colors.onSurface : colors.onPrimaryContainer;

    final locale = Localizations.localeOf(context);

    final l10n = AppLocalizations.of(context)!;

    final languageCode = locale.languageCode;

    final scriptCode = locale.scriptCode ?? '';

    final tagWidgets = widget.tags.map((tag) {
      // ------------------------------------------
      // 默认显示：
      //
      // 作者提供当前语言翻译
      // ↓
      // 没有就原文
      // ------------------------------------------

      final authorDisplay = tag.displayFor(
        languageCode: languageCode,

        scriptCode: scriptCode,
      );

      // ------------------------------------------
      // 观看者主动点 AI 后：
      //
      // AI / 后端缓存结果
      // ↓
      // 没结果继续作者版本
      // ------------------------------------------

      final aiDisplay = _aiTranslations[tag.value]?.trim();

      final display =
          _showAiTranslations && aiDisplay != null && aiDisplay.isNotEmpty
          ? aiDisplay
          : authorDisplay;

      final differsFromOriginal = display != tag.value;

      final chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tagBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (differsFromOriginal) ...[
              Icon(
                Icons.translate_rounded,
                size: 12,
                color: tagForegroundColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '# $display',
              style: TextStyle(
                fontSize: 12,
                color: tagForegroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

      if (!differsFromOriginal) {
        return chip;
      }

      return Tooltip(message: '# ${tag.value}', child: chip);
    }).toList();

    if (widget.showAddButton) {
      tagWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: tagBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.add, size: 14, color: tagForegroundColor),
        ),
      );
    }

    final wrap = Wrap(spacing: 8, runSpacing: 8, children: tagWidgets);

    final editableWrap = widget.onTap == null
        ? wrap
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            child: wrap,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        editableWrap,

        const SizedBox(height: 6),

        TextButton.icon(
          onPressed: _isTranslating ? null : _toggleTranslation,

          icon: _isTranslating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _showAiTranslations
                      ? Icons.restore_rounded
                      : Icons.translate_rounded,
                  size: 16,
                ),

          label: Text(
            _showAiTranslations ? l10n.showOriginalTags : l10n.translateTags,
          ),
        ),
      ],
    );
  }
}
