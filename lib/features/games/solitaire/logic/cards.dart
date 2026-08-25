import 'package:flutter/foundation.dart';

import '../../../../core/util/dally_random.dart';

/// The four suits. Order is fixed: the two reds first, so `isRed` is one
/// comparison and the foundations always sit in the same order.
enum Suit { hearts, diamonds, clubs, spades }

extension SuitColour on Suit {
  bool get isRed => index < 2;

  /// The glyph drawn on the card. A shape, not licensed art.
  String get glyph => switch (this) {
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
        Suit.spades => '♠',
      };
}

/// One card. `rank` is 1 (ace) … 13 (king).
@immutable
class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  final int rank;
  final Suit suit;

  bool get isRed => suit.isRed;

  String get rankLabel => switch (rank) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '$rank',
      };

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '$rankLabel${suit.glyph}';
}

/// A fresh 52-card deck in a fixed order, ready to be shuffled by a seeded
/// [DallyRandom]. Building it in order and shuffling separately is what makes a
/// deal reproducible from a seed.
List<PlayingCard> orderedDeck() => [
      for (final suit in Suit.values)
        for (var rank = 1; rank <= 13; rank++) PlayingCard(rank, suit),
    ];

List<PlayingCard> shuffledDeck(DallyRandom random) =>
    random.shuffled(orderedDeck());
