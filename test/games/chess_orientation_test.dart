import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:dally/features/games/chess/chess_config.dart';
import 'package:dally/features/games/chess/ui/chess_pieces.dart';
import 'package:dally/features/games/chess/ui/play_chess_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// "Flip board each turn" and "Face-to-face" are two answers to the same
/// problem, and the design is explicit that they do not compose: face-to-face
/// "replaces the flip rather than adding to it — the board never moves, only
/// the glyphs". The play screen used to treat them as the same flag, so turning
/// on face-to-face spun the board on every move: exactly what a phone lying
/// flat between two players must never do.
void main() {
  /// A saved game with **Black to move**, so orientation is observable without
  /// simulating a move. Saved under no-clock, matching the configs below.
  Map<String, Object> blackToMove() => {
        'flutter.save.chess': jsonEncode({
          'schemaVersion': 1,
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

  ChessConfig config({bool flip = false, bool faceToFace = false}) => ChessConfig(
        time: ChessTime.none,
        player1Side: ChessSide.white,
        flipEachTurn: flip,
        faceToFace: faceToFace,
        legalDots: true,
      );

  /// Vertical centre of a side's king on screen.
  double kingY(WidgetTester tester, Side side) {
    for (final e in find.byType(PieceGlyph).evaluate()) {
      final g = e.widget as PieceGlyph;
      if (g.piece.color == side && g.piece.role == Role.king) {
        return tester.getCenter(find.byWidget(g)).dy;
      }
    }
    throw StateError('no $side king on the board');
  }

  /// How many pieces are drawn upside down.
  int rotatedGlyphs(WidgetTester tester) => find
      .ancestor(of: find.byType(PieceGlyph), matching: find.byType(Transform))
      .evaluate()
      .where((e) {
        final t = e.widget as Transform;
        // A 180° rotation negates both diagonal terms of the 2D basis.
        return (t.transform.storage[0] + 1).abs() < 0.001 &&
            (t.transform.storage[5] + 1).abs() < 0.001;
      })
      .length;

  testWidgets('face-to-face never moves the board', (tester) async {
    await pumpGameScreen(
        tester,
        PlayChessScreen(moduleId: 'chess', config: config(faceToFace: true)),
        prefs: blackToMove());
    await tester.pump();

    // Black is to move. With face-to-face the board must still be drawn from
    // White's side — Player 1's — exactly as it is at move one.
    expect(kingY(tester, Side.white), greaterThan(kingY(tester, Side.black)),
        reason: 'White stays at the bottom; the phone is flat on the table');
  });

  testWidgets('flip-each-turn does move the board', (tester) async {
    await pumpGameScreen(
        tester,
        PlayChessScreen(moduleId: 'chess', config: config(flip: true)),
        prefs: blackToMove());
    await tester.pump();

    expect(kingY(tester, Side.black), greaterThan(kingY(tester, Side.white)),
        reason: 'Black is to move, so Black comes to the bottom');
  });

  testWidgets('face-to-face rotates the far side\'s glyphs, and only those',
      (tester) async {
    await pumpGameScreen(
        tester,
        PlayChessScreen(moduleId: 'chess', config: config(faceToFace: true)),
        prefs: blackToMove());
    await tester.pump();
    expect(rotatedGlyphs(tester), 16,
        reason: 'the opposite player reads their own sixteen upright');
  });

  testWidgets('no rotation when face-to-face is off', (tester) async {
    await pumpGameScreen(
        tester, PlayChessScreen(moduleId: 'chess', config: config()),
        prefs: blackToMove());
    await tester.pump();
    expect(rotatedGlyphs(tester), 0);
  });
}
