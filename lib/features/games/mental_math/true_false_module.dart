import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_true_false_screen.dart';

/// True / False — twenty statements, wrong ones off by a plausible margin.
class TrueFalseModule extends GameModule {
  @override
  String get id => 'true_false';

  @override
  String get title => 'True / False';

  @override
  String get tagline => 'Is that sum right? Two seconds to decide.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.mentalMath, Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.mentalMath;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['maths', 'true', 'false', 'check', 'quick', 'drill'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final blocks = <StatBlock>[
      StatBlock.hero(
        title: 'Best streak',
        cell: StatCell.metric('Best streak', agg.metric('bestStreak'), StatFormat.number,
            higherIsBetter: true, accent: true),
      ),
      StatBlock.cells(cells: [
        StatCell.count('Rounds', agg.sessions),
        StatCell.metric('Accuracy', agg.metric('accuracy'), StatFormat.percent,
            higherIsBetter: true),
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
          StatCell.metric('Best score', c.metric('score'), StatFormat.number,
              higherIsBetter: true, accent: true),
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
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.number.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayTrueFalseScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayTrueFalseScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Twenty statements. Say whether each one is right. Wrong ones are off by a little, never absurd.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'A tick you got right, in the strip above the buttons.'),
        HowToLegend(howToCell(t: t, hairline: true), 'One you missed.'),
      ],
      controls: [
        HowToStep(Icon(Icons.check_rounded, size: 20, color: t.textMuted), 'True',
            'The statement as written is correct'),
        HowToStep(Icon(Icons.close_rounded, size: 20, color: t.textMuted), 'False',
            'Something about it is off'),
      ],
      tip: 'The wrong ones are usually off by one, or have two digits swapped.',
    );
  }
}
