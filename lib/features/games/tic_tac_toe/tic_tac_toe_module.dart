import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/widgets/game_glyph.dart';
import 'tic_tac_toe_config.dart';
import 'ui/play_tic_tac_toe_screen.dart';
import 'ui/setup_tic_tac_toe_screen.dart';

/// Tic-tac-toe — pass-and-play, configurable board and win length.
class TicTacToeModule extends GameModule {
  @override
  String get id => 'tic_tac_toe';

  @override
  String get title => 'Tic-tac-toe';

  @override
  String get tagline => 'Three in a row, pass and play.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.leisure};

  @override
  GameCategory get category => GameCategory.classic;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['noughts', 'crosses', 'grid', 'three in a row', 'two player'];

  @override
  bool get supportsSaveResume => false;



  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final w = agg.outcome(SessionOutcome.won);
    final l = agg.outcome(SessionOutcome.lost);
    final d = agg.outcome(SessionOutcome.drawn);
    return [
      if (w + l + d > 0)
        StatBlock.bars(title: 'Results', bars: [
          StatBar('Player 1', w, accent: true),
          StatBar('Player 2', l),
          StatBar('Drawn', d),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.count('Drawn', d),
        StatCell.average('Average game', agg.metric('duration'), StatFormat.duration),
      ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) =>
      agg.sessions == 0 ? null : '\${agg.outcome(SessionOutcome.won)} / \${agg.outcome(SessionOutcome.lost)} / \${agg.outcome(SessionOutcome.drawn)}';
  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupTicTacToeScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayTicTacToeScreen(moduleId: id, config: config as TicTacToeConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    Widget mark(IconData icon, Color c) =>
        howToCell(t: t, color: t.surfaceAlt, radius: 7, child: Icon(icon, size: 20, color: c));
    return HowToContent(
      goal: 'Take turns marking squares. Get three of yours in a row — across, '
          'down or diagonally — to win.',
      reading: [
        HowToLegend(mark(Icons.close_rounded, t.accent), 'Player one.'),
        HowToLegend(mark(Icons.circle_outlined, t.textMuted), 'Player two.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a square',
            'Claim any empty square'),
      ],
    );
  }
}
