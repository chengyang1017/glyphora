import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart' as auth_cubit;

import '../../../../app/l10n/app_localizations.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/forum_categories.dart';
import 'package:glyphora_language_core/glyphora_language_core.dart';
import '../../../language/presentation/screens/language_select_screen.dart';
import '../widgets/recommended_posts_view.dart';

import '../../../language/data/forum_languages.dart';

enum _HomeSection { recommended, categories }

enum _CategoryLayout { list, grid }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

  class _HomeTabState extends State<HomeTab> {
    _HomeSection _currentSection = _HomeSection.recommended;
    _CategoryLayout _categoryLayout = _CategoryLayout.list;
    String _selectedChannelKey = 'zh';
  static const List<CategoryConfig> _categories = [
    CategoryConfig(id: 'language_learning', icon: Icons.translate_rounded),
    CategoryConfig(id: 'programming', icon: Icons.code_rounded),
    CategoryConfig(id: 'ai', icon: Icons.smart_toy_rounded),
    CategoryConfig(id: 'technology', icon: Icons.devices_rounded),
    CategoryConfig(id: 'gaming', icon: Icons.sports_esports_rounded),
    CategoryConfig(id: 'music', icon: Icons.music_note_rounded),
    CategoryConfig(id: 'movies', icon: Icons.movie_rounded),
    CategoryConfig(id: 'campus', icon: Icons.school_rounded),
    CategoryConfig(id: 'startup', icon: Icons.rocket_launch_rounded),
    CategoryConfig(id: 'friends', icon: Icons.people_alt_rounded),
    CategoryConfig(id: 'travel', icon: Icons.flight_takeoff_rounded),
    CategoryConfig(id: 'chat', icon: Icons.forum_rounded),
    CategoryConfig(id: 'love', icon: Icons.favorite_rounded),
    CategoryConfig(id: 'food', icon: Icons.restaurant_rounded),
    CategoryConfig(id: 'medicine', icon: Icons.medical_services_rounded),
  ];

  ForumLanguageChannel get _currentChannel {
    return ForumLanguages.channels.firstWhere(
      (channel) => channel.key == _selectedChannelKey,
      orElse: () {
        return ForumLanguages.channels.firstWhere(
          (channel) => channel.language.code == 'zh',
        );
      },
    );
  }

  void _selectSection(_HomeSection section) {
    if (_currentSection == section) {
      return;
    }

    setState(() {
      _currentSection = section;
    });
  }

  Future<void> _openLanguageSelect(String uiLanguageCode) async {
    final selectedChannel = await Navigator.of(context)
        .push<ForumLanguageChannel>(
          MaterialPageRoute<ForumLanguageChannel>(
            builder: (_) => LanguageSelectScreen(
              currentChannel: _currentChannel,
              currentUiLanguageCode: uiLanguageCode,
            ),
          ),
        );

    if (!mounted || selectedChannel == null) {
      return;
    }

    if (selectedChannel.key == _selectedChannelKey) {
      return;
    }

    setState(() {
      _selectedChannelKey = selectedChannel.key;
    });
  }

  void _openCategory({required CategoryConfig category}) {
    final channel = _currentChannel;

    context.push(
      AppRoutes.feedLocation(channelKey: channel.key, categoryId: category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final uiLanguageCode = Localizations.localeOf(context).languageCode;

    final currentChannel = _currentChannel;

    final currentLanguage = currentChannel.language;

    final currentLanguageName = currentChannel.nameOf(uiLanguageCode);

    final isRecommended = _currentSection == _HomeSection.recommended;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRecommended
                  ? l10n.get('recommendedForYou')
                  : l10n.forumCategories,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            Text(
              isRecommended
                  ? l10n.get('recommendedOnlyInterests')
                  : '$currentLanguageName · ${l10n.currentChannel}',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (!isRecommended)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _ChannelSelectorButton(
                flag: currentLanguage.flag,
                languageName: currentLanguageName,
                onPressed: () {
                  _openLanguageSelect(uiLanguageCode);
                },
              ),
            ),
        ],
      ),
      drawer: _HomeDrawer(
        currentSection: _currentSection,
        onSectionSelected: _selectSection,
      ),
      body: IndexedStack(
        index: _currentSection.index,
        children: [
          const _RecommendedSection(),
          _CategorySection(
            language: currentLanguage,
            channelKey: currentChannel.key,
            languageName: currentLanguageName,
            categories: _categories,
            layout: _categoryLayout,
            onLayoutChanged: (layout) {
              setState(() {
                _categoryLayout = layout;
              });
            },
            onChangeLanguage: () {
              _openLanguageSelect(uiLanguageCode);
            },
            onCategorySelected: (category) {
              _openCategory(category: category);
            },
          ),
        ],
      ),
    );
  }
}

