import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/player_identity.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/widgets/player_chip.dart';
import 'snakes_config.dart';
import 'ui/play_snakes_screen.dart';
import 'ui/setup_snakes_screen.dart';

/// Snakes & Ladders — pure luck, four seats, a fresh board every game.
class SnakesAndLaddersModule extends GameModule {
  @override
  String get id => 'snakes_and_ladders';

  @override
  String get title => 'Snakes & Ladders';

  @override
  String get tagline => 'Climb the ladders. Mind the snakes.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.party, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.board;

  @override
  PlayerCount get playerCount => PlayerCount.group;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags =>
      const ['dice', 'race', 'ladders', 'family', 'four player', 'luck', 'board'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        if (agg.sessions > 0)
          StatBlock.bars(
            title: 'Wins by seat',
            bars: [
              for (final seat in kPlayerIdentities)
                StatBar(seat.name, agg.metric('seat${seat.index + 1}Wins').count,
                    accent: seat.index == 0),
            ],
          ),
        StatBlock.cells(cells: [
          StatCell.count('Games', agg.sessions),
          StatCell.average('Average game', agg.metric('duration'), StatFormat.duration),
          StatCell.metric('Most climbs', agg.metric('climbs'), StatFormat.number,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds),
              earned: agg.seconds > 0),
        ]),
        for (final label in const ['6×6', '8×8', '10×10'])
          if (!agg.config(label).isEmpty)
            StatBlock.cells(title: label, cells: [
              StatCell.count('Games', agg.config(label).sessions),
              StatCell.average('Average game', agg.config(label).metric('duration'),
                  StatFormat.duration),
            ]),
      ];

  @override
  String? statSummary(GameAggregate agg) =>
      agg.sessions == 0 ? null : '${agg.sessions} played';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupSnakesScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySnakesScreen(moduleId: id, config: config as SnakesConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    final seats = identitiesFor(2);
    return HowToContent(
      goal: 'Be first to land exactly on the last square. There is nothing to '
          'decide — the board decides for you.',
      readingLabel: 'Reading the board',
      reading: [
        HowToLegend(PlayerMark(identity: seats[0], size: 16),
            'Your token. Squares run left, then right, then left again.'),
        HowToLegend(Icon(Icons.stairs_outlined, size: 18, color: t.textMuted),
            'A ladder: land on its foot and you climb to the top.'),
        HowToLegend(Icon(Icons.waves_rounded, size: 18, color: t.textMuted),
            'A snake: land on its head and you slide down to its tail.'),
      ],
      controls: [
        HowToStep(Icon(Icons.casino_outlined, size: 20, color: t.textMuted), 'Roll',
            'The turn passes on its own — there is no move to pick'),
      ],
      tip: 'Overshooting the last square leaves you where you are, so the very '
          'end of the board is often the slowest part.',
    );
  }
}
