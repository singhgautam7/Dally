import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_jumper_screen.dart';

/// Jumper — auto-bounce, left/right only, platforms in fixed-gap bands.
class JumperModule extends GameModule {
  @override
  String get id => 'jumper';

  @override
  String get title => 'Jumper';

  @override
  String get tagline => 'Bounce up. Do not come down.';

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
  List<String> get tags => const ['jump', 'platform', 'climb', 'endless', 'height', 'arcade'];

  @override
  String get styleNoun => 'Blocks';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'blocks', label: 'Blocks', recommended: true),
        StyleOption(id: 'hairline', label: 'Hairline'),
        StyleOption(id: 'pixel', label: 'Pixel'),
  ];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Best height',
          cell: StatCell.metric('Best height', agg.metric('score'), StatFormat.number,
              higherIsBetter: true, accent: true),
        ),
        StatBlock.cells(cells: [
          StatCell.count('Runs', agg.sessions),
          StatCell.average('Average', agg.metric('score'), StatFormat.number),
          StatCell.metric('Longest run', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.number.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayJumperScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayJumperScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'You bounce on your own. Steer left and right so you keep landing on something.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'You. The bounce is automatic.'),
        HowToLegend(howToCell(t: t, hairline: true), 'A platform. The next one is always in reach.'),
      ],
      controls: [
        HowToStep(Icon(Icons.swipe_left_rounded, size: 20, color: t.textMuted), 'Hold a side',
            'Left half of the arena to go left, right half to go right'),
        HowToStep(Icon(Icons.flag_outlined, size: 20, color: t.textMuted), 'Best-run tick',
            'The accent mark on the right edge is your record height'),
      ],
      tip: 'Running off one side brings you back on the other.',
    );
  }
}
