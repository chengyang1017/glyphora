import 'package:flutter/material.dart';
import 'package:glyphora_language_core/glyphora_language_core.dart';

class NicknameEditorResult {
  const NicknameEditorResult({
    required this.nickname,
    required this.localizedNames,
  });

  final String nickname;
  final List<Map<String, dynamic>> localizedNames;
}

Future<NicknameEditorResult?> showNicknameEditorSheet({
  required BuildContext context,
  required String nickname,
  required List<Map<String, dynamic>> localizedNames,
}) {
  return showModalBottomSheet<NicknameEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return _NicknameEditorSheet(
        nickname: nickname,
        localizedNames: localizedNames,
      );
    },
  );
}

class _NicknameEditorSheet extends StatefulWidget {
  const _NicknameEditorSheet({
    required this.nickname,
    required this.localizedNames,
  });

  final String nickname;
  final List<Map<String, dynamic>> localizedNames;

  @override
  State<_NicknameEditorSheet> createState() =>
      _NicknameEditorSheetState();
}

class _NicknameEditorSheetState
    extends State<_NicknameEditorSheet> {
  late final TextEditingController _nicknameController;

  late final List<Map<String, dynamic>> _localizedNames;

  String _uiLanguageCode = 'zh';

  @override
  void initState() {
    super.initState();

    _nicknameController = TextEditingController(
      text: widget.nickname,
    );

    _localizedNames = widget.localizedNames
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _uiLanguageCode =
        Localizations.localeOf(context).languageCode;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String _languageCodeOf(
    Map<String, dynamic> item,
  ) {
    return item['languageCode']
            ?.toString()
            .trim() ??
        '';
  }

  String _scriptCodeOf(
    Map<String, dynamic> item,
  ) {
    return item['scriptCode']
            ?.toString()
            .trim() ??
        '';
  }

  String _nameOf(
    Map<String, dynamic> item,
  ) {
    return item['name']
            ?.toString()
            .trim() ??
        '';
  }

  String _languageLabel(
    String languageCode,
  ) {
    final language =
        LanguageConfig.findByCode(languageCode);

    if (language == null) {
      return languageCode;
    }

    return language.nameOf(_uiLanguageCode);
  }

  String _scriptLabel(
    String scriptCode,
  ) {
    if (scriptCode.isEmpty) {
      return '';
    }

    final script =
        ScriptConfig.findByCode(scriptCode);

    if (script == null) {
      return scriptCode;
    }

    return script.nameOf(_uiLanguageCode);
  }

  Future<void> _addLocalizedName() async {
    final language =
        await _selectLanguage();

    if (!mounted || language == null) {
      return;
    }

    final scripts = language.scriptCodes
        .map(ScriptConfig.findByCode)
        .whereType<ScriptConfig>()
        .toList(growable: false);

    String scriptCode = '';

    if (scripts.length == 1) {
      scriptCode = scripts.first.code;
    } else if (scripts.length > 1) {
      final script =
          await _selectScript(
        language,
        scripts,
      );

      if (!mounted || script == null) {
        return;
      }

      scriptCode = script.code;
    }

    final existingIndex =
        _localizedNames.indexWhere((item) {
      return _languageCodeOf(item)
                  .toLowerCase() ==
              language.code.toLowerCase() &&
          _scriptCodeOf(item)
                  .toLowerCase() ==
              scriptCode.toLowerCase();
    });

    final existingName =
        existingIndex >= 0
            ? _nameOf(
                _localizedNames[
                    existingIndex],
              )
            : '';

    final name = await _editName(
      language: language,
      scriptCode: scriptCode,
      initialName: existingName,
    );

    if (!mounted || name == null) {
      return;
    }

    setState(() {
      final item = <String, dynamic>{
        'languageCode': language.code,
        'scriptCode': scriptCode,
        'name': name,
      };

      if (existingIndex >= 0) {
        _localizedNames[existingIndex] =
            item;
      } else {
        _localizedNames.add(item);
      }
    });
  }

  Future<LanguageConfig?>
  _selectLanguage() {
    return showModalBottomSheet<
        LanguageConfig>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final languages =
            List<LanguageConfig>.from(
          LanguageConfig.allLanguages,
        );

        languages.sort(
          (a, b) => a
              .sortKeyOf(_uiLanguageCode)
              .compareTo(
                b.sortKeyOf(
                  _uiLanguageCode,
                ),
              ),
        );

        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.sizeOf(
                      sheetContext,
                    ).height *
                    0.75,
            child: Column(
              children: [
                const Padding(
                  padding:
                      EdgeInsets.all(16),
                  child: Text(
                    '选择语言',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView.builder(
                    itemCount:
                        languages.length,
                    itemBuilder:
                        (context, index) {
                      final language =
                          languages[index];

                      return ListTile(
                        leading: Text(
                          language.flag,
                          style:
                              const TextStyle(
                            fontSize: 24,
                          ),
                        ),
                        title: Text(
                          language.nameOf(
                            _uiLanguageCode,
                          ),
                        ),
                        subtitle: Text(
                          language.code,
                        ),
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                            language,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ScriptConfig?> _selectScript(
    LanguageConfig language,
    List<ScriptConfig> scripts,
  ) {
    return showModalBottomSheet<
        ScriptConfig>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Text(
                  language.nameOf(
                    _uiLanguageCode,
                  ),
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              const Divider(height: 1),

              ...scripts.map(
                (script) => ListTile(
                  title: Text(
                    script.nameOf(
                      _uiLanguageCode,
                    ),
                  ),
                  subtitle:
                      Text(script.code),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      script,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _editName({
    required LanguageConfig language,
    required String scriptCode,
    required String initialName,
  }) async {
    final controller =
        TextEditingController(
      text: initialName,
    );

    final scriptLabel =
        _scriptLabel(scriptCode);

    final result =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            scriptLabel.isEmpty
                ? language.nameOf(
                    _uiLanguageCode,
                  )
                : '${language.nameOf(_uiLanguageCode)} · $scriptLabel',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration:
                const InputDecoration(
              labelText: '名称',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value =
                    controller.text
                        .trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child:
                  const Text('保存'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    return result;
  }

  Future<void> _editExisting(
    int index,
  ) async {
    final item =
        _localizedNames[index];

    final languageCode =
        _languageCodeOf(item);

    final language =
        LanguageConfig.findByCode(
      languageCode,
    );

    if (language == null) {
      return;
    }

    final scriptCode =
        _scriptCodeOf(item);

    final name = await _editName(
      language: language,
      scriptCode: scriptCode,
      initialName: _nameOf(item),
    );

    if (!mounted || name == null) {
      return;
    }

    setState(() {
      _localizedNames[index] = {
        ...item,
        'name': name,
      };
    });
  }

  void _removeLocalizedName(
    int index,
  ) {
    setState(() {
      _localizedNames.removeAt(index);
    });
  }

  void _save() {
    Navigator.pop(
      context,
      NicknameEditorResult(
        nickname:
            _nicknameController.text
                .trim(),
        localizedNames:
            _localizedNames
                .map(
                  (item) =>
                      Map<String, dynamic>
                          .from(item),
                )
                .toList(
                  growable: false,
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.viewInsetsOf(
                  context,
                ).bottom +
                20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '昵称',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  child:
                      const Text('保存'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller:
                  _nicknameController,
              maxLength: 100,
              decoration:
                  const InputDecoration(
                labelText: '主要昵称',
                helperText:
                    '没有对应语言名称时，将显示这个名称',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    '多语言名称',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _addLocalizedName,
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text('添加'),
                ),
              ],
            ),

            if (_localizedNames.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Text(
                  '还没有设置其他语言名称',
                ),
              )
            else
              ...List.generate(
                _localizedNames.length,
                (index) {
                  final item =
                      _localizedNames[
                          index];

                  final languageCode =
                      _languageCodeOf(
                    item,
                  );

                  final scriptCode =
                      _scriptCodeOf(
                    item,
                  );

                  final scriptLabel =
                      _scriptLabel(
                    scriptCode,
                  );

                  return ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    title: Text(
                      _nameOf(item),
                    ),
                    subtitle: Text(
                      scriptLabel.isEmpty
                          ? _languageLabel(
                              languageCode,
                            )
                          : '${_languageLabel(languageCode)} · $scriptLabel',
                    ),
                    onTap: () =>
                        _editExisting(
                      index,
                    ),
                    trailing:
                        IconButton(
                      icon: const Icon(
                        Icons
                            .delete_outline,
                      ),
                      onPressed: () =>
                          _removeLocalizedName(
                        index,
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}