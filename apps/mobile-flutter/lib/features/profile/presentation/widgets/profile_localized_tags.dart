import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../translation/data/services/ai_translation_service.dart';

class ProfileLocalizedTags extends StatefulWidget {
  final List<String> tags;
  final String profileContext;
  final VoidCallback? onTap;
  final bool showAddButton;

  const ProfileLocalizedTags({
    super.key,
    required this.tags,
    this.profileContext = '',
    this.onTap,
    this.showAddButton = false,
  });

  @override
  State<ProfileLocalizedTags> createState() => _ProfileLocalizedTagsState();
}

class _ProfileLocalizedTagsState extends State<ProfileLocalizedTags> {
  final AiTranslationService _translationService = AiTranslationService();

  Map<String, String> _translations = const <String, String>{};
  String? _requestKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleTranslation();
  }

  @override
  void didUpdateWidget(covariant ProfileLocalizedTags oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameTags(oldWidget.tags, widget.tags) ||
        oldWidget.profileContext != widget.profileContext) {
      _requestKey = null;
      _translations = const <String, String>{};
      _scheduleTranslation();
    }
  }

  bool _sameTags(List<String> first, List<String> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;

    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }

    return true;
  }

  void _scheduleTranslation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _translateForCurrentLocale();
      }
    });
  }

  Future<void> _translateForCurrentLocale() async {
    if (widget.tags.isEmpty) {
      return;
    }

    final locale = Localizations.localeOf(context);
    final targetLanguageCode = locale.toLanguageTag();
    final l10n = AppLocalizations.of(context)!;

    final targetLanguageName =
        locale.languageCode == 'vi' && locale.scriptCode == 'Hani'
        ? '${l10n.getLanguageName('vi')} · ${l10n.nomWritingSystem}'
        : l10n.getLanguageName(locale.languageCode);

    final requestKey = [
      targetLanguageCode,
      widget.profileContext,
      ...widget.tags,
    ].join('\u001F');

    if (_requestKey == requestKey) {
      return;
    }

    _requestKey = requestKey;

    try {
      final results = await _translationService.translateProfileTags(
        tags: widget.tags,
        targetLanguageCode: targetLanguageCode,
        targetLanguageName: targetLanguageName,
        profileContext: widget.profileContext,
      );

      if (!mounted || _requestKey != requestKey) {
        return;
      }

      final translations = <String, String>{};

      for (final result in results) {
        final translated = result.translated.trim();

        if (translated.isNotEmpty) {
          translations[result.original] = translated;
        }
      }

      setState(() {
        _translations = translations;
      });
    } catch (_) {
      // Translation is a display enhancement only. If it fails, keep the
      // user's original tag instead of turning profile loading into an error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final tagWidgets = widget.tags.map((tag) {
      final translated = _translations[tag]?.trim();
      final display = translated == null || translated.isEmpty
          ? tag
          : translated;
      final wasTranslated = display != tag;

      final chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.outlineVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wasTranslated) ...[
              Icon(
                Icons.translate_rounded,
                size: 12,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '# $display',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

      if (!wasTranslated) {
        return chip;
      }

      return Tooltip(
        message: '# $tag',
        child: chip,
      );
    }).toList();

    if (widget.showAddButton) {
      tagWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.outlineVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.add,
            size: 14,
            color: colors.onSurface,
          ),
        ),
      );
    }

    final wrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tagWidgets,
    );

    final onTap = widget.onTap;
    if (onTap == null) {
      return wrap;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: wrap,
    );
  }
}
