import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_sequence_screen.dart';

/// Sequence — spot the rule and give the next value. Difficulty is the rule family, not bigger numbers.
class SequenceModule extends GameModule {
  @override
  String get id => 'sequence';

  @override
  String get title => 'Sequence';

  @override
  String get tagline => 'What comes next?';

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
  List<String> get tags => const ['maths', 'sequence', 'pattern', 'next', 'series', 'rule'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final blocks = <StatBlock>[
      StatBlock.hero(
        title: 'Best round',
        cell: StatCell.metric('Right', agg.metric('score'), StatFormat.number,
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
      PlaySequenceScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySequenceScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Four numbers follow a rule. Give the fifth.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'A term you can see.'),
        HowToLegend(howToCell(t: t, color: t.accent), 'The slot you are filling.'),
      ],
      controls: [
        HowToStep(Icon(Icons.dialpad_rounded, size: 20, color: t.textMuted), 'Type the value',
            'The ± key handles sequences that run downwards'),
        HowToStep(Icon(Icons.lightbulb_outline_rounded, size: 20, color: t.textMuted), 'A miss names the rule',
            'So the summary tells you what you were looking for'),
      ],
      tip: 'Easy is one operation, Normal two mixed, Hard two runs woven together.',
    );
  }
}
