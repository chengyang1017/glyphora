import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/forum_categories.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../discover/domain/models/discover_user.dart';
import '../../../discover/domain/repositories/discover_repository.dart';
import '../../../language/data/forum_languages.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/models/note_model.dart';
import '../../domain/repositories/note_repository.dart';

class AllNotesScreen extends StatefulWidget {
  const AllNotesScreen({super.key});

  @override
  State<AllNotesScreen> createState() {
    return _AllNotesScreenState();
  }
}

class _AllNotesScreenState extends State<AllNotesScreen> {
  final Map<String, _SharedUser> _usersById = {};

  final Set<String> _loadingUserIds = {};

  String? _selectedLanguageCode;
  String? _selectedCategory;

  bool _isCreating = false;

  static const String _unspecifiedLanguage = '__unspecified_language__';

  static const String _uncategorized = '__uncategorized__';

  static const String _allSelection = '__all__';

  static const String _noneSelection = '__none__';

  List<String> get _categoryIds => ForumCategories.roots
      .map((category) => category.id)
      .toList(growable: false);

  String? get _currentUserId {
    return context.read<AuthCubit>().user?.id;
  }

  bool get _hasActiveFilter {
    return _selectedLanguageCode != null || _selectedCategory != null;
  }

  // ============================================================
  // 用户资料
  // ============================================================

  Future<void> _loadUser(String userId) async {
    if (_usersById.containsKey(userId) || _loadingUserIds.contains(userId)) {
      return;
    }

    _loadingUserIds.add(userId);

    try {
      final user = await context.read<ProfileRepository>().getProfile(userId);

      if (!mounted || user == null) {
        return;
      }

      setState(() {
        final locale = Localizations.localeOf(context);

        _usersById[userId] = _SharedUser.fromUserModel(
          user,
          fallbackName: context.l10n.user,
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode ?? '',
        );
      });
    } catch (error) {
      debugPrint('加载共享用户失败：$userId，$error');
    } finally {
      _loadingUserIds.remove(userId);
    }
  }

  void _ensureUsersLoaded(List<NoteModel> notes, String currentUserId) {
    final userIds = notes
        .expand((note) => note.participantIds)
        .where((userId) => userId.isNotEmpty && userId != currentUserId)
        .toSet();

    for (final userId in userIds) {
      unawaited(_loadUser(userId));
    }
  }

  // ============================================================
  // 筛选
  // ============================================================

  List<NoteModel> _filterNotes(List<NoteModel> notes) {
    return notes.where((note) {
      final noteLanguageCode = note.languageCode?.trim();

      final noteCategory = note.category?.trim();

      final matchesLanguage =
          _selectedLanguageCode == null ||
          (_selectedLanguageCode == _unspecifiedLanguage
              ? noteLanguageCode == null || noteLanguageCode.isEmpty
              : noteLanguageCode == _selectedLanguageCode);

      final matchesCategory =
          _selectedCategory == null ||
          (_selectedCategory == _uncategorized
              ? noteCategory == null || noteCategory.isEmpty
              : noteCategory == _selectedCategory);

      return matchesLanguage && matchesCategory;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedLanguageCode = null;
      _selectedCategory = null;
    });
  }

  // ============================================================
  // 语言显示
  // ============================================================

  String _languageLabel(String? languageCode) {
    if (languageCode == null) {
      return context.l10n.allLanguages;
    }

    if (languageCode == _unspecifiedLanguage) {
      return context.l10n.unspecifiedLanguage;
    }

    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    for (final language in ForumLanguages.supportedLanguages) {
      if (language.code == languageCode) {
        final name = language.nameOf(uiLanguageCode);

        if (language.flag.isEmpty) {
          return name;
        }

        return '${language.flag} $name';
      }
    }

    return languageCode;
  }

  String _newNoteLanguageLabel(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) {
      return context.l10n.notSelected;
    }

