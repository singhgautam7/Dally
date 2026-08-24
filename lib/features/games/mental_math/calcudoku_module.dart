import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_calcudoku_screen.dart';

/// Calcudoku — a Latin square with arithmetic cages, generated with a verified unique solution.
class CalcudokuModule extends GameModule {
  @override
  String get id => 'calcudoku';

  @override
  String get title => 'Calcudoku';

  @override
  String get tagline => 'Latin square, with arithmetic cages.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.mentalMath, Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.mentalMath;

  @override
  GameLength get typicalLength => GameLength.long;

  @override
  List<String> get tags => const ['maths', 'grid', 'cages', 'latin square', 'logic', 'puzzle'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final blocks = <StatBlock>[
      StatBlock.hero(
        title: 'Best time',
        cell: StatCell.metric('Best time', agg.metric('score'), StatFormat.duration,
            higherIsBetter: false, accent: true),
      ),
      StatBlock.cells(cells: [
        StatCell.count('Solved', agg.outcomes['solved'] ?? 0),
        StatCell.average('Average', agg.metric('score'), StatFormat.duration),
        StatCell.average('Mistakes', agg.metric('mistakes'), StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
    ];
    // One card per difficulty, from the per-config rollup. Bests are kept per
    // level, so raising the difficulty never overwrites an easier record.
    for (final level in const ['Easy', 'Normal', 'Hard']) {
      final c = agg.config(level);
      if (c.isEmpty) {
        blocks.add(StatBlock.waiting(title: level, waitingFor: 'Not played at this level yet.'));
      } else {
        blocks.add(StatBlock.cells(title: level, cells: [
          StatCell.metric('Best time', c.metric('score'), StatFormat.duration,
              higherIsBetter: false, accent: true),
          StatCell.count('Rounds', c.sessions),
          StatCell.metric('Accuracy', c.metric('accuracy'), StatFormat.percent,
              higherIsBetter: true),
        ]));
      }
    }
    return blocks;
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: false);
    return best == null ? null : 'Best ${StatFormat.duration.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayCalcudokuScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayCalcudokuScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Fill the grid so every row and column holds each number once, and every cage hits its target.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'A cage — one heavier outline, target in its top-left cell.'),
        HowToLegend(howToCell(t: t, color: t.danger), 'Two cells that disagree, flagged once both are filled.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a cell, then a number',
            'Tapping the same number again clears it'),
        HowToStep(Icon(Icons.edit_outlined, size: 20, color: t.textMuted), 'Notes',
            'Pencil in the candidates while you work'),
      ],
      tip: 'A cage marked − or ÷ states a difference or a ratio, so the order inside it does not matter.',
    );
  }
}
