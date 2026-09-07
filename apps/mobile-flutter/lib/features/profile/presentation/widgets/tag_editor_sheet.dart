import 'package:flutter/material.dart';
import 'package:glyphora_language_core/glyphora_language_core.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/domain/models/user_tag_model.dart';

Future<List<UserTagModel>?> showTagEditorSheet({
  required BuildContext context,
  required List<UserTagModel> selectedTags,
  required List<String> presetTags,
}) {
  return showModalBottomSheet<List<UserTagModel>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _TagEditorSheet(
        selectedTags: selectedTags,
        presetTags: presetTags,
      );
    },
  );
}

class _TagEditorSheet extends StatefulWidget {
  final List<UserTagModel> selectedTags;
  final List<String> presetTags;

  const _TagEditorSheet({required this.selectedTags, required this.presetTags});

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  final TextEditingController _customController = TextEditingController();

  late final List<UserTagModel> _selected;

  @override
  void initState() {
    super.initState();

    _selected = List<UserTagModel>.from(widget.selectedTags);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool _containsValue(String value) {
    final normalized = value.trim().toLowerCase();

    return _selected.any((tag) => tag.value.trim().toLowerCase() == normalized);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _addCustomTag() async {
    final value = _customController.text.trim();

    if (value.isEmpty) {
      return;
    }

    if (_containsValue(value)) {
      _showMessage(context.l10n.tagExists);
      return;
    }

    if (_selected.length >= 10) {
      _showMessage(context.l10n.tagMax);
      return;
    }

    final result = await _openTagDetailEditor(UserTagModel(value: value));

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selected.add(result);
      _customController.clear();
    });
  }

  Future<void> _editTag(int index) async {
    final result = await _openTagDetailEditor(_selected[index]);

    if (!mounted || result == null) {
      return;
    }

    final duplicated = _selected.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.value.trim().toLowerCase() ==
              result.value.trim().toLowerCase(),
    );

    if (duplicated) {
      _showMessage(context.l10n.tagExists);
      return;
    }

