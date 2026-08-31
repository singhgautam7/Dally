import 'dart:convert';

import 'package:dally/features/games/chess/chess_config.dart';
import 'package:dally/features/games/chess/ui/play_chess_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Continuing a saved chess game used to be able to end it instantly.
///
/// The save carries the clocks of the game it belongs to. A no-clock game saves
/// `whiteMs: 0`, and the play screen restored those numbers over the ones the
/// chosen time control had just set — so picking Blitz and tapping "Continue"
/// resumed a saved game with **zero seconds on both clocks**. White's first
/// tick after Black replied timed out, and the board announced "Black wins on
/// time" a move into a five-minute game.
void main() {
  /// A saved game one white move in, from a **no-clock** session.
  Map<String, Object> savedNoClockGame() => {
        'flutter.save.chess': jsonEncode({
          'schemaVersion': 1,
          // After 1. e4 — Black to move.
          'fen': 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          'history': ['e4'],
          'lastFrom': 12,
          'lastTo': 28,
          'whiteMs': 0,
          'blackMs': 0,
          'timeName': 'none',
          'p1White': true,
          'flipEachTurn': false,
          'faceToFace': false,
          'legalDots': true,
        }),
      };

  const blitz = ChessConfig(
    time: ChessTime.blitz,
    player1Side: ChessSide.white,
    flipEachTurn: false,
    faceToFace: false,
    legalDots: true,
  );

  const noClock = ChessConfig(
    time: ChessTime.none,
    player1Side: ChessSide.white,
    flipEachTurn: false,
    faceToFace: false,
    legalDots: true,
  );

  Widget screen(ChessConfig config) =>
      PlayChessScreen(moduleId: 'chess', config: config);

  testWidgets('a no-clock save is not resumed under a timed config',
      (tester) async {
    await pumpGameScreen(tester, screen(blitz), prefs: savedNoClockGame());
    await tester.pump();

    // The clocks must show the time control that was chosen, never the saved
    // game's zeroes.
    expect(find.textContaining('05:00'), findsWidgets,
        reason: 'a five-minute game starts with five minutes on the clock');
    expect(find.textContaining('wins on time'), findsNothing);
  });

  testWidgets('a mismatched save is discarded for a fresh board', (tester) async {
    await pumpGameScreen(tester, screen(blitz), prefs: savedNoClockGame());
    await tester.pump();
    // The saved game's one move must not carry into a game it doesn't belong
    // to — the position is the opening, not "after 1. e4".
    expect(find.textContaining('e4'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('wins on time'), findsNothing,
        reason: 'nobody flags two seconds into a five-minute game');
    expect(find.text('Rematch'), findsNothing, reason: 'the game is still live');
  });

  testWidgets('a matching save still resumes', (tester) async {
    // The same saved game, opened under the config it belongs to.
    await pumpGameScreen(tester, screen(noClock), prefs: savedNoClockGame());
    await tester.pump();
    // Its move history came back, so the position was genuinely restored.
    expect(find.textContaining('e4'), findsWidgets);
  });
}
