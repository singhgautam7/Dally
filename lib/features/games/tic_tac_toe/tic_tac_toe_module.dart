import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
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
  bool get supportsSaveResume => false;

  @override
  List<StatSpec> get statSpecs => const [
        StatSpec(key: 'record', label: 'W / L / D', format: StatFormat.record, higherIsBetter: true),
      ];

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
