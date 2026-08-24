import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_reaction_screen.dart';

/// Reaction — five attempts make a set, and the set average is the record.
class ReactionModule extends GameModule {
  @override
  String get id => 'reaction';

  @override
  String get title => 'Reaction';

  @override
  String get tagline => 'Five taps. The average is the score.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.reflex, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.arcade;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['reaction', 'reflex', 'speed', 'tap', 'time', 'arcade'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Best set average',
          cell: StatCell.metric('Best set average', agg.metric('score'), StatFormat.millis,
              higherIsBetter: false, accent: true),
        ),
        StatBlock.cells(cells: [
          StatCell.count('Runs', agg.sessions),
          StatCell.average('Average', agg.metric('score'), StatFormat.millis),
          StatCell.metric('Longest run', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: false);
    return best == null ? null : 'Best ${StatFormat.millis.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayReactionScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayReactionScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'The arena fills after one to five seconds. Tap it as fast as you can. Five attempts make a set.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'The arena is live — tap now.'),
        HowToLegend(howToCell(t: t, hairline: true), 'Still waiting. Tapping now loses the attempt.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap the arena',
            'The label under it always says what state you are in'),
        HowToStep(Icon(Icons.functions_rounded, size: 20, color: t.textMuted), 'The average counts',
            'One lucky tap will not carry a set'),
      ],
      tip: 'An early tap costs that attempt only — the set carries on.',
    );
  }
}
