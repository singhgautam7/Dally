import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'frog_hop_config.dart';
import 'ui/play_frog_screen.dart';
import 'ui/setup_frog_screen.dart';

/// Frog Hop — a race down one lane. Two players pass and play; a solo puzzle
/// mode swaps the two blocks in as few moves as possible.
class FrogHopModule extends GameModule {
  @override
  String get id => 'frog_hop';

  @override
  String get title => 'Frog Hop';

  @override
  String get tagline => 'Step ahead, or hop over. First side across wins.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay, PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.leisure, Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.board;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags =>
      const ['leapfrog', 'lane', 'hop', 'jump', 'race', 'two player', 'puzzle'];

  @override
  bool get supportsSaveResume => false;

  @override
  String get styleNoun => 'Token';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'chip', label: 'Chip', recommended: true),
        StyleOption(id: 'pin', label: 'Pin'),
      ];

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final bottom = agg.outcome(SessionOutcome.won);
    final top = agg.outcome(SessionOutcome.lost);
    final drawn = agg.outcome(SessionOutcome.drawn);
    final puzzle = agg.metric('puzzleMoves');
    return [
      if (bottom + top + drawn > 0)
        StatBlock.bars(title: 'Series', bars: [
          StatBar('Bottom', bottom, accent: true),
          StatBar('Top', top),
          StatBar('Drawn', drawn),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Moves to win', agg.metric('moves'), StatFormat.number),
        StatCell.metric('Longest jump chain', agg.metric('longestChain'), StatFormat.number,
            higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      if (!puzzle.isEmpty)
        StatBlock.hero(
          title: 'Best puzzle solve',
          cell: StatCell.metric('Fewest moves', puzzle, StatFormat.number,
              higherIsBetter: false, accent: true),
        ),
      for (final n in const [3, 4, 5])
        if (!agg.config('Puzzle · $n a side').isEmpty)
          StatBlock.cells(title: 'Puzzle · $n a side', cells: [
            StatCell.count('Solves', agg.config('Puzzle · $n a side').sessions),
            StatCell.metric('Fewest moves',
                agg.config('Puzzle · $n a side').metric('puzzleMoves'), StatFormat.number,
                higherIsBetter: false),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) => agg.sessions == 0
      ? null
      : '${agg.outcome(SessionOutcome.won)} / ${agg.outcome(SessionOutcome.lost)}';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupFrogScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayFrogScreen(module: this, config: config as FrogHopConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Get every one of your pieces into the far end of the lane. Both '
          'goals are marked from the first move, in the colour of the side that '
          'has to reach them.',
      readingLabel: 'The two moves',
      reading: [
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.arrow_upward_rounded, size: 18, color: t.textMuted)),
          'Step: into the empty cell directly ahead.',
        ),
        HowToLegend(
          howToCell(t: t, color: t.accent, child: Icon(Icons.moving_rounded, size: 18, color: t.onAccent)),
          'Jump: over exactly one neighbour — either colour — into the empty cell beyond.',
        ),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap a piece', 'Its legal targets are drawn the moment you touch it'),
        HowToStep(Icon(Icons.undo_rounded, size: 20, color: t.textMuted), 'Undo',
            'Takes back one step or jump and hands the turn back'),
      ],
      tip: 'Nothing moves backwards and nothing is captured, so a side with no '
          'legal move simply passes — the strip under the lane says so.',
    );
  }
}