    return _languageLabel(languageCode);
  }

  // ============================================================
  // 分类显示
  // ============================================================

  String _categoryName(String? category) {
    if (category == null) {
      return context.l10n.allCategories;
    }

    if (category == _uncategorized) {
      return context.l10n.uncategorized;
    }

    final l10n = AppLocalizations.of(context)!;
    final uiLanguageCode = Localizations.localeOf(context).languageCode;
    return l10n.categoryName(
      category,
      fallback: ForumCategories.nameOf(category, uiLanguageCode),
    );
  }

  String _newNoteCategoryLabel(String? category) {
    if (category == null || category.isEmpty) {
      return context.l10n.notSelected;
    }

    return _categoryName(category);
  }

  // ============================================================
  // 笔记列表 - 选择语言
  // ============================================================

  Future<void> _showLanguagePicker() async {
    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      Icon(Icons.language),
                      SizedBox(width: 10),
                      Text(
                        context.l10n.selectLanguage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.public),
                        title: Text(context.l10n.allLanguages),
                        trailing: _selectedLanguageCode == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _allSelection);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: Text(context.l10n.unspecifiedLanguage),
                        trailing: _selectedLanguageCode == _unspecifiedLanguage
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _unspecifiedLanguage);
                        },
                      ),

                      const Divider(),

                      for (final language in ForumLanguages.supportedLanguages)
                        ListTile(
                          leading: SizedBox(
                            width: 36,
                            child: Text(
                              language.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(language.nameOf(uiLanguageCode)),
                          subtitle: Text(language.code),
                          trailing: _selectedLanguageCode == language.code
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext, language.code);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (selected == _allSelection) {
        _selectedLanguageCode = null;
      } else {
        _selectedLanguageCode = selected;
      }
    });
  }

  // ============================================================
  // 笔记列表 - 选择分类
  // ============================================================

  Future<void> _showCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined),
                      SizedBox(width: 10),
                      Text(
                        context.l10n.selectCategory,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.apps_outlined),
                        title: Text(context.l10n.allCategories),
                        trailing: _selectedCategory == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _allSelection);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.label_off_outlined),
                        title: Text(context.l10n.uncategorized),
                        trailing: _selectedCategory == _uncategorized
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _uncategorized);
                        },
                      ),

                      const Divider(),

                      for (int index = 0; index < _categoryIds.length; index++)
                        ListTile(
                          leading: const Icon(Icons.topic_outlined),
                          title: Text(_categoryName(_categoryIds[index])),
                          subtitle: Text(_categoryIds[index]),
                          trailing: _selectedCategory == _categoryIds[index]
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext, _categoryIds[index]);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (selected == _allSelection) {
        _selectedCategory = null;
      } else {
        _selectedCategory = selected;
      }
    });
  }

  // ============================================================
  // 新建笔记 - 语言
  // ============================================================

  Future<String?> _pickLanguageForNewNote(String? currentLanguageCode) async {
    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      Icon(Icons.language),
                      SizedBox(width: 10),
                      Text(
                        context.l10n.noteLanguage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.remove_circle_outline),
                        title: Text(context.l10n.notSelected),
                        trailing: currentLanguageCode == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _noneSelection);
                        },
                      ),

                      const Divider(),

                      for (final language in ForumLanguages.supportedLanguages)
                        ListTile(
                          leading: SizedBox(
                            width: 36,
                            child: Text(
                              language.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(language.nameOf(uiLanguageCode)),
                          subtitle: Text(language.code),
                          trailing: currentLanguageCode == language.code
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext, language.code);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return currentLanguageCode;
    }

    if (selected == _noneSelection) {
      return null;
    }

    return selected;
  }

  // ============================================================
  // 新建笔记 - 分类
  // ============================================================

  Future<String?> _pickCategoryForNewNote(String? currentCategory) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined),
                      SizedBox(width: 10),
                      Text(
                        context.l10n.noteCategory,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.remove_circle_outline),
                        title: Text(context.l10n.notSelected),
                        trailing: currentCategory == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext, _noneSelection);
                        },
                      ),

                      const Divider(),

                      for (int index = 0; index < _categoryIds.length; index++)
                        ListTile(
                          leading: const Icon(Icons.topic_outlined),
                          title: Text(_categoryName(_categoryIds[index])),
                          subtitle: Text(_categoryIds[index]),
                          trailing: currentCategory == _categoryIds[index]
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext, _categoryIds[index]);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return currentCategory;
    }

    if (selected == _noneSelection) {
      return null;
    }

    return selected;
  }

  // ============================================================
  // 新建笔记 - 共享成员
  // ============================================================

  Future<Set<String>?> _pickSharedUsersForNewNote({
    required String currentUserId,
    required Set<String> selectedUserIds,
  }) async {
    try {
      final discoverUsers = await context
          .read<DiscoverRepository>()
          .watchAllUsers(currentUserId)
          .first;

      final users = discoverUsers
          .where((user) => user.id != currentUserId)
          .map(
            (user) => _SharedUser.fromDiscoverUser(
              user,
              fallbackName: context.l10n.user,
            ),
          )
          .toList();

      users.sort((first, second) {
        return first.name.compareTo(second.name);
      });

      if (!mounted) {
        return null;
      }

      return showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) {
          return _NewNoteSharedUsersPicker(
            users: users,
            selectedUserIds: selectedUserIds,
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.loadFailed}: $error'),
          backgroundColor: Colors.red,
        ),
      );

      return null;
    }
  }

  // ============================================================
  // 新建笔记配置
  // ============================================================

  Future<_NewNoteConfig?> _showNewNoteConfig(String currentUserId) async {
    String? languageCode;
    String? category;

    final sharedUserIds = <String>{};

    return showModalBottomSheet<_NewNoteConfig>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.newNote,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.newNoteConfigDescription,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          _NewNoteConfigTile(
                            icon: Icons.language,
                            title: context.l10n.currentLanguage,
                            value: _newNoteLanguageLabel(languageCode),
                            selected: languageCode != null,
                            onTap: () async {
                              final result = await _pickLanguageForNewNote(
                                languageCode,
                              );

                              if (!sheetContext.mounted) {
                                return;
                              }

                              setSheetState(() {
                                languageCode = result;
                              });
                            },
                          ),

                          const Divider(height: 1, indent: 52),

                          _NewNoteConfigTile(
                            icon: Icons.category_outlined,
                            title: context.l10n.category,
                            value: _newNoteCategoryLabel(category),
                            selected: category != null,
                            onTap: () async {
                              final result = await _pickCategoryForNewNote(
                                category,
                              );

                              if (!sheetContext.mounted) {
                                return;
                              }

                              setSheetState(() {
                                category = result;
                              });
                            },
                          ),

                          const Divider(height: 1, indent: 52),

                          _NewNoteConfigTile(
                            icon: Icons.group_outlined,
                            title: context.l10n.sharing,
                            value: sharedUserIds.isEmpty
                                ? context.l10n.onlyMe
                                : context.l10n.selectedPeople(
                                    '${sharedUserIds.length}',
                                  ),
                            selected: sharedUserIds.isNotEmpty,
                            onTap: () async {
                              final result = await _pickSharedUsersForNewNote(
                                currentUserId: currentUserId,
                                selectedUserIds: sharedUserIds,
                              );

                              if (result == null || !sheetContext.mounted) {
                                return;
                              }

                              setSheetState(() {
                                sharedUserIds
                                  ..clear()
                                  ..addAll(result);
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                _NewNoteConfig(
                                  languageCode: languageCode,
                                  category: category,
                                  sharedUserIds: sharedUserIds.toList(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.note_add_outlined),
                            label: Text(context.l10n.createNote),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 创建笔记
  // ============================================================

  Future<void> _createPrivateNote() async {
    final currentUserId = _currentUserId;

    if (currentUserId == null || _isCreating) {
      return;
    }

    final config = await _showNewNoteConfig(currentUserId);

    if (config == null || !mounted) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final noteId = await context.read<NoteRepository>().createNote(
        ownerId: currentUserId,
        sharedUserIds: config.sharedUserIds,
        languageCode: config.languageCode,
        category: config.category,
      );

      if (!mounted) {
        return;
      }

      await context.push<void>(AppRoutes.noteEditorLocation(noteId: noteId));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.createNoteFailed}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  // ============================================================
  // 页面
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.myNotes)),
        body: Center(child: Text(context.l10n.pleaseSignIn)),
      );
    }

    final noteRepository = context.read<NoteRepository>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(context.l10n.myNotes),

        actions: [
          if (_hasActiveFilter)
            TextButton(
              onPressed: _clearFilters,
              child: Text(context.l10n.clear),
            ),
        ],
      ),

      body: StreamBuilder<List<NoteModel>>(
        stream: noteRepository.watchNotesForUser(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      context.l10n.notesLoadFailed,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final notes = snapshot.data ?? const <NoteModel>[];

          _ensureUsersLoaded(notes, currentUserId);

          final visibleNotes = _filterNotes(notes);

          return Column(
            children: [
              _buildFilterPanel(),

              Expanded(
                child: _buildNotesContent(
                  notes: visibleNotes,
                  currentUserId: currentUserId,
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createPrivateNote,

        icon: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),

        label: Text(_isCreating ? context.l10n.creating : context.l10n.newNote),
      ),
    );
  }

  // ============================================================
  // 顶部筛选
  // ============================================================

  Widget _buildFilterPanel() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          InkWell(
            onTap: _showLanguagePicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 21),

                  const SizedBox(width: 12),

                  Text(
                    context.l10n.currentLanguage,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),

                  const Spacer(),

                  Flexible(
                    child: Text(
                      _languageLabel(_selectedLanguageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedLanguageCode == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const Divider(height: 1, indent: 50),

          InkWell(
            onTap: _showCategoryPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, size: 21),

                  const SizedBox(width: 12),

                  Text(
                    context.l10n.category,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),

                  const Spacer(),

                  Flexible(
                    child: Text(
                      _categoryName(_selectedCategory),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedCategory == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 笔记内容
  // ============================================================

  Widget _buildNotesContent({
    required List<NoteModel> notes,
    required String currentUserId,
  }) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 12),

            Text(
              _hasActiveFilter
                  ? context.l10n.noMatchingNotes
                  : context.l10n.noNotesYet,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            if (_hasActiveFilter) ...[
              const SizedBox(height: 10),

              TextButton(
                onPressed: _clearFilters,
                child: Text(context.l10n.clearFilters),
              ),
            ] else ...[
              const SizedBox(height: 6),

              Text(
                context.l10n.tapFabToCreateNote,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: notes.length,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        return _buildNoteCard(note: notes[index], currentUserId: currentUserId);
      },
    );
  }

  // ============================================================
  // 笔记卡片
  // ============================================================

  Widget _buildNoteCard({
    required NoteModel note,
    required String currentUserId,
  }) {
    final title = note.title.trim();

    final content = note.content.trim();

    final canEdit = note.canEdit(currentUserId);

    final otherUserIds = note.participantIds
        .where((userId) => userId != currentUserId)
        .toList();

    final firstUser = otherUserIds.isEmpty
        ? null
        : _usersById[otherUserIds.first];

    final sharedLabel = _buildSharedLabel(otherUserIds);

    final languageCode = note.languageCode?.trim();

    final category = note.category?.trim();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push(AppRoutes.noteEditorLocation(noteId: note.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstUser != null)
                _buildAvatar(firstUser, radius: 22)
              else
                const CircleAvatar(radius: 22, child: Icon(Icons.lock_outline)),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? context.l10n.untitledNote : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Icon(
                          canEdit ? Icons.edit_outlined : Icons.lock_outline,
                          size: 17,
                          color: Colors.grey,
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      content.isEmpty ? context.l10n.noContent : content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: content.isEmpty
                            ? Colors.grey
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),

                    if ((languageCode != null && languageCode.isNotEmpty) ||
                        (category != null && category.isNotEmpty)) ...[
                      const SizedBox(height: 9),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (languageCode != null && languageCode.isNotEmpty)
                            _buildMetaTag(
                              icon: Icons.language,
                              text: _languageLabel(languageCode),
                            ),

                          if (category != null && category.isNotEmpty)
                            _buildMetaTag(
                              icon: Icons.category_outlined,
                              text: _categoryName(category),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sharedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        Text(
                          _formatTime(note.updatedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaTag({required IconData icon, required String text}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),

          const SizedBox(width: 4),

          Text(
            text,
            style: TextStyle(fontSize: 11, color: colorScheme.primary),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 共享信息
  // ============================================================

  String _buildSharedLabel(List<String> userIds) {
    if (userIds.isEmpty) {
      return context.l10n.privateNote;
    }

    final names = userIds
        .map((userId) => _usersById[userId]?.name ?? context.l10n.user)
        .toList();

    if (names.length == 1) {
      return context.l10n.sharedWithUser(names.first);
    }

    if (names.length == 2) {
      return context.l10n.sharedWithUsers(names.join('、'));
    }

    return context.l10n.sharedWithMany(
      names.take(2).join('、'),
      '${names.length}',
    );
  }

  Widget _buildAvatar(_SharedUser user, {required double radius}) {
    final avatarUrl = user.avatarUrl?.trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8E8E8),
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? NetworkImage(avatarUrl)
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? const Icon(Icons.person, color: Colors.grey)
          : null,
    );
  }

  // ============================================================
  // 时间
  // ============================================================

  String _formatTime(DateTime dateTime) {
    if (dateTime.millisecondsSinceEpoch == 0) {
      return '';
    }

    final local = dateTime.toLocal();

    final now = DateTime.now();

    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    if (isToday) {
      return '$hour:$minute';
    }

    final month = local.month.toString().padLeft(2, '0');

    final day = local.day.toString().padLeft(2, '0');

    if (local.year == now.year) {
      return '$month-$day';
    }

    return '${local.year}-$month-$day';
  }
}

// ============================================================
// 新建笔记配置结果
// ============================================================

class _NewNoteConfig {
  final String? languageCode;
  final String? category;
  final List<String> sharedUserIds;

  const _NewNoteConfig({
    this.languageCode,
    this.category,
    this.sharedUserIds = const [],
  });
}

// ============================================================
// 新建笔记配置行
// ============================================================

class _NewNoteConfigTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _NewNoteConfigTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: selected ? colorScheme.primary : null),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? colorScheme.primary : Colors.grey,
              ),
            ),
          ),

          const SizedBox(width: 4),

          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ============================================================
// 新建笔记共享用户选择器
// ============================================================

class _NewNoteSharedUsersPicker extends StatefulWidget {
  final List<_SharedUser> users;
  final Set<String> selectedUserIds;

  const _NewNoteSharedUsersPicker({
    required this.users,
    required this.selectedUserIds,
  });

  @override
  State<_NewNoteSharedUsersPicker> createState() {
    return _NewNoteSharedUsersPickerState();
  }
}

class _NewNoteSharedUsersPickerState extends State<_NewNoteSharedUsersPicker> {
  final TextEditingController _searchController = TextEditingController();

  late final Set<String> _selectedUserIds;

  String _keyword = '';

  @override
  void initState() {
    super.initState();

    _selectedUserIds = Set<String>.from(widget.selectedUserIds);
  }

  List<_SharedUser> get _visibleUsers {
    final keyword = _keyword.trim().toLowerCase();

    if (keyword.isEmpty) {
      return widget.users;
    }

    return widget.users.where((user) {
      return user.name.toLowerCase().contains(keyword) ||
          user.username.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = _visibleUsers;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.sharedMembers,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedUserIds);
                    },
                    child: Text(context.l10n.done),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _keyword = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: context.l10n.searchNicknameOrUsername,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: users.isEmpty
                  ? Center(child: Text(context.l10n.noUsersFound))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];

                        final selected = _selectedUserIds.contains(user.id);

                        return CheckboxListTile(
                          value: selected,
                          secondary: CircleAvatar(
                            backgroundImage:
                                user.avatarUrl != null &&
                                    user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child:
                                user.avatarUrl == null ||
                                    user.avatarUrl!.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(user.name),
                          subtitle: user.username.isEmpty
                              ? null
                              : Text('@${user.username}'),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedUserIds.add(user.id);
                              } else {
                                _selectedUserIds.remove(user.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 用户
// ============================================================

class _SharedUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  const _SharedUser({
    required this.id,
    required this.name,
    this.username = '',
    this.avatarUrl,
  });

  factory _SharedUser.fromUserModel(
    UserModel user, {
    required String fallbackName,
    required String languageCode,
    required String scriptCode,
  }) {
    final name = user
        .displayNameFor(
          languageCode: languageCode,
          scriptCode: scriptCode,
        )
        .trim();

    final avatarUrl = user.avatarUrl.trim();

    return _SharedUser(
      id: user.id,
      name: name.isEmpty ? fallbackName : name,
      username: user.username.trim(),
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    );
  }

  factory _SharedUser.fromDiscoverUser(
    DiscoverUser user, {
    required String fallbackName,
  }) {
    final name = user.displayName.trim();
    final avatarUrl = user.avatarUrl.trim();

    return _SharedUser(
      id: user.id,
      name: name.isEmpty ? fallbackName : name,
      username: user.username.trim(),
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    );
  }
}
