import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/widgets/game_glyph.dart';
import 'fifteen_config.dart';
import 'ui/play_fifteen_screen.dart';
import 'ui/setup_fifteen_screen.dart';

/// 15-puzzle — slide tiles into order. Single-player.
class FifteenPuzzleModule extends GameModule {
  @override
  String get id => 'fifteen_puzzle';

  @override
  String get title => '15-puzzle';

  @override
  String get tagline => 'Slide the tiles back into order.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.brain;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['slide', 'tiles', 'order', 'puzzle', 'sliding'];

  @override
  bool get supportsSaveResume => false;


  @override
  String? homeBestLabel(StatsRepository stats) {
    final m = stats.bestOf('$id.bestMoves');
    return m == null ? null : '${m.round()} moves';
  }


  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Solved', agg.outcome(SessionOutcome.solved)),
          StatCell.metric('Fewest moves', agg.metric('moves'), StatFormat.number,
              higherIsBetter: false, accent: true),
          StatCell.metric('Best time', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: false),
          StatCell.average('Average moves', agg.metric('moves'), StatFormat.number),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final m = agg.metric('moves').best(higherIsBetter: false);
    return m == null ? null : '\${m.round()} moves';
  }
  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupFifteenScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayFifteenScreen(moduleId: id, config: config as FifteenConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Slide the tiles until they read 1 to 15 in order, with the gap last.',
      reading: [
        HowToLegend(
          howToCell(t: t, color: t.surfaceAlt, radius: 7, child: Text('7',
              style: DallyType.body.copyWith(
                  fontFamily: DallyType.mono, fontWeight: FontWeight.w700, fontSize: 15, color: t.textPrimary))),
          'A tile. Slide it toward the gap.',
        ),
        HowToLegend(howToCell(t: t, color: t.surface, hairline: true, radius: 7),
            'The empty space everything slides into.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a tile',
            'Any tile next to the gap slides in'),
      ],
    );
  }
}
