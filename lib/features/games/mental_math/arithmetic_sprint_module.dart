import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_sprint_screen.dart';

/// Arithmetic Sprint — 60 seconds of arithmetic, range widening as you go.
class ArithmeticSprintModule extends GameModule {
  @override
  String get id => 'arithmetic_sprint';

  @override
  String get title => 'Arithmetic Sprint';

  @override
  String get tagline => 'As many as you can in sixty seconds.';

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
  List<String> get tags => const ['maths', 'arithmetic', 'speed', 'timed', 'sums', 'drill'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final blocks = <StatBlock>[
      StatBlock.hero(
        title: 'Best in 60 seconds',
        cell: StatCell.metric('Best', agg.metric('score'), StatFormat.number,
            higherIsBetter: true, accent: true),
      ),
      StatBlock.cells(cells: [
        StatCell.count('Rounds', agg.sessions),
        StatCell.average('Average', agg.metric('score'), StatFormat.number),
        StatCell.metric('Best streak', agg.metric('bestStreak'), StatFormat.number,
            higherIsBetter: true),
        StatCell.average('Response', agg.metric('responseMs'), StatFormat.millis),
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
      PlaySprintScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySprintScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Answer as many as you can in sixty seconds. A wrong answer costs your streak, never time.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'What you have typed so far.'),
        HowToLegend(howToCell(t: t, hairline: true), 'The timer bar, notched each time the range widens.'),
      ],
      controls: [
        HowToStep(Icon(Icons.dialpad_rounded, size: 20, color: t.textMuted), 'Type the answer',
            'It submits itself when the length can only be one thing'),
        HowToStep(Icon(Icons.check_rounded, size: 20, color: t.textMuted), 'Tick to confirm',
            'For longer answers, where the length is ambiguous'),
      ],
      tip: 'Difficulty is set once on home and applies to all six drills.',
    );
  }
}