    setState(() {
      _selected[index] = result;
    });
  }

  void _togglePreset(String value) {
    final index = _selected.indexWhere(
      (tag) => tag.value.trim().toLowerCase() == value.trim().toLowerCase(),
    );

    if (index >= 0) {
      setState(() {
        _selected.removeAt(index);
      });

      return;
    }

    if (_selected.length >= 10) {
      _showMessage(context.l10n.tagMax);
      return;
    }

    setState(() {
      _selected.add(UserTagModel(value: value));
    });
  }

  Future<UserTagModel?> _openTagDetailEditor(UserTagModel tag) {
    return showModalBottomSheet<UserTagModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return _TagDetailEditor(tag: tag);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.editTagsTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, List<UserTagModel>.from(_selected));
                },
                child: Text(context.l10n.done),
              ),
            ],
          ),

          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              context.l10n.selectedTagsCount('${_selected.length}'),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selected.asMap().entries.map((entry) {
                final index = entry.key;
                final tag = entry.value;

                return InputChip(
                  label: Text(tag.value),
                  avatar: tag.translations.isNotEmpty
                      ? const Icon(Icons.translate_rounded, size: 15)
                      : null,
                  onPressed: () => _editTag(index),
                  onDeleted: () {
                    setState(() {
                      _selected.removeAt(index);
                    });
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    hintText: context.l10n.customTagHint,
                    counterText: '',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCustomTag(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _addCustomTag,
                child: Text(context.l10n.add),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Divider(color: colors.outlineVariant),

          const SizedBox(height: 12),

          Text(
            context.l10n.recommendTags,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.presetTags.map((value) {
                  final selected = _containsValue(value);

                  return FilterChip(
                    label: Text(value),
                    selected: selected,
                    onSelected: (_) => _togglePreset(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagDetailEditor extends StatefulWidget {
  final UserTagModel tag;

  const _TagDetailEditor({required this.tag});

  @override
  State<_TagDetailEditor> createState() => _TagDetailEditorState();
}

class _TagDetailEditorState extends State<_TagDetailEditor> {
  late final TextEditingController _valueController;

  late String _languageCode;
  late String _scriptCode;

  late List<UserTagTranslationModel> _translations;

  @override
  void initState() {
    super.initState();

    _valueController = TextEditingController(text: widget.tag.value);

    _languageCode = widget.tag.languageCode;

    _scriptCode = widget.tag.scriptCode;

    _translations = List<UserTagTranslationModel>.from(widget.tag.translations);
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String _languageName(String code) {
    if (code.isEmpty) {
      return '—';
    }

    final language = LanguageConfig.findByCode(code);

    if (language == null) {
      return code;
    }

    final uiLanguage = Localizations.localeOf(context).languageCode;

    return language.nameOf(uiLanguage);
  }

  String _scriptName(String code) {
    if (code.isEmpty) {
      return '—';
    }

    final script = ScriptConfig.findByCode(code);

    if (script == null) {
      return code;
    }

    final uiLanguage = Localizations.localeOf(context).languageCode;

    return script.nameOf(uiLanguage);
  }

  Future<void> _selectOriginalLanguage() async {
    final result = await _selectLanguageAndScript(
      languageCode: _languageCode,
      scriptCode: _scriptCode,
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _languageCode = result.languageCode;

      _scriptCode = result.scriptCode;
    });
  }

  Future<void> _addTranslation() async {
    final result = await _editTranslation();

    if (!mounted || result == null) {
      return;
    }

    final duplicateIndex = _translations.indexWhere(
      (item) =>
          item.languageCode.toLowerCase() ==
              result.languageCode.toLowerCase() &&
          item.scriptCode.toLowerCase() == result.scriptCode.toLowerCase(),
    );

    setState(() {
      if (duplicateIndex >= 0) {
        _translations[duplicateIndex] = result;
      } else {
        _translations.add(result);
      }
    });
  }

  Future<void> _editExistingTranslation(int index) async {
    final result = await _editTranslation(existing: _translations[index]);

    if (!mounted || result == null) {
      return;
    }

    final duplicateIndex = _translations.indexWhere(
      (item) =>
          item.languageCode.toLowerCase() ==
              result.languageCode.toLowerCase() &&
          item.scriptCode.toLowerCase() == result.scriptCode.toLowerCase(),
    );

    if (duplicateIndex >= 0 && duplicateIndex != index) {
      setState(() {
        _translations.removeAt(index);

        _translations[duplicateIndex > index
                ? duplicateIndex - 1
                : duplicateIndex] =
            result;
      });

      return;
    }

    setState(() {
      _translations[index] = result;
    });
  }

  Future<UserTagTranslationModel?> _editTranslation({
    UserTagTranslationModel? existing,
  }) async {
    final selected = await _selectLanguageAndScript(
      languageCode: existing?.languageCode ?? '',
      scriptCode: existing?.scriptCode ?? '',
    );

    if (!mounted || selected == null) {
      return null;
    }

    final controller = TextEditingController(text: existing?.value ?? '');

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${_languageName(selected.languageCode)}'
            '${selected.scriptCode.isEmpty ? '' : ' · ${_scriptName(selected.scriptCode)}'}',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: context.l10n.tagTranslationValue,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, text);
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return UserTagTranslationModel(
      languageCode: selected.languageCode,
      scriptCode: selected.scriptCode,
      value: value.trim(),
    );
  }

  Future<_LanguageScriptSelection?> _selectLanguageAndScript({
    required String languageCode,
    required String scriptCode,
  }) {
    return showModalBottomSheet<_LanguageScriptSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return _LanguageScriptPicker(
          initialLanguageCode: languageCode,
          initialScriptCode: scriptCode,
        );
      },
    );
  }

  void _save() {
    final value = _valueController.text.trim();

    if (value.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      UserTagModel(
        id: widget.tag.id,
        value: value,
        languageCode: _languageCode,
        scriptCode: _scriptCode,
        translations: List<UserTagTranslationModel>.from(_translations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.editTagsTitle,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: _save, child: Text(context.l10n.save)),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _valueController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: context.l10n.customTagHint,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.tagOriginalLanguage),
              subtitle: Text(
                _languageCode.isEmpty
                    ? context.l10n.tagLanguageNotSpecified
                    : '${_languageName(_languageCode)}'
                          '${_scriptCode.isEmpty ? '' : ' · ${_scriptName(_scriptCode)}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectOriginalLanguage,
            ),

            Divider(color: colors.outlineVariant),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.tagTranslations,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addTranslation,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.tagAddTranslation),
                ),
              ],
            ),

            if (_translations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.l10n.tagNoTranslations,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),

            ..._translations.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.translate_rounded),
                title: Text(item.value),
                subtitle: Text(
                  '${_languageName(item.languageCode)}'
                  '${item.scriptCode.isEmpty ? '' : ' · ${_scriptName(item.scriptCode)}'}',
                ),
                onTap: () => _editExistingTranslation(index),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _translations.removeAt(index);
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LanguageScriptSelection {
  final String languageCode;
  final String scriptCode;

  const _LanguageScriptSelection({
    required this.languageCode,
    required this.scriptCode,
  });
}

class _LanguageScriptPicker extends StatefulWidget {
  final String initialLanguageCode;
  final String initialScriptCode;

  const _LanguageScriptPicker({
    required this.initialLanguageCode,
    required this.initialScriptCode,
  });

  @override
  State<_LanguageScriptPicker> createState() => _LanguageScriptPickerState();
}

class _LanguageScriptPickerState extends State<_LanguageScriptPicker> {
  final TextEditingController _searchController = TextEditingController();

  late final List<LanguageConfig> _languages;

  @override
  void initState() {
    super.initState();

    _languages = List<LanguageConfig>.from(LanguageConfig.allLanguages);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LanguageConfig> _filteredLanguages() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _languages;
    }

    return _languages.where((language) {
      if (language.code.toLowerCase().contains(query)) {
        return true;
      }

      return language.names.values.any(
        (name) => name.toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _selectLanguage(LanguageConfig language) async {
    final scripts = language.scriptCodes
        .map(ScriptConfig.findByCode)
        .whereType<ScriptConfig>()
        .toList(growable: false);

    if (scripts.isEmpty) {
      Navigator.pop(
        context,
        _LanguageScriptSelection(languageCode: language.code, scriptCode: ''),
      );

      return;
    }

    if (scripts.length == 1) {
      Navigator.pop(
        context,
        _LanguageScriptSelection(
          languageCode: language.code,
          scriptCode: scripts.first.code,
        ),
      );

      return;
    }

    final selectedScript = await showModalBottomSheet<ScriptConfig>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final uiLanguage = Localizations.localeOf(context).languageCode;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: scripts
                .map(
                  (script) => ListTile(
                    title: Text(script.nameOf(uiLanguage)),
                    subtitle: Text(script.code),
                    onTap: () => Navigator.pop(context, script),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (!mounted || selectedScript == null) {
      return;
    }

    Navigator.pop(
      context,
      _LanguageScriptSelection(
        languageCode: language.code,
        scriptCode: selectedScript.code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiLanguage = Localizations.localeOf(context).languageCode;

    final visible = _filteredLanguages();

    visible.sort(
      (a, b) => a.sortKeyOf(uiLanguage).compareTo(b.sortKeyOf(uiLanguage)),
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.searchLanguageNameOrCode,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final language = visible[index];

                return ListTile(
                  title: Text(language.nameOf(uiLanguage)),
                  subtitle: Text(language.code),
                  onTap: () => _selectLanguage(language),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
