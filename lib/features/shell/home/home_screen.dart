import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/dally_empty_state.dart';
import '../../../core/widgets/filter_chip_pill.dart';
import '../../../core/widgets/game_tile.dart';
import 'filter_sheet.dart';
import '../../games/mental_math/math_difficulty.dart';
import 'home_filter.dart';
import 'search_field.dart';

/// Home = the games list. Registry-driven, grouped into labelled sections, with
/// a catalogue-derived chip row, a More sheet and a search mode. No bottom nav;
/// Stats/Settings are pushed, the theme swatch is the quick theme entry.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;

  void _exitSearch() {
    ref.read(searchQueryProvider.notifier).clear();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filter = ref.watch(homeFilterProvider);
    final sections = ref.watch(homeSectionsProvider);
    final categories = ref.watch(availableCategoriesProvider);
    final total = ref.watch(gameCountProvider);
    final matching = ref.watch(filteredGamesProvider).length;
    final accent = ref.watch(paletteProvider).accent;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_searching)
                SearchBarRow(onCancel: _exitSearch)
              else
                Row(
                  children: [
                    Text(
                      'Dally',
                      style: DallyType.displayLg.copyWith(
                        fontSize: 27,
                        letterSpacing: -0.54,
                        color: t.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _TopIcon(
                      icon: Icons.search_rounded,
                      label: 'Search games',
                      onTap: () => setState(() => _searching = true),
                    ),
                    const Gap.h(Insets.s2),
                    _TopIcon(
                        icon: Icons.bar_chart_rounded,
                        label: 'Stats',
                        onTap: () => context.push(Routes.stats)),
                    const Gap.h(Insets.s2),
                    _TopIcon(
                        icon: Icons.tune_rounded,
                        label: 'Settings',
                        onTap: () => context.push(Routes.settings)),
                    const Gap.h(Insets.s2),
                    _ThemeSwatchButton(accent: accent, onTap: () => context.push(Routes.theme)),
                  ],
                ),
              const Gap(Insets.s4 + 2),
              if (_searching)
                Expanded(child: SearchResults(onOpen: _open))
              else ...[
                // Chip row — generated from the catalogue, scrolls rather than
                // wraps so it stays one line at any width.
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      FilterChipPill(
                        label: 'All',
                        selected: filter.category == null,
                        onTap: () => ref.read(homeFilterProvider.notifier).selectCategory(null),
                      ),
                      for (final c in categories) ...[
                        const Gap.h(Insets.s2),
                        FilterChipPill(
                          label: c.label,
                          selected: filter.category == c,
                          onTap: () => ref.read(homeFilterProvider.notifier).selectCategory(c),
                        ),
                      ],
                      const Gap.h(Insets.s2),
                      FilterChipPill(
                        label: filter.sheetCount > 0 ? 'More ${filter.sheetCount}' : 'More',
                        selected: filter.sheetCount > 0,
                        onTap: () => showFilterSheet(context, ref),
                      ),
                    ],
                  ),
                ),
                if (!filter.isEmpty) ...[
                  const Gap(Insets.s3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$matching of $total · ${filter.summary}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
                        ),
                      ),
                      const Gap.h(Insets.s3),
                      Semantics(
                        button: true,
                        label: 'Clear filters',
                        child: GestureDetector(
                          onTap: () => ref.read(homeFilterProvider.notifier).clear(),
                          child: Text('Clear',
                              style: DallyType.bodyStrong
                                  .copyWith(fontSize: 12, color: t.accent)),
                        ),
                      ),
                    ],
                  ),
                ],
                const Gap(Insets.s4 + 2),
                Expanded(
                  child: sections.isEmpty
                      ? DallyEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No games match',
                          message: 'Nothing fits that combination — clear a filter to see more.',
                          actionLabel: 'Clear filters',
                          onAction: () => ref.read(homeFilterProvider.notifier).clear(),
                        )
                      : _SectionedGrid(sections: sections, onOpen: _open),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(GameModule m) => context.push(Routes.gameSetup(m.id));
}

/// The grid, split into its labelled bands. Sections render as slivers so the
/// whole thing is one scroll view — headers never cause nested scrolling.
class _SectionedGrid extends ConsumerWidget {
  const _SectionedGrid({required this.sections, required this.onOpen});

  final List<(HomeSection, List<GameModule>)> sections;
  final void Function(GameModule) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(statsRepositoryProvider);
    // Only label the bands when more than one is showing — a filtered view down
    // to a single section doesn't need a header restating the chip.
    final labelled = sections.length > 1;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        for (final (section, games) in sections) ...[
          if (labelled)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: section == sections.first.$1 ? 0 : Insets.s5,
                  bottom: Insets.s3,
                ),
                child: Row(
                  children: [
                    Text(section.label.toUpperCase(),
                        style: DallyType.label
                            .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
                    const Spacer(),
                    // The Mental Math header carries the one control its six
                    // games share; there is no module screen behind it.
                    if (section == HomeSection.mentalMath)
                      const _DifficultyControl(),
                  ],
                ),
              ),
            ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Insets.s3,
              crossAxisSpacing: Insets.s3,
              mainAxisExtent: 132,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final m = games[i];
                return RepaintBoundary(
                  child: GameTile(
                    title: m.title,
                    glyphAsset: m.id,
                    vibe: m.vibeLabel,
                    passAndPlay: m.players.contains(PlayerMode.passAndPlay),
                    best: m.homeBestLabel(stats),
                    onTap: () => onOpen(m),
                  ),
                );
              },
              childCount: games.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: Gap(Insets.s5)),
      ],
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(width: 36, height: 38, child: Icon(icon, color: t.textMuted, size: 21)),
      ),
    );
  }
}

class _ThemeSwatchButton extends StatelessWidget {
  const _ThemeSwatchButton({required this.accent, required this.onTap});
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Change theme',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.border),
          ),
          child: Center(
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Mental Math difficulty control, opened from that section's header and
/// applied to all six drills at once. Bests are kept per level.
class _DifficultyControl extends ConsumerWidget {
  const _DifficultyControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final current = ref.watch(mathDifficultyProvider);
    return Semantics(
      button: true,
      label: 'Mental math difficulty',
      child: GestureDetector(
        onTap: () => _open(context, ref),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.label,
                style: DallyType.body.copyWith(fontSize: 12, color: t.accent)),
            const Gap.h(2),
            Icon(Icons.expand_more_rounded, size: 16, color: t.accent),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: t.border),
      ),
      builder: (sheetContext) {
        final t = sheetContext.tokens;
        final current = ref.read(mathDifficultyProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mental math difficulty',
                    style: DallyType.title.copyWith(color: t.textPrimary)),
                const SizedBox(height: 5),
                Text('Applies to all six drills. Bests are kept per level.',
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                const Gap(Insets.s4),
                for (final d in MathDifficulty.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.label,
                        style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                    trailing: d == current
                        ? Icon(Icons.check_rounded, size: 20, color: t.accent)
                        : null,
                    onTap: () {
                      ref.read(mathDifficultyProvider.notifier).select(d);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
