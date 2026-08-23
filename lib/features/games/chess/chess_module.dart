import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'chess_config.dart';
import 'ui/chess_pieces.dart';
import 'ui/play_chess_screen.dart';
import 'ui/setup_chess_screen.dart';

/// Chess — pass-and-play PvP, full rules (dartchess), no engine in v1.
class ChessModule extends GameModule {
  @override
  String get id => 'chess';

  @override
  String get title => 'Chess';

  @override
  String get tagline => 'Full rules, pass-and-play.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser};

  @override
  bool get supportsSaveResume => true;

  @override
  List<StatSpec> get statSpecs => const [
        StatSpec(key: 'gamesPlayed', label: 'Games played', format: StatFormat.number, higherIsBetter: true),
      ];

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'classic', label: 'Classic'),
        StyleOption(id: 'outline', label: 'Outline'),
        StyleOption(id: 'minimal', label: 'Minimal'),
        StyleOption(id: 'letters', label: 'Letters'),
      ];

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupChessScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayChessScreen(moduleId: id, config: config as ChessConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    Widget square(Color tint, {Widget? child}) => howToCell(
        t: t, color: Color.alphaBlend(tint, t.chessLightSquare), radius: 4, child: child);
    Widget piece(Role role) => SizedBox(
          width: 28,
          height: 28,
          child: PieceGlyph(
              piece: Piece(color: Side.white, role: role), style: PieceStyle.classic, size: 28),
        );
    return HowToContent(
      goal: 'Trap the other king with no legal escape. '
          'Two players, one phone — Dally has no engine.',
      reading: [
        HowToLegend(square(t.selectedTint, child: piece(Role.knight)),
            'Picked up. Tap it again to put it down.'),
        HowToLegend(
          square(const Color(0x00000000), child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: t.moveHint, shape: BoxShape.circle),
          )),
          'A square it can move to.',
        ),
        HowToLegend(
          square(const Color(0x00000000), child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.moveHint, width: 2)),
          )),
          'A piece it can take.',
        ),
        HowToLegend(
          square(t.danger.withValues(alpha: 0.4), child: piece(Role.king)),
          'Your king is in check. Get out of it.',
        ),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap, then tap',
            'Pick a piece, then its square. No dragging needed.'),
        HowToStep(Icon(Icons.screen_rotation_rounded, size: 20, color: t.textMuted),
            'The board turns itself',
            "Flip after each move, or face-to-face if the phone's flat"),
        HowToStep(Icon(Icons.history_rounded, size: 20, color: t.textMuted), 'Move history',
            'Every move is listed above the board'),
      ],
      tip: 'Castling, en passant and promotion all work. Only legal moves get a '
          "marker, so illegal ones simply won't show.",
    );
  }
}
