import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_racer_screen.dart';

/// Racer — three lanes, a fixed car, and a spawner that always leaves one open.
class RacerModule extends GameModule {
  @override
  String get id => 'racer';

  @override
  String get title => 'Racer';

  @override
  String get tagline => 'Three lanes. Pick one, quickly.';

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
  List<String> get tags => const ['lanes', 'dodge', 'drive', 'distance', 'speed', 'arcade'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Furthest run',
          cell: StatCell.metric('Furthest run', agg.metric('score'), StatFormat.distance,
              higherIsBetter: true, accent: true),
        ),
        StatBlock.cells(cells: [
          StatCell.count('Runs', agg.sessions),
          StatCell.average('Average', agg.metric('score'), StatFormat.distance),
          StatCell.metric('Longest run', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.distance.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayRacerScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayRacerScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Change lane to get past what is coming. There is always one lane open.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'Your car. It never moves forward or back.'),
        HowToLegend(howToCell(t: t, hairline: true), 'A blocker. Outlined, like everything you must avoid.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a side',
            'Left half moves left, right half moves right — one lane at a time'),
        HowToStep(Icon(Icons.speed_rounded, size: 20, color: t.textMuted), 'The speed flattens',
            'A good run is long rather than endless'),
      ],
      tip: 'The moving lane dashes are the only cue for how fast you are going.',
    );
  }
}
