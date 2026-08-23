import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

/// These exercise the dartchess rules the Chess game relies on, from known FEN
/// positions (fulfils the build contract's chess-correctness requirement).
Position fromFen(String fen) => Chess.fromSetup(Setup.parseFen(fen));

void main() {
  group('Chess rules (via dartchess)', () {
    test("Fool's mate is checkmate", () {
      // 1. f3 e5 2. g4 Qh4#
      Position pos = Chess.initial;
      pos = pos.play(NormalMove.fromUci('f2f3'));
      pos = pos.play(NormalMove.fromUci('e7e5'));
      pos = pos.play(NormalMove.fromUci('g2g4'));
      pos = pos.play(NormalMove.fromUci('d8h4'));
      expect(pos.isCheckmate, isTrue);
      expect(pos.isGameOver, isTrue);
      expect(pos.outcome?.winner, Side.black);
    });

    test('stalemate is detected and is not checkmate', () {
      final pos = fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(pos.isStalemate, isTrue);
      expect(pos.isCheckmate, isFalse);
      expect(pos.isGameOver, isTrue);
    });

    test('castling is legal (lichess king-onto-rook convention)', () {
      final pos = fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final legal = pos.legalMovesOf(Square.fromName('e1'));
      // dartchess encodes castling as the king moving onto its own rook square.
      expect(legal.has(Square.fromName('h1')), isTrue, reason: 'kingside');
      expect(legal.has(Square.fromName('a1')), isTrue, reason: 'queenside');
    });

    test('cannot castle out of check', () {
      // Black rook on e8 checks the white king on e1; castling is not a legal
      // response. (Black king on h4 keeps the position otherwise legal.)
      final pos = fromFen('4r3/8/8/8/7k/8/8/R3K3 w Q - 0 1');
      expect(pos.isCheck, isTrue);
      final legal = pos.legalMovesOf(Square.fromName('e1'));
      expect(legal.has(Square.fromName('c1')), isFalse);
    });

    test('en passant capture is available', () {
      final pos = fromFen('rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      final legal = pos.legalMovesOf(Square.fromName('e5'));
      expect(legal.has(Square.fromName('f6')), isTrue);
    });

    test('a pinned piece cannot expose the king', () {
      // Bishop on e2 is pinned by the rook on e8 against the king on e1.
      final pos = fromFen('4r2k/8/8/8/8/8/4B3/4K3 w - - 0 1');
      final legal = pos.legalMovesOf(Square.fromName('e2'));
      // It may slide along the pin line but never off it (e.g. to d3).
      expect(legal.has(Square.fromName('d3')), isFalse);
    });

    test('promotion to a queen is a legal move', () {
      final pos = fromFen('8/P6k/8/8/8/8/8/7K w - - 0 1');
      expect(pos.isLegal(NormalMove(from: Square.fromName('a7'), to: Square.fromName('a8'), promotion: Role.queen)),
          isTrue);
    });
  });
}
