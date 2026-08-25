import 'package:flutter/foundation.dart';

import '../../../../core/util/dally_random.dart';
import 'cards.dart';

/// Where a card lives.
enum PileKind { stock, waste, foundation, tableau }

/// A card's address: which pile, and how deep in it.
@immutable
class CardRef {
  const CardRef(this.kind, this.pile, this.index);

  final PileKind kind;

  /// Which foundation (0–3) or tableau column (0–6). Always 0 for stock/waste.
  final int pile;

  /// Position within the pile, 0 at the bottom.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is CardRef && other.kind == kind && other.pile == pile && other.index == index;

  @override
  int get hashCode => Object.hash(kind, pile, index);
}

/// Klondike. Pure rules: deal, legality, foundations, recycling, win and
/// auto-complete, with no widget, clock or randomness of its own beyond the
/// [DallyRandom] used to shuffle.
class Solitaire {
  Solitaire({required DallyRandom random, this.drawCount = 1})
      : assert(drawCount == 1 || drawCount == 3) {
    final deck = shuffledDeck(random);
    var at = 0;
    for (var column = 0; column < columns; column++) {
      for (var i = 0; i <= column; i++) {
        tableau[column].add(deck[at++]);
      }
      // Only the last card of each column starts face up.
      faceUpFrom[column] = column;
    }
    stock.addAll(deck.sublist(at));
  }

  static const int columns = 7;

  /// 1 or 3. Draw-3 is the harder deal; both recycle the stock without limit.
  final int drawCount;

  final List<List<PlayingCard>> tableau =
      List.generate(columns, (_) => <PlayingCard>[]);

  /// Index of the first face-up card in each column; `length` means none.
  final List<int> faceUpFrom = List.filled(columns, 0);

  final List<List<PlayingCard>> foundations =
      List.generate(4, (_) => <PlayingCard>[]);

  final List<PlayingCard> stock = [];
  final List<PlayingCard> waste = [];

  int moves = 0;

  bool isFaceUp(int column, int index) => index >= faceUpFrom[column];

  bool get isWon => foundations.every((f) => f.length == 13);

  /// Every card is face up and the stock is spent — from here the rest of the
  /// game is mechanical, so [autoComplete] can finish it.
  bool get canAutoComplete {
    if (isWon) return false;
    if (stock.isNotEmpty || waste.isNotEmpty) return false;
    for (var c = 0; c < columns; c++) {
      if (faceUpFrom[c] > 0) return false;
    }
    return true;
  }

  // ── Drawing ───────────────────────────────────────────────────────────────

  /// Turns [drawCount] cards from the stock, or recycles the waste when the
  /// stock is empty. Returns false when there is nothing to do at all.
  bool draw() {
    if (stock.isEmpty) {
      if (waste.isEmpty) return false;
      stock.addAll(waste.reversed);
      waste.clear();
      moves++;
      return true;
    }
    for (var i = 0; i < drawCount && stock.isNotEmpty; i++) {
      waste.add(stock.removeLast());
    }
    moves++;
    return true;
  }

  // ── Legality ──────────────────────────────────────────────────────────────

  PlayingCard? cardAt(CardRef ref) {
    final pile = _pileOf(ref.kind, ref.pile);
    if (ref.index < 0 || ref.index >= pile.length) return null;
    return pile[ref.index];
  }

  List<PlayingCard> _pileOf(PileKind kind, int pile) => switch (kind) {
        PileKind.stock => stock,
        PileKind.waste => waste,
        PileKind.foundation => foundations[pile],
        PileKind.tableau => tableau[pile],
      };

  /// The cards that travel together when [from] is picked up. Only a face-up
  /// run in a tableau column moves as a unit; everywhere else it is one card.
  List<PlayingCard> movingCards(CardRef from) {
    final pile = _pileOf(from.kind, from.pile);
    if (from.index < 0 || from.index >= pile.length) return const [];
    if (from.kind != PileKind.tableau) {
      return from.index == pile.length - 1 ? [pile[from.index]] : const [];
    }
    if (!isFaceUp(from.pile, from.index)) return const [];
    final run = pile.sublist(from.index);
    for (var i = 1; i < run.length; i++) {
      if (!_stacks(run[i - 1], run[i])) return const [];
    }
    return run;
  }

  /// Tableau stacking: descending rank, alternating colour.
  static bool _stacks(PlayingCard under, PlayingCard over) =>
      under.rank == over.rank + 1 && under.isRed != over.isRed;

  bool canMove(CardRef from, PileKind toKind, int toPile) {
    final moving = movingCards(from);
    if (moving.isEmpty) return false;
    if (from.kind == toKind && from.pile == toPile) return false;

    switch (toKind) {
      case PileKind.foundation:
        if (moving.length != 1) return false;
        final card = moving.first;
        final target = foundations[toPile];
        if (target.isEmpty) return card.rank == 1;
        return target.last.suit == card.suit && target.last.rank == card.rank - 1;
      case PileKind.tableau:
        final target = tableau[toPile];
        // An empty column only takes a king — the rule that makes the game hard.
        if (target.isEmpty) return moving.first.rank == 13;
        return isFaceUp(toPile, target.length - 1) && _stacks(target.last, moving.first);
      case PileKind.stock:
      case PileKind.waste:
        return false;
    }
  }

  /// Applies the move if legal, flipping the card it uncovers. Returns false
  /// and changes nothing otherwise.
  bool move(CardRef from, PileKind toKind, int toPile) {
    if (!canMove(from, toKind, toPile)) return false;
    final source = _pileOf(from.kind, from.pile);
    final moving = source.sublist(from.index);
    source.removeRange(from.index, source.length);
    _pileOf(toKind, toPile).addAll(moving);

    if (from.kind == PileKind.tableau) {
      // Uncovering the column turns its new last card face up.
      faceUpFrom[from.pile] =
          source.isEmpty ? 0 : faceUpFrom[from.pile].clamp(0, source.length - 1);
    }
    if (toKind == PileKind.tableau && tableau[toPile].length == moving.length) {
      faceUpFrom[toPile] = 0;
    }
    moves++;
    return true;
  }

  /// The foundation index [card] belongs on — one per suit, always in place.
  int foundationFor(PlayingCard card) => card.suit.index;

  /// Where tapping [from] should send it: a foundation first, then the leftmost
  /// tableau column that takes it. Null when nothing accepts it.
  (PileKind, int)? autoTarget(CardRef from) {
    final moving = movingCards(from);
    if (moving.isEmpty) return null;
    if (moving.length == 1) {
      final f = foundationFor(moving.first);
      if (canMove(from, PileKind.foundation, f)) return (PileKind.foundation, f);
    }
    for (var c = 0; c < columns; c++) {
      if (canMove(from, PileKind.tableau, c)) return (PileKind.tableau, c);
    }
    return null;
  }

  /// Plays out a game that is already decided. Returns the moves it made, so
  /// the screen can animate them one at a time rather than snapping to a win.
  List<CardRef> autoComplete() {
    final played = <CardRef>[];
    var progress = true;
    while (progress && !isWon) {
      progress = false;
      for (var c = 0; c < columns; c++) {
        final column = tableau[c];
        if (column.isEmpty) continue;
        final ref = CardRef(PileKind.tableau, c, column.length - 1);
        final f = foundationFor(column.last);
        if (canMove(ref, PileKind.foundation, f)) {
          move(ref, PileKind.foundation, f);
          played.add(ref);
          progress = true;
        }
      }
    }
    return played;
  }
}
