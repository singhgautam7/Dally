import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/util/dally_random.dart';

/// A chute or a climb: step onto [from] and you end up on [to].
@immutable
class Link {
  const Link(this.from, this.to);

  final int from;
  final int to;

  bool get isLadder => to > from;

  @override
  bool operator ==(Object other) => other is Link && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// How many ladders and snakes a board of [squares] carries.
///
/// The 10×10 numbers come straight from the design — "7 ladders · 8 snakes" —
/// and the other sizes scale from the same density, so an 8×8 stays a
/// five-minute game and a 12×12 stays busy without becoming a cat's cradle.
({int ladders, int snakes}) linkCountsFor(int squares) => (
      ladders: (squares * 0.07).round().clamp(2, 14),
      snakes: (squares * 0.08).round().clamp(2, 16),
    );

/// Generates a board's links. Seeded, so a board is reproducible and every
/// generation rule is testable.
///
/// Guarantees, all of which a hand-placed board also has:
/// * every endpoint (foot, top, head, tail) is a distinct square, so no link
///   can ever chain into another and no single roll resolves twice;
/// * square 1 and the last square are never an endpoint;
/// * ordinary links span **two to four rows** — long enough to matter, short
///   enough that the board stays legible;
/// * exactly one **long snake** starts in the top row and drops the player back
///   into the first two rows. Every printed board has one, and without it the
///   last stretch has no teeth;
/// * ladders climb, snakes drop;
/// * the counts match [linkCountsFor].
List<Link> generateLinks(DallyRandom random, {required int columns, required int rows}) {
  final squares = columns * rows;
  final counts = linkCountsFor(squares);
  final used = <int>{1, squares};
  final links = <Link>[];

  /// Free squares in `[lowest, highest]`, in random order. Walking a shuffled
  /// pool rather than guessing is what lets the board actually reach its link
  /// count on a crowded 12×12 instead of quietly coming up short.
  List<int> pool(int lowest, int highest) => random.shuffled([
        for (var s = lowest; s <= highest; s++)
          if (!used.contains(s)) s,
      ]);

  // The long snake is placed first, so it always gets the room it needs: it
  // starts in the top row and drops the player back into the first two.
  var snakesLeft = counts.snakes;
  final heads = pool(squares - columns + 1, squares - 1);
  final tails = pool(2, math.min(squares - 1, columns * 2));
  if (heads.isNotEmpty && tails.isNotEmpty) {
    used
      ..add(heads.first)
      ..add(tails.first);
    links.add(Link(heads.first, tails.first));
    snakesLeft--;
  }

  // Ladders first: they are the ones players notice missing.
  for (final wantLadders in const [true, false]) {
    final want = wantLadders ? counts.ladders : snakesLeft;
    for (var i = 0; i < want; i++) {
      var placed = false;
      for (final low in pool(2, squares - columns - 1)) {
        final lowRow = (low - 1) ~/ columns;
        final minRow = lowRow + 2;
        if (minRow >= rows) continue;
        final maxRow = math.min(rows - 1, lowRow + 4);
        final highs = pool(minRow * columns + 1,
            math.min(squares - 1, (maxRow + 1) * columns));
        if (highs.isEmpty) continue;
        final high = highs.first;
        used
          ..add(low)
          ..add(high);
        links.add(wantLadders ? Link(low, high) : Link(high, low));
        placed = true;
        break;
      }
      // The board is full: stop rather than spin.
      if (!placed) break;
    }
  }
  links.sort((a, b) => a.from.compareTo(b.from));
  return links;
}

/// The result of one roll: where the token stepped to, and where the board then
/// sent it.
@immutable
class SnakesTurn {
  const SnakesTurn({
    required this.player,
    required this.face,
    required this.from,
    required this.landed,
    required this.link,
    required this.won,
  });

  final int player;
  final int face;
  final int from;

  /// Where the die alone put the token, before any link resolved.
  final int landed;

  /// The link the landing square triggered, or null.
  final Link? link;

  final bool won;

  int get to => link?.to ?? landed;
  bool get bounced => landed == from;
}

/// Snakes & Ladders — roll, walk, and let the board decide what it thinks of
/// where you stopped. Pure rules; the only randomness is the die handed in.
class SnakesAndLaddersGame {
  SnakesAndLaddersGame({
    required this.playerCount,
    required this.columns,
    required this.rows,
    required List<Link> links,
    int firstPlayer = 0,
  })  : assert(playerCount >= 2 && playerCount <= 4),
        _links = {for (final l in links) l.from: l},
        links = List.unmodifiable(links),
        current = firstPlayer,
        positions = List.filled(playerCount, 1);

  final int playerCount;
  final int columns;
  final int rows;
  final List<Link> links;
  final Map<int, Link> _links;

  /// Every token starts on square 1 rather than off-board: one fewer special
  /// case, and it is where players put them anyway.
  final List<int> positions;

  int current;
  int? winner;

  int get squares => columns * rows;
  bool get isFinished => winner != null;

  Link? linkAt(int square) => _links[square];

  /// Grid position of [square] as `(column, row)` counted from the **top-left**,
  /// which is how the painter wants it. Numbering boustrophedons from the
  /// bottom-left, the way every printed board does.
  (int, int) cellOf(int square) {
    final index = square - 1;
    final rowFromBottom = index ~/ columns;
    final along = index % columns;
    final column = rowFromBottom.isEven ? along : columns - 1 - along;
    return (column, rows - 1 - rowFromBottom);
  }

  /// Rolls and resolves in one step — there is no decision to make in between.
  SnakesTurn roll(DallyRandom random) => rollFace(random.range(1, 6));

  @visibleForTesting
  SnakesTurn rollFace(int face) {
    if (isFinished) throw StateError('roll after the game ended');
    final player = current;
    final from = positions[player];
    // An overshoot stays put: the last square needs an exact count.
    final landed = from + face > squares ? from : from + face;
    final link = _links[landed];
    final to = link?.to ?? landed;
    positions[player] = to;
    final won = to == squares;
    if (won) winner = player;
    if (!won) current = (current + 1) % playerCount;
    return SnakesTurn(
      player: player,
      face: face,
      from: from,
      landed: landed,
      link: link,
      won: won,
    );
  }
}
