import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/game_glyph.dart';
import 'game_2048_config.dart';
import 'ui/play_2048_screen.dart';
import 'ui/setup_2048_screen.dart';

/// 2048 — slide and merge on an N×N board. Single-player.
class Game2048Module extends GameModule {
  @override
  String get id => 'game_2048';

  @override
  String get title => '2048';

  @override
  String get tagline => 'Slide, merge, chase the big tile.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.brain;

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags => const ['tiles', 'merge', 'numbers', 'puzzle', 'slide'];

  @override
  bool get supportsSaveResume => true;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final score = agg.metric('score');
    final tile = agg.metric('bestTile');
    return [
      StatBlock.hero(
        title: 'Best score',
        cell: StatCell.metric('Best score', score, StatFormat.number,
            higherIsBetter: true, accent: true),
      ),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.metric('Best tile', tile, StatFormat.tile, higherIsBetter: true),
        StatCell.average('Average', score, StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${formatGrouped(best)}';
  }

  @override
  String? homeBestLabel(StatsRepository stats) {
    final score = stats.bestOf('$id.bestScore');
    return score == null ? null : 'Best ${formatGrouped(score)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      Setup2048Screen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      Play2048Screen(moduleId: id, config: config as Game2048Config);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    Widget tile(Color bg, String n, Color fg) => howToCell(
          t: t,
          color: bg,
          radius: 7,
          child: Text(n,
              style: DallyType.body
                  .copyWith(fontFamily: DallyType.mono, fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
        );
    return HowToContent(
      goal: 'Slide tiles to combine matching numbers. Reach the 2048 tile — '
          'then keep going for a higher score.',
      reading: [
        HowToLegend(tile(t.scale.first, '2', t.scaleForeground(t.scale.first)),
            'Two of the same number merge when they meet.'),
        HowToLegend(tile(t.accent, '2048', t.onAccent),
            'Make this tile to win. You can keep playing after.'),
      ],
      controls: [
        HowToStep(Icon(Icons.swipe_rounded, size: 20, color: t.textMuted), 'Swipe',
            'Every tile slides that way; a new one appears'),
      ],
    );
  }
}