class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.14),
                  colorScheme.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('interestHomeTitle'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.get('interestHomeDesc'),
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(child: RecommendedPostsView()),
      ],
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  final _HomeSection currentSection;
  final ValueChanged<_HomeSection> onSectionSelected;

  const _HomeDrawer({
    required this.currentSection,
    required this.onSectionSelected,
  });

  void _select(BuildContext context, _HomeSection section) {
    Navigator.of(context).pop();
    onSectionSelected(section);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.72),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.get('languageCommunity'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.get('languageCommunityTagline'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _DrawerNavigationItem(
                    selected: currentSection == _HomeSection.recommended,
                    icon: Icons.home_rounded,
                    outlineIcon: Icons.home_outlined,
                    title: l10n.get('recommendedHome'),
                    subtitle: l10n.get('recommendedHomeDesc'),
                    onTap: () {
                      _select(context, _HomeSection.recommended);
                    },
                  ),
                  const SizedBox(height: 6),
                  _DrawerNavigationItem(
                    selected: currentSection == _HomeSection.categories,
                    icon: Icons.grid_view_rounded,
                    outlineIcon: Icons.grid_view_outlined,
                    title: l10n.get('categoryChannels'),
                    subtitle: l10n.get('categoryChannelsDesc'),
                    onTap: () {
                      _select(context, _HomeSection.categories);
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.get('exploreLanguageContent'),
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavigationItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData outlineIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerNavigationItem({
    required this.selected,
    required this.icon,
    required this.outlineIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  selected ? icon : outlineIcon,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.65),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.48),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final LanguageConfig language;
  final String channelKey;
  final String languageName;
  final List<CategoryConfig> categories;
  final _CategoryLayout layout;
  final ValueChanged<_CategoryLayout> onLayoutChanged;
  final VoidCallback onChangeLanguage;
  final ValueChanged<CategoryConfig> onCategorySelected;

  const _CategorySection({
    required this.language,
    required this.channelKey,
    required this.languageName,
    required this.categories,
    required this.layout,
    required this.onLayoutChanged,
    required this.onChangeLanguage,
    required this.onCategorySelected,
  });

  String _interestKey(String categoryId) => '$channelKey::$categoryId';

  Future<void> _toggleInterest({
    required BuildContext context,
    required auth_cubit.AuthCubit authProvider,
    required CategoryConfig category,
  }) async {
    final copy = _CategoryCopy.of(context);

    if (authProvider.user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.signInFirst)));
      return;
    }

    if (!authProvider.interestsLoaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.interestsLoading)));
      return;
    }

    try {
      await authProvider.toggleInterest(_interestKey(category.id));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${copy.updateFailed}: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<auth_cubit.AuthCubit>();
    final interests = authProvider.interests;
    final copy = _CategoryCopy.of(context);
    final interestedCount = categories.where((category) {
      return interests.contains(_interestKey(category.id));
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        final horizontalPadding = isTablet ? 24.0 : 16.0;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isTablet ? 14 : 10,
                horizontalPadding,
                0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _CategoryOverview(
                    language: language,
                    languageName: languageName,
                    interestedCount: interestedCount,
                    totalCount: categories.length,
                    interestsLoaded: authProvider.interestsLoaded,
                    onChangeLanguage: onChangeLanguage,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isTablet ? 18 : 16,
                horizontalPadding,
                10,
              ),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _CategorySectionHeading(
                    title: copy.selectTopics,
                    subtitle: authProvider.interestsLoaded
                        ? copy.interestSummary(
                            interestedCount,
                            categories.length,
                          )
                        : copy.interestsLoading,
                    layout: layout,
                    onLayoutChanged: onLayoutChanged,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _CategoryGrid(
                layout: layout,
                channelKey: channelKey,
                categories: categories,
                interests: interests,
                onCategorySelected: onCategorySelected,
                onInterestPressed: (category, _) {
                  _toggleInterest(
                    context: context,
                    authProvider: authProvider,
                    category: category,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryOverview extends StatelessWidget {
  final LanguageConfig language;
  final String languageName;
  final int interestedCount;
  final int totalCount;
  final bool interestsLoaded;
  final VoidCallback onChangeLanguage;

  const _CategoryOverview({
    required this.language,
    required this.languageName,
    required this.interestedCount,
    required this.totalCount,
    required this.interestsLoaded,
    required this.onChangeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;

    if (!isTablet) {
      return _LanguageChannelCard(
        language: language,
        languageName: languageName,
        onChangeLanguage: onChangeLanguage,
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _LanguageChannelCard(
              language: language,
              languageName: languageName,
              onChangeLanguage: onChangeLanguage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _InterestOverviewCard(
              interestedCount: interestedCount,
              totalCount: totalCount,
              interestsLoaded: interestsLoaded,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChannelCard extends StatelessWidget {
  final LanguageConfig language;
  final String languageName;
  final VoidCallback onChangeLanguage;

  const _LanguageChannelCard({
    required this.language,
    required this.languageName,
    required this.onChangeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(isTablet ? 22 : 20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChangeLanguage,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.13),
                colorScheme.secondary.withValues(alpha: 0.055),
              ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 22 : 20),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 18 : 16,
              vertical: isTablet ? 16 : 14,
            ),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 54 : 50,
                  height: isTablet ? 54 : 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    language.flag,
                    style: TextStyle(fontSize: isTablet ? 28 : 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.currentChannel,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        languageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: isTablet ? 18 : 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.75),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.switchLanguage,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestOverviewCard extends StatelessWidget {
  final int interestedCount;
  final int totalCount;
  final bool interestsLoaded;

  const _InterestOverviewCard({
    required this.interestedCount,
    required this.totalCount,
    required this.interestsLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final copy = _CategoryCopy.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interestsLoaded ? '$interestedCount / $totalCount' : '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  interestsLoaded
                      ? copy.interestCardLabel
                      : copy.interestsLoading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final _CategoryLayout layout;
  final ValueChanged<_CategoryLayout> onLayoutChanged;

  const _CategorySectionHeading({
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CategoryLayoutButton(
                icon: Icons.view_agenda_rounded,
                selected: layout == _CategoryLayout.list,
                onTap: () {
                  onLayoutChanged(_CategoryLayout.list);
                },
              ),
              _CategoryLayoutButton(
                icon: Icons.grid_view_rounded,
                selected: layout == _CategoryLayout.grid,
                onTap: () {
                  onLayoutChanged(_CategoryLayout.grid);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryLayoutButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryLayoutButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final _CategoryLayout layout;
  final String channelKey;
  final List<CategoryConfig> categories;
  final Set<String> interests;
  final ValueChanged<CategoryConfig> onCategorySelected;
  final void Function(CategoryConfig category, bool isInterested)
  onInterestPressed;

  const _CategoryGrid({
    required this.layout,
    required this.channelKey,
    required this.categories,
    required this.interests,
    required this.onCategorySelected,
    required this.onInterestPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final horizontalPadding = width >= 600 ? 24.0 : 16.0;

        final int crossAxisCount;

        if (layout == _CategoryLayout.list) {
          crossAxisCount = 1;
        } else if (width >= 1000) {
          crossAxisCount = 4;
        } else if (width >= 600) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        final itemHeight = layout == _CategoryLayout.list ? 96.0 : 156.0;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1088),
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                28,
              ),
              itemCount: categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisExtent: itemHeight,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final category = categories[index];

                final categoryName = l10n.categoryName(
                  category.id,
                  fallback: ForumCategories.nameOf(
                    category.id,
                    Localizations.localeOf(context).languageCode,
                  ),
                );

                final key = '$channelKey::${category.id}';

                final isInterested = interests.contains(key);

                return _CategoryCard(
                  gridMode: layout == _CategoryLayout.grid,
                  index: index,
                  icon: category.icon,
                  name: categoryName,
                  isInterested: isInterested,
                  onTap: () => onCategorySelected(category),
                  onInterestPressed: () {
                    onInterestPressed(category, isInterested);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class CategoryConfig {
  final String id;
  final IconData icon;

  const CategoryConfig({required this.id, required this.icon});
}

class _ChannelSelectorButton extends StatelessWidget {
  final String flag;
  final String languageName;
  final VoidCallback onPressed;

  const _ChannelSelectorButton({
    required this.flag,
    required this.languageName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  languageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colorScheme.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final bool gridMode;
  final int index;
  final IconData icon;
  final String name;
  final bool isInterested;
  final VoidCallback onTap;
  final VoidCallback onInterestPressed;

  const _CategoryCard({
    required this.gridMode,
    required this.index,
    required this.icon,
    required this.name,
    required this.isInterested,
    required this.onTap,
    required this.onInterestPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final accent = _accentColor(colors, index);

    final copy = _CategoryCopy.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: isInterested
                ? colors.primary.withValues(alpha: 0.07)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isInterested
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outlineVariant,
              width: isInterested ? 1.5 : 1,
            ),
          ),
          child: gridMode
              ? _buildGrid(colors, accent, copy)
              : _buildList(colors, accent, copy),
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme colors, Color accent, _CategoryCopy copy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _iconBox(accent, 52, 26),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                if (isInterested) ...[
                  const SizedBox(height: 5),
                  Text(
                    copy.following,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          _heartButton(colors, copy),
        ],
      ),
    );
  }

  Widget _buildGrid(ColorScheme colors, Color accent, _CategoryCopy copy) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(accent, 46, 23),

              const Spacer(),

              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),

              const SizedBox(height: 5),

              SizedBox(
                height: 16,
                child: isInterested
                    ? Text(
                        copy.following,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ],
          ),

          Positioned(top: -6, right: -7, child: _heartButton(colors, copy)),
        ],
      ),
    );
  }

  Widget _iconBox(Color accent, double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }

  Widget _heartButton(ColorScheme colors, _CategoryCopy copy) {
    return IconButton(
      tooltip: isInterested ? copy.removeInterest : copy.addInterest,
      onPressed: onInterestPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isInterested ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isInterested
            ? colors.primary
            : colors.onSurfaceVariant.withValues(alpha: 0.6),
        size: 21,
      ),
    );
  }

  Color _accentColor(ColorScheme colorScheme, int index) {
    final colors = <Color>[
      colorScheme.primary,
      colorScheme.secondary,
      Colors.deepPurple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
    ];

    return colors[index % colors.length];
  }
}

class _CategoryCopy {
  final String selectTopics;
  final String interestsLoading;
  final String signInFirst;
  final String updateFailed;
  final String interestCardLabel;
  final String following;
  final String addInterest;
  final String removeInterest;
  final String Function(int selected, int total) interestSummary;

  const _CategoryCopy({
    required this.selectTopics,
    required this.interestsLoading,
    required this.signInFirst,
    required this.updateFailed,
    required this.interestCardLabel,
    required this.following,
    required this.addInterest,
    required this.removeInterest,
    required this.interestSummary,
  });

  static _CategoryCopy of(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _CategoryCopy(
      selectTopics: l10n.get('selectTopics'),
      interestsLoading: l10n.get('interestsLoading'),
      signInFirst: l10n.get('signInFirst'),
      updateFailed: l10n.get('interestUpdateFailed'),
      interestCardLabel: l10n.get('interestCardLabel'),
      following: l10n.get('following'),
      addInterest: l10n.get('addInterest'),
      removeInterest: l10n.get('removeInterest'),
      interestSummary: (selected, total) => l10n.getWithArgs(
        'interestSummary',
        <String, String>{'selected': '$selected', 'total': '$total'},
      ),
    );
  }
}
