import 'package:dally/core/theme/palettes.dart';
import 'package:dally/features/games/chess/chess_config.dart';
import 'package:dally/features/games/chess/ui/play_chess_screen.dart';
import 'package:dally/features/games/dots_and_boxes/dots_config.dart';
import 'package:dally/features/games/dots_and_boxes/ui/play_dots_screen.dart';
import 'package:dally/features/games/game_2048/game_2048_config.dart';
import 'package:dally/features/games/game_2048/ui/play_2048_screen.dart';
import 'package:dally/features/games/mafia/logic/mafia_word_pair.dart';
import 'package:dally/features/games/mafia/mafia_config.dart';
import 'package:dally/features/games/mafia/ui/play_mafia_screen.dart';
import 'package:dally/features/games/memory/memory_config.dart';
import 'package:dally/features/games/memory/ui/play_memory_screen.dart';
import 'package:dally/features/games/snake/snake_config.dart';
import 'package:dally/features/games/snake/ui/play_snake_screen.dart';
import 'package:dally/features/games/sudoku/logic/sudoku.dart';
import 'package:dally/features/games/sudoku/sudoku_config.dart';
import 'package:dally/features/games/sudoku/ui/play_sudoku_screen.dart';
import 'package:dally/features/games/tic_tac_toe/tic_tac_toe_config.dart';
import 'package:dally/features/games/tic_tac_toe/ui/play_tic_tac_toe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Every palette, on the smallest phone the app supports.
///
/// "Verified in all eight themes" is otherwise a claim nobody can re-check.
/// This renders a screen from each family that the v3 audit touched — the two
/// migrated onto the shared shells, the ones that gained motion, and the ones
/// with the densest chrome — in each of the eight palettes at 320×568, and
/// fails on any exception, including a `RenderFlex` overflow.
///
/// It cannot see whether a colour *reads* well; that stays a human job. What it
/// does hold is that no palette makes a screen throw, clip or fail to lay out —
/// which is what actually broke in the past, on AMOLED and on the light ones.
void main() {
  final screens = <String, Widget Function()>{
    'Dots & Boxes': () => const PlayDotsScreen(
          moduleId: 'dots_and_boxes',
          config: DotsConfig(
              size: 4, playerOne: 'Ana', playerTwo: 'Ben', firstPlayer: 0),
        ),
    'Mafia': () => const PlayMafiaScreen(
          moduleId: 'mafia',
          config: MafiaConfig(
            names: ['Ana', 'Ben', 'Cass'],
            difficulty: MafiaDifficulty.normal,
            voting: MafiaVoting.open,
          ),
        ),
    'Sudoku': () => const PlaySudokuScreen(
          moduleId: 'sudoku',
          config: SudokuConfig(difficulty: SudokuDifficulty.beginner),
        ),
    'Memory': () => const PlayMemoryScreen(
          moduleId: 'memory',
          config: MemoryConfig(rows: 4, cols: 3),
        ),
    'Snake': () => const PlaySnakeScreen(
          moduleId: 'snake',
          config: SnakeConfig(
              arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: false),
        ),
    '2048': () => const Play2048Screen(
          moduleId: 'game_2048',
          config: Game2048Config(size: 4),
        ),
    'Tic-tac-toe': () => const PlayTicTacToeScreen(
          moduleId: 'tic_tac_toe',
          config: TicTacToeConfig(size: 3, winLength: 3, firstPlayer: 1),
        ),
    'Chess': () => const PlayChessScreen(
          moduleId: 'chess',
          config: ChessConfig(
            time: ChessTime.none,
            player1Side: ChessSide.white,
            flipEachTurn: false,
            faceToFace: false,
            legalDots: true,
          ),
        ),
  };

  for (final palette in DallyPalettes.all) {
    group('the ${palette.id} palette', () {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} lays out on a 320×568 phone', (tester) async {
          await pumpGameScreen(
            tester,
            entry.value(),
            size: const Size(320, 568),
            paletteId: palette.id,
          );
          // Two more frames: Sudoku generates its puzzle off the first frame,
          // and the skeleton it shows until then is not what we came to check.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          // Unmount so any ticker or timer the screen started is disposed.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
        });
      }
    });
  }

  testWidgets('the pause sheet fits every palette on the smallest phone',
      (tester) async {
    for (final palette in DallyPalettes.all) {
      await pumpGameScreen(
        tester,
        const PlaySnakeScreen(
          moduleId: 'snake',
          config: SnakeConfig(
              arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: false),
        ),
        size: const Size(320, 568),
        paletteId: palette.id,
      );
      // Snake's sheet is the longest in the app — style, on-screen controls and
      // D-pad position on top of the standard rows. It scrolls rather than
      // clipping "Resume", and that has to hold in every palette.
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: palette.id);
      await tester.ensureVisible(find.text('Resume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
