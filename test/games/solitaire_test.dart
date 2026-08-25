import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/solitaire/logic/cards.dart';
import 'package:dally/features/games/solitaire/logic/solitaire.dart';
import 'package:flutter_test/flutter_test.dart';

Solitaire deal({int seed = 1, int drawCount = 1}) =>
    Solitaire(random: DallyRandom.seeded(seed), drawCount: drawCount);

/// Puts a known card on top of a tableau column, face up, with nothing under it.
void seedColumn(Solitaire s, int column, List<PlayingCard> cards) {
  s.tableau[column]
    ..clear()
    ..addAll(cards);
  s.faceUpFrom[column] = 0;
}

void main() {
  group('the deck', () {
    test('is 52 distinct cards', () {
      final deck = orderedDeck();
      expect(deck, hasLength(52));
      expect(deck.toSet(), hasLength(52));
    });

    test('shuffles deterministically from a seed', () {
      expect(shuffledDeck(DallyRandom.seeded(5)),
          shuffledDeck(DallyRandom.seeded(5)));
      expect(shuffledDeck(DallyRandom.seeded(5)),
          isNot(shuffledDeck(DallyRandom.seeded(6))));
    });
  });

  group('the deal', () {
    test('lays 28 cards in seven columns and leaves 24 in the stock', () {
      final s = deal();
      for (var c = 0; c < Solitaire.columns; c++) {
        expect(s.tableau[c], hasLength(c + 1));
        expect(s.isFaceUp(c, c), isTrue, reason: 'the last card of a column is up');
        if (c > 0) expect(s.isFaceUp(c, c - 1), isFalse);
      }
      expect(s.stock, hasLength(24));
      expect(s.waste, isEmpty);
      expect(s.foundations.every((f) => f.isEmpty), isTrue);
    });

    test('deals every card exactly once', () {
      final s = deal(seed: 9);
      final seen = <PlayingCard>{...s.stock, for (final c in s.tableau) ...c};
      expect(seen, hasLength(52));
    });

    test('the same seed deals the same game', () {
      expect(deal(seed: 4).tableau.toString(), deal(seed: 4).tableau.toString());
    });
  });

  group('stock and waste', () {
    test('draw-1 turns one card at a time', () {
      final s = deal();
      s.draw();
      expect(s.waste, hasLength(1));
      expect(s.stock, hasLength(23));
    });

    test('draw-3 turns three', () {
      final s = deal(drawCount: 3);
      s.draw();
      expect(s.waste, hasLength(3));
      expect(s.stock, hasLength(21));
    });

    test('an empty stock recycles the waste without limit', () {
      final s = deal();
      while (s.stock.isNotEmpty) {
        s.draw();
      }
      expect(s.waste, hasLength(24));
      expect(s.draw(), isTrue);
      expect(s.stock, hasLength(24));
      expect(s.waste, isEmpty);
    });

    test('an empty stock and an empty waste is not a move', () {
      final s = deal();
      s.stock.clear();
      expect(s.draw(), isFalse);
    });
  });

  group('tableau legality', () {
    test('a run only stacks descending and alternating in colour', () {
      final s = deal();
      seedColumn(s, 0, const [PlayingCard(8, Suit.spades)]);
      seedColumn(s, 1, const [PlayingCard(7, Suit.hearts)]);
      seedColumn(s, 2, const [PlayingCard(7, Suit.clubs)]);
      seedColumn(s, 3, const [PlayingCard(6, Suit.hearts)]);

      final red7 = const CardRef(PileKind.tableau, 1, 0);
      final black7 = const CardRef(PileKind.tableau, 2, 0);
      expect(s.canMove(red7, PileKind.tableau, 0), isTrue);
      expect(s.canMove(black7, PileKind.tableau, 0), isFalse,
          reason: 'same colour');
      expect(s.canMove(const CardRef(PileKind.tableau, 3, 0), PileKind.tableau, 0),
          isFalse, reason: 'wrong rank');
    });

    test('only a king moves to an empty column', () {
      final s = deal();
      seedColumn(s, 0, const []);
      seedColumn(s, 1, const [PlayingCard(13, Suit.spades)]);
      seedColumn(s, 2, const [PlayingCard(12, Suit.hearts)]);
      expect(s.canMove(const CardRef(PileKind.tableau, 1, 0), PileKind.tableau, 0),
          isTrue);
      expect(s.canMove(const CardRef(PileKind.tableau, 2, 0), PileKind.tableau, 0),
          isFalse);
    });

    test('a whole valid run travels together', () {
      final s = deal();
      seedColumn(s, 0, const [
        PlayingCard(9, Suit.hearts),
        PlayingCard(8, Suit.spades),
        PlayingCard(7, Suit.diamonds),
      ]);
      seedColumn(s, 1, const [PlayingCard(10, Suit.clubs)]);
      final head = const CardRef(PileKind.tableau, 0, 0);
      expect(s.movingCards(head), hasLength(3));
      expect(s.move(head, PileKind.tableau, 1), isTrue);
      expect(s.tableau[1], hasLength(4));
      expect(s.tableau[0], isEmpty);
    });

    test('a broken run does not move as a unit', () {
      final s = deal();
      seedColumn(s, 0, const [
        PlayingCard(9, Suit.hearts),
        PlayingCard(5, Suit.spades),
      ]);
      expect(s.movingCards(const CardRef(PileKind.tableau, 0, 0)), isEmpty);
    });

    test('a face-down card cannot be picked up', () {
      final s = deal();
      expect(s.movingCards(const CardRef(PileKind.tableau, 6, 0)), isEmpty);
    });

    test('uncovering a column turns its new top card face up', () {
      final s = deal();
      final column = 3;
      final top = CardRef(PileKind.tableau, column, s.tableau[column].length - 1);
      // Force a legal home for it.
      seedColumn(s, 0, [
        PlayingCard(s.tableau[column].last.rank + 1,
            s.tableau[column].last.isRed ? Suit.spades : Suit.hearts)
      ]);
      expect(s.move(top, PileKind.tableau, 0), isTrue);
      expect(s.isFaceUp(column, s.tableau[column].length - 1), isTrue);
    });
  });

  group('foundations', () {
    test('start with an ace and climb in suit', () {
      final s = deal();
      seedColumn(s, 0, const [PlayingCard(1, Suit.hearts)]);
      seedColumn(s, 1, const [PlayingCard(2, Suit.hearts)]);
      seedColumn(s, 2, const [PlayingCard(2, Suit.spades)]);
      const heartsPile = 0;
      expect(
          s.canMove(const CardRef(PileKind.tableau, 1, 0), PileKind.foundation, heartsPile),
          isFalse,
          reason: 'a two cannot open a foundation');
      expect(s.move(const CardRef(PileKind.tableau, 0, 0), PileKind.foundation, heartsPile),
          isTrue);
      expect(s.move(const CardRef(PileKind.tableau, 2, 0), PileKind.foundation, heartsPile),
          isFalse, reason: 'wrong suit');
      expect(s.move(const CardRef(PileKind.tableau, 1, 0), PileKind.foundation, heartsPile),
          isTrue);
      expect(s.foundations[heartsPile], hasLength(2));
    });

    test('a run never goes to a foundation', () {
      final s = deal();
      seedColumn(s, 0, const [PlayingCard(2, Suit.hearts), PlayingCard(1, Suit.spades)]);
      expect(s.canMove(const CardRef(PileKind.tableau, 0, 0), PileKind.foundation, 3),
          isFalse);
    });

    test('tapping sends a card to its foundation before any column', () {
      final s = deal();
      seedColumn(s, 0, const [PlayingCard(1, Suit.spades)]);
      expect(s.autoTarget(const CardRef(PileKind.tableau, 0, 0)),
          (PileKind.foundation, Suit.spades.index));
    });
  });

  group('finishing', () {
    test('a full board of foundations is a win', () {
      final s = deal();
      expect(s.isWon, isFalse);
      for (final suit in Suit.values) {
        s.foundations[suit.index]
            .addAll([for (var r = 1; r <= 13; r++) PlayingCard(r, suit)]);
      }
      expect(s.isWon, isTrue);
    });

    test('auto-complete is only offered once the game is decided', () {
      final s = deal();
      expect(s.canAutoComplete, isFalse, reason: 'the stock is still full');
      s.stock.clear();
      expect(s.canAutoComplete, isFalse, reason: 'columns are still face down');
      for (var c = 0; c < Solitaire.columns; c++) {
        s.faceUpFrom[c] = 0;
      }
      expect(s.canAutoComplete, isTrue);
    });

    test('auto-complete plays a decided game out to a win', () {
      final s = deal();
      // Lay the whole deck out in descending order, one suit per column pair.
      for (var c = 0; c < Solitaire.columns; c++) {
        seedColumn(s, c, const []);
      }
      s.stock.clear();
      var column = 0;
      for (final suit in Suit.values) {
        seedColumn(s, column, [for (var r = 13; r >= 1; r--) PlayingCard(r, suit)]);
        column++;
      }
      expect(s.canAutoComplete, isTrue);
      final played = s.autoComplete();
      expect(played, hasLength(52));
      expect(s.isWon, isTrue);
    });
  });
}
