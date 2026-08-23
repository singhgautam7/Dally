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
import '../../../core/widgets/filter_chip_pill.dart';
import '../../../core/widgets/game_tile.dart';
import 'home_filter.dart';

/// Home = the games list. Registry-driven 2-column grid with Players + Vibe
/// filter chips. No bottom nav; Stats/Settings are pushed, the theme swatch is
/// the quick theme entry.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _playerLabel(PlayerMode p) =>
      p == PlayerMode.single ? 'Single-player' : 'Pass-and-play';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final filter = ref.watch(homeFilterProvider);
    final filtered = ref.watch(filteredGamesProvider);
    final players = ref.watch(availablePlayersProvider);
    final vibes = ref.watch(availableVibesProvider);
    final registry = ref.watch(gameRegistryProvider);
    final stats = ref.watch(statsRepositoryProvider);
    final accent = ref.watch(paletteProvider).accent;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar.
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
                  _TopIcon(icon: Icons.bar_chart_rounded, label: 'Stats', onTap: () => context.push(Routes.stats)),
                  const Gap.h(Insets.s2),
                  _TopIcon(icon: Icons.tune_rounded, label: 'Settings', onTap: () => context.push(Routes.settings)),
                  const Gap.h(Insets.s2),
                  _ThemeSwatchButton(accent: accent, onTap: () => context.push(Routes.theme)),
                ],
              ),
              const Gap(Insets.s4 + 2),
              // Filter chips.
              Wrap(
                spacing: Insets.s2,
                runSpacing: Insets.s2,
                children: [
                  for (final p in players)
                    FilterChipPill(
                      label: _playerLabel(p),
                      selected: filter.players.contains(p),
                      enabled: _playerEnabled(registry, filter, p),
                      onTap: () => ref.read(homeFilterProvider.notifier).togglePlayer(p),
                    ),
                  for (final v in vibes)
                    FilterChipPill(
                      label: v.label,
                      selected: filter.vibes.contains(v),
                      enabled: _vibeEnabled(registry, filter, v),
                      onTap: () => ref.read(homeFilterProvider.notifier).toggleVibe(v),
                    ),
                ],
              ),
              if (!filter.isEmpty) ...[
                const Gap(Insets.s3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} of ${registry.length} games',
                      style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
                    ),
                    Semantics(
                      button: true,
                      label: 'Clear filters',
                      child: GestureDetector(
                        onTap: () => ref.read(homeFilterProvider.notifier).clear(),
                        child: Text(
                          'Clear',
                          style: DallyType.bodyStrong.copyWith(fontSize: 12, color: t.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Gap(Insets.s4 + 2),
              // Grid.
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyResult(tokens: t)
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: Insets.s5),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Insets.s3,
                          crossAxisSpacing: Insets.s3,
                          mainAxisExtent: 132,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final m = filtered[i];
                          return RepaintBoundary(
                            child: GameTile(
                              title: m.title,
                              glyphAsset: m.id,
                              vibe: m.vibeLabel,
                              passAndPlay: m.players.contains(PlayerMode.passAndPlay),
                              best: m.homeBestLabel(stats),
                              onTap: () => context.push(Routes.gameSetup(m.id)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _playerEnabled(List<GameModule> reg, HomeFilterState f, PlayerMode p) {
    if (f.players.contains(p)) return true;
    return reg.any((m) =>
        m.players.contains(p) && (f.vibes.isEmpty || m.vibes.any(f.vibes.contains)));
  }

  bool _vibeEnabled(List<GameModule> reg, HomeFilterState f, Vibe v) {
    if (f.vibes.contains(v)) return true;
    return reg.any((m) =>
        m.vibes.contains(v) && (f.players.isEmpty || m.players.any(f.players.contains)));
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.tokens});
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined, color: t.textFaint, size: 34),
          const Gap(Insets.s3),
          Text('No games match', style: DallyType.bodyStrong.copyWith(color: t.textMuted)),
        ],
      ),
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
        child: SizedBox(width: 38, height: 38, child: Icon(icon, color: t.textMuted, size: 21)),
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
