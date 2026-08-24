import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_missing_operator_screen.dart';

/// Missing Operator — one omitted sign (two on Hard), always with a unique answer.
class MissingOperatorModule extends GameModule {
  @override
  String get id => 'missing_operator';

  @override
  String get title => 'Missing Operator';

  @override
  String get tagline => 'Which sign makes it true?';

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
  List<String> get tags => const ['maths', 'operator', 'signs', 'equation', 'drill'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final blocks = <StatBlock>[
      StatBlock.hero(
        title: 'Best first-try run',
        cell: StatCell.metric('Best', agg.metric('score'), StatFormat.number,
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
      PlayMissingOperatorScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayMissingOperatorScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Pick the sign that makes the equation true. Only one ever does.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true, child: Text('?',
            style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 16, color: t.accent))),
            'The slot. The only accent on screen.'),
        HowToLegend(howToCell(t: t, color: t.danger), 'A key you got wrong — it stays tapped out.'),
      ],
      controls: [
        HowToStep(Icon(Icons.grid_view_rounded, size: 20, color: t.textMuted), 'Four fixed keys',
            'Always + − × ÷ in that order, so the positions are learnable'),
        HowToStep(Icon(Icons.filter_2_rounded, size: 20, color: t.textMuted), 'Two slots on Hard',
            'Both have to be right before it moves on'),
      ],
      tip: 'A wrong pick tints the key, never the equation.',
    );
  }
}
