import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_avoider_screen.dart';

/// Avoider — a square on a hairline, a tap to jump, and a generator that always leaves a landing gap.
class AvoiderModule extends GameModule {
  @override
  String get id => 'avoider';

  @override
  String get title => 'Avoider';

  @override
  String get tagline => 'One line, one jump, no excuses.';

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
  List<String> get tags => const ['jump', 'dodge', 'run', 'obstacles', 'distance', 'arcade'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Furthest run',
          cell: StatCell.metric('Furthest run', agg.metric('score'), StatFormat.metres,
              higherIsBetter: true, accent: true),
        ),
        StatBlock.cells(cells: [
          StatCell.count('Runs', agg.sessions),
          StatCell.average('Average', agg.metric('score'), StatFormat.metres),
          StatCell.metric('Longest run', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.metres.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayAvoiderScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayAvoiderScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Jump the obstacles. They speed up every 250 metres, and past a kilometre they come in pairs.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'You. Solid, like every player in the arcade.'),
        HowToLegend(howToCell(t: t, hairline: true), 'An obstacle. There is always room to land between them.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap to jump',
            'Anywhere in the arena. No double jumps'),
        HowToStep(Icon(Icons.straighten_rounded, size: 20, color: t.textMuted), 'Distance is the score',
            'It is the only thing tracked'),
      ],
      tip: 'The gap between obstacles is never shorter than one full jump.',
    );
  }
}
