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
import 'ludo_config.dart';
import 'ui/play_ludo_screen.dart';
import 'ui/setup_ludo_screen.dart';

/// Ludo — the Pachisi family. Four tokens a seat, one shared ring, pass-and-play.
class LudoModule extends GameModule {
  @override
  String get id => 'ludo';

  @override
  String get title => 'Ludo';

  @override
  String get tagline => 'Race four tokens home, send theirs back.';

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
  GameLength get typicalLength => GameLength.long;

  @override
  List<String> get tags =>
      const ['pachisi', 'dice', 'race', 'tokens', 'four player', 'board', 'family'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'pin', label: 'Pin', recommended: true),
        StyleOption(id: 'pawn', label: 'Pawn'),
        StyleOption(id: 'geometric', label: 'Geometric'),
      ];

  @override
  String get styleNoun => 'Token';

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    return [
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
        StatCell.metric('Most captures', agg.metric('captures'), StatFormat.number,
            higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      for (final label in const ['2 players', '3 players', '4 players'])
        if (!agg.config(label).isEmpty)
          StatBlock.cells(title: label, cells: [
            StatCell.count('Games', agg.config(label).sessions),
            StatCell.average('Average game', agg.config(label).metric('duration'),
                StatFormat.duration),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) =>
      agg.sessions == 0 ? null : '${agg.sessions} played';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupLudoScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayLudoScreen(moduleId: id, config: config as LudoConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    final seats = identitiesFor(4);
    return HowToContent(
      goal: 'Get all four of your tokens around the ring and into the middle. '
          'Land on an opponent and their token goes back to its yard.',
      readingLabel: 'Reading the board',
      reading: [
        HowToLegend(PlayerMark(identity: seats[0], size: 16),
            'Your seat: one colour and one shape, so it reads in any theme.'),
        HowToLegend(
            Icon(Icons.star_rounded, size: 18, color: t.textMuted),
            'A safe square — nothing can be captured while standing on one.'),
        HowToLegend(
            Icon(Icons.arrow_forward_rounded, size: 18, color: t.textMuted),
            'The tinted lane is your private home column. Only you enter it.'),
      ],
      controls: [
        HowToStep(Icon(Icons.casino_outlined, size: 20, color: t.textMuted), 'Roll',
            'A six is needed to bring a token out, and rolls again'),
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap a token', 'Only the tokens that can use the roll light up'),
      ],
      tip: 'The home square needs an exact count. Keep one token a few steps '
          'back so you always have something to move.',
    );
  }
}
