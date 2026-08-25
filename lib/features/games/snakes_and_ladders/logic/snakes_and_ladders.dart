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

/// Generates a board's links. Seeded, so a board is reproducible and every
/// generation rule is testable.
///
/// Guarantees, all of which a hand-placed board also has:
/// * every endpoint (foot, top, head, tail) is a distinct square, so no link
///   can ever chain into another and no single roll resolves twice;
/// * square 1 and the last square are never an endpoint;
/// * a link spans **two to four rows** — long enough to matter, short enough
///   that the board stays legible instead of becoming a cat's cradle;
/// * ladders climb, snakes drop.
///
/// The counts are deliberately low. An earlier version put a link on every
/// twelfth square with an unbounded span, which on a 10x10 drew sixteen lines
/// across the whole board and buried the numbers underneath them.
List<Link> generateLinks(DallyRandom random, {required int columns, required int rows}) {
  final squares = columns * rows;
  final pairs = (squares / 25).round().clamp(2, 5);
  final used = <int>{1, squares};
  final links = <Link>[];

  int? freeSquare(int lowest, int highest) {
    for (var attempt = 0; attempt < 40; attempt++) {
      final s = random.range(lowest, highest);
      if (!used.contains(s)) return s;
    }
    return null;
  }

  // Ladders first: they are the ones players notice missing.
  for (var kind = 0; kind < 2; kind++) {
    final wantLadders = kind == 0;
    for (var i = 0; i < pairs; i++) {
      final low = freeSquare(2, squares - columns - 1);
      if (low == null) continue;
      final lowRow = (low - 1) ~/ columns;
      final minRow = lowRow + 2;
      if (minRow >= rows) continue;
      final maxRow = math.min(rows - 1, lowRow + 4);
      final high = freeSquare(
          minRow * columns + 1, math.min(squares - 1, (maxRow + 1) * columns));
      if (high == null || high == low) continue;
      used
        ..add(low)
        ..add(high);
      links.add(wantLadders ? Link(low, high) : Link(high, low));
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
