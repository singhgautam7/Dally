import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_tower_screen.dart';

/// Tower Builder — a sweeping block, a tap to drop, and an overhang that is cut away.
class TowerBuilderModule extends GameModule {
  @override
  String get id => 'tower_builder';

  @override
  String get title => 'Tower Builder';

  @override
  String get tagline => 'Drop it straight, or lose the edges.';

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
  List<String> get tags => const ['stack', 'tower', 'timing', 'blocks', 'height', 'arcade'];

  @override
  String get styleNoun => 'Block';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'stack', label: 'Stack', recommended: true),
        StyleOption(id: 'girder', label: 'Girder'),
        StyleOption(id: 'slab', label: 'Slab'),
  ];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Tallest tower',
          cell: StatCell.metric('Tallest tower', agg.metric('score'), StatFormat.number,
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
      PlayTowerScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayTowerScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'A block sweeps the top. Tap to drop it. Whatever hangs over the edge is cut off.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'The block you are about to drop.'),
        HowToLegend(howToCell(t: t, hairline: true), 'The tower so far. It only ever narrows.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap to drop',
            'Anywhere in the arena'),
        HowToStep(Icon(Icons.auto_awesome_outlined, size: 20, color: t.textMuted), 'Three perfect drops',
            'Widen the block a step — the only accent flash in the game'),
      ],
      tip: 'The sweep speeds up every five floors.',
    );
  }
}
