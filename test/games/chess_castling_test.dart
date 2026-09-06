import 'package:dally/features/games/chess/chess_config.dart';
import 'package:dally/features/games/chess/logic/chess_moves.dart';
import 'package:dally/features/games/chess/ui/play_chess_screen.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// dartchess encodes castling as **king onto its own rook**, so the legal set
/// carries h1/a1. Drawing that told the player to take their own rook, and the
/// only dot anywhere near the king's real destination was f1 — an ordinary
/// one-square move. The correct target was offered nowhere, and executing a
/// castle teleported both pieces.
void main() {
  Square sq(int file, int rank) => Square.fromCoords(File(file), Rank(rank));

  /// Both sides may castle both ways.
  Position open() => Chess.fromSetup(
      Setup.parseFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1'));

  group('the marked square is the king’s real destination', () {
    test('white, both sides available', () {
      final pos = open();
      final e1 = sq(4, 0);
      final legal = pos.legalMovesOf(e1);
      // What the encoding actually offers.
      expect(legal.has(sq(7, 0)), isTrue, reason: 'h1, the rook square');
      expect(legal.has(sq(0, 0)), isTrue, reason: 'a1, the rook square');

      final markers = castlingAwareMarkers(legal: legal, from: e1, isKing: true);
      expect(markers.has(sq(6, 0)), isTrue, reason: 'g1 — two files over');
      expect(markers.has(sq(2, 0)), isTrue, reason: 'c1 — two files over');
      expect(markers.has(sq(7, 0)), isFalse, reason: 'no dot on the rook');
      expect(markers.has(sq(0, 0)), isFalse, reason: 'no dot on the rook');
      // The ordinary king moves are untouched.
      expect(markers.has(sq(5, 0)), isTrue, reason: 'f1');
      expect(markers.has(sq(3, 0)), isTrue, reason: 'd1');
    });

    test('black, both sides available', () {
      final pos = open().play(NormalMove(from: sq(4, 1), to: sq(4, 3)));
      final e8 = sq(4, 7);
      final legal = pos.legalMovesOf(e8);
      final markers = castlingAwareMarkers(legal: legal, from: e8, isKing: true);
      expect(markers.has(sq(6, 7)), isTrue, reason: 'g8');
      expect(markers.has(sq(2, 7)), isTrue, reason: 'c8');
      expect(markers.has(sq(7, 7)), isFalse);
      expect(markers.has(sq(0, 7)), isFalse);
    });

    test('one side only, when only one is legal', () {
      // Queenside blocked by a bishop still on c1.
      final pos = Chess.fromSetup(
          Setup.parseFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R1B1K2R w KQkq - 0 1'));
      final markers = castlingAwareMarkers(
          legal: pos.legalMovesOf(sq(4, 0)), from: sq(4, 0), isKing: true);
      expect(markers.has(sq(6, 0)), isTrue, reason: 'kingside is still on');
      expect(markers.has(sq(2, 0)), isFalse, reason: 'queenside is not');
    });

    test('a king with no castling rights is left alone', () {
      final pos = Chess.fromSetup(
          Setup.parseFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1'));
      final legal = pos.legalMovesOf(sq(4, 0));
      expect(castlingAwareMarkers(legal: legal, from: sq(4, 0), isKing: true),
          legal);
    });

    test('nothing else is rewritten — a rook keeps its own moves', () {
      final pos = open();
      final legal = pos.legalMovesOf(sq(0, 0));
      expect(castlingAwareMarkers(legal: legal, from: sq(0, 0), isKing: false),
          legal);
    });
  });

  group('a castle moves two pieces, so it animates two', () {
    test('kingside: e1→g1 and h1→f1', () {
      expect(castlingSlides(kingFrom: sq(4, 0), rookFrom: sq(7, 0)), [
        (sq(4, 0), sq(6, 0)),
        (sq(7, 0), sq(5, 0)),
      ]);
    });

    test('queenside: e1→c1 and a1→d1', () {
      expect(castlingSlides(kingFrom: sq(4, 0), rookFrom: sq(0, 0)), [
        (sq(4, 0), sq(2, 0)),
        (sq(0, 0), sq(3, 0)),
      ]);
    });

    test('black gets the same, on its own rank', () {
      expect(castlingSlides(kingFrom: sq(4, 7), rookFrom: sq(7, 7)), [
        (sq(4, 7), sq(6, 7)),
        (sq(7, 7), sq(5, 7)),
      ]);
      expect(castlingSlides(kingFrom: sq(4, 7), rookFrom: sq(0, 7)), [
        (sq(4, 7), sq(2, 7)),
        (sq(0, 7), sq(3, 7)),
      ]);
    });

    test('the slides agree with what the rules actually do', () {
      for (final rook in [sq(7, 0), sq(0, 0)]) {
        final pos = open();
        final after = pos.play(NormalMove(from: sq(4, 0), to: rook));
        for (final (_, to) in castlingSlides(kingFrom: sq(4, 0), rookFrom: rook)) {
          expect(after.board.pieceAt(to), isNotNull,
              reason: 'nothing landed on ${to.name}');
        }
        final slides = castlingSlides(kingFrom: sq(4, 0), rookFrom: rook);
        expect(after.board.pieceAt(slides.first.$2)?.role, Role.king);
        expect(after.board.pieceAt(slides.last.$2)?.role, Role.rook);
      }
    });
  });

  group('the slide interpolation is progress-driven, never clock-driven', () {
    const from = Offset(0, 0);
    const to = Offset(100, 40);

    test('0 draws it at the start, 1 at the destination', () {
      expect(slideOffset(from: from, to: to, progress: 0), to * -1);
      expect(slideOffset(from: from, to: to, progress: 1), Offset.zero);
    });

    test('the same progress always gives the same frame', () {
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(slideOffset(from: from, to: to, progress: p),
            slideOffset(from: from, to: to, progress: p));
      }
    });

    test('it is linear in progress — no hidden time term', () {
      final half = slideOffset(from: from, to: to, progress: 0.5);
      final quarter = slideOffset(from: from, to: to, progress: 0.25);
      expect(quarter.dx, closeTo(half.dx * 1.5, 1e-9));
      expect(quarter.dy, closeTo(half.dy * 1.5, 1e-9));
    });

    test('out-of-range progress cannot overshoot', () {
      expect(slideOffset(from: from, to: to, progress: -3), to * -1);
      expect(slideOffset(from: from, to: to, progress: 9), Offset.zero);
    });
  });

  testWidgets('selecting the king offers g1 and c1 on the board', (tester) async {
    await pumpGameScreen(
      tester,
      const PlayChessScreen(
        moduleId: 'chess',
        config: ChessConfig(
          time: ChessTime.none,
          player1Side: ChessSide.white,
          flipEachTurn: false,
          faceToFace: false,
          legalDots: true,
        ),
      ),
      size: const Size(390, 844),
    );
    await tester.pump();
    // Clear the way: 1.Nf3 d5 2.g3 e5 3.Bg2 Nc6 leaves white able to castle.
    final board = tester.getRect(find.byType(AspectRatio).first);
    final cell = board.width / 8;
    Offset at(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
      return Offset(board.left + (file + 0.5) * cell,
          board.top + (7 - rank + 0.5) * cell);
    }

    Future<void> move(String from, String to) async {
      await tester.tapAt(at(from));
      await tester.pump();
      await tester.tapAt(at(to));
      await tester.pumpAndSettle();
    }

    await move('g1', 'f3');
    await move('d7', 'd5');
    await move('g2', 'g3');
    await move('e7', 'e5');
    await move('f1', 'g2');
    await move('b8', 'c6');

    await tester.tapAt(at('e1'));
    await tester.pump();
    // Tapping g1 — the square the marker now sits on — castles.
    await tester.tapAt(at('g1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('O-O'), findsWidgets,
        reason: 'the move list should record a castle');
  });

  test('a castle is written O-O, not as a king taking its own rook', () {
    // The move list used to read "Kxh1", because the encoding says the king
    // captures its own rook and nothing asked whether that was really true.
    expect(castlingSan(kingFrom: sq(4, 0), rookFrom: sq(7, 0)), 'O-O');
    expect(castlingSan(kingFrom: sq(4, 0), rookFrom: sq(0, 0)), 'O-O-O');
    expect(castlingSan(kingFrom: sq(4, 7), rookFrom: sq(7, 7)), 'O-O');
    expect(castlingSan(kingFrom: sq(4, 7), rookFrom: sq(0, 7)), 'O-O-O');
  });

  test('isCastling tells a castle from a capture', () {
    final pos = open();
    expect(isCastling(pos.board, sq(4, 0), sq(7, 0)), isTrue);
    expect(isCastling(pos.board, sq(4, 0), sq(0, 0)), isTrue);
    // A king next to an *enemy* rook is a capture, not a castle.
    final taking = Chess.fromSetup(Setup.parseFen('4k3/8/8/8/8/8/8/4Kr2 w - - 0 1'));
    expect(isCastling(taking.board, sq(4, 0), sq(5, 0)), isFalse);
    // An empty square is neither.
    expect(isCastling(pos.board, sq(4, 0), sq(4, 3)), isFalse);
  });

  testWidgets('castling slides the king and the rook, it does not teleport them',
      (tester) async {
    await pumpGameScreen(
      tester,
      const PlayChessScreen(
        moduleId: 'chess',
        config: ChessConfig(
          time: ChessTime.none,
          player1Side: ChessSide.white,
          flipEachTurn: false,
          faceToFace: false,
          legalDots: true,
        ),
      ),
      size: const Size(390, 844),
    );
    await tester.pump();
    final board = tester.getRect(find.byType(AspectRatio).first);
    final cell = board.width / 8;
    Offset at(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
      return Offset(
          board.left + (file + 0.5) * cell, board.top + (7 - rank + 0.5) * cell);
    }

    Future<void> move(String from, String to) async {
      await tester.tapAt(at(from));
      await tester.pump();
      await tester.tapAt(at(to));
      await tester.pumpAndSettle();
    }

    await move('g1', 'f3');
    await move('d7', 'd5');
    await move('g2', 'g3');
    await move('e7', 'e5');
    await move('f1', 'g2');
    await move('b8', 'c6');

    await tester.tapAt(at('e1'));
    await tester.pump();
    await tester.tapAt(at('g1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Mid-flight the board is animating *two* travels, not one — the king and
    // the rook. A teleporting rook would leave a single entry here.
    final boardWidget = tester.widget(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Board')) as dynamic;
    final slides = (boardWidget.slides as List).cast<(Square, Square)>();
    final progress = boardWidget.slideProgress as double;
    expect(slides.length, 2, reason: 'king and rook both travel');
    expect(progress, greaterThan(0));
    expect(progress, lessThan(1), reason: 'still in flight, not snapped home');

    // And they travel to the squares the rules put them on.
    expect(slides.map((s) => s.$2.name).toSet(), {'g1', 'f1'});
    expect(slides.map((s) => s.$1.name).toSet(), {'e1', 'h1'});

    await tester.pumpAndSettle();
    expect(find.textContaining('O-O'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
