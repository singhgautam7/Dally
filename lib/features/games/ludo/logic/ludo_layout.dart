import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'ludo.dart';

/// Where every square of the cross sits, in board cells. Pure geometry with no
/// painter or widget attached, so the hit test and the painter agree by
/// construction and the whole thing is testable.
///
/// The board is a 15×15 grid: four 6×6 yards in the corners, three-wide arms
/// meeting at a centre cell.
class LudoLayout {
  LudoLayout._();

  static const int gridSize = 15;

  /// The 52 shared ring cells, clockwise, starting at seat 0's entry square.
  static final List<Offset> ring = _buildRing();

  static List<Offset> _buildRing() {
    final cells = <Offset>[];
    void run(int c0, int r0, int c1, int r1) {
      final steps = (c1 - c0).abs() + (r1 - r0).abs();
      final dc = (c1 - c0).sign, dr = (r1 - r0).sign;
      for (var i = 0; i <= steps; i++) {
        cells.add(Offset((c0 + dc * i).toDouble(), (r0 + dr * i).toDouble()));
      }
    }

    run(1, 6, 5, 6);
    run(6, 5, 6, 1);
    run(6, 0, 8, 0);
    run(8, 1, 8, 5);
    run(9, 6, 13, 6);
    run(14, 6, 14, 8);
    run(13, 8, 9, 8);
    run(8, 9, 8, 13);
    run(8, 14, 6, 14);
    run(6, 13, 6, 9);
    run(5, 8, 1, 8);
    run(0, 8, 0, 6);
    assert(cells.length == kRingSquares);
    return cells;
  }

  /// The five private home-column cells for [player], entry end first.
  static List<Offset> homeColumn(int player) => switch (player) {
        0 => [for (var c = 1; c <= 5; c++) Offset(c.toDouble(), 7)],
        1 => [for (var r = 1; r <= 5; r++) Offset(7, r.toDouble())],
        2 => [for (var c = 13; c >= 9; c--) Offset(c.toDouble(), 7)],
        _ => [for (var r = 13; r >= 9; r--) Offset(7, r.toDouble())],
      };

  /// The centre cell every token finishes on.
  static const Offset centre = Offset(7, 7);

  /// The 6×6 yard block for [player], as (left, top) in cells.
  static Offset yardOrigin(int player) => switch (player) {
        0 => const Offset(0, 0),
        1 => const Offset(9, 0),
        2 => const Offset(9, 9),
        _ => const Offset(0, 9),
      };

  /// The four resting spots inside [player]'s yard, in cell coordinates
  /// (centres, so they land between grid lines).
  ///
  /// They sit near the yard's corners rather than hugging its middle: the
  /// centre is where the follow-the-turn die parks, and a die big enough to be
  /// a comfortable target needs that room.
  static List<Offset> yardSpots(int player) {
    final o = yardOrigin(player);
    return [
      o + const Offset(1.5, 1.5),
      o + const Offset(4.5, 1.5),
      o + const Offset(1.5, 4.5),
      o + const Offset(4.5, 4.5),
    ];
  }

  /// The centre of [player]'s yard — where the die parks when it follows the
  /// turn. Nothing else is ever drawn here.
  static Offset yardCentre(int player) => yardOrigin(player) + const Offset(3, 3);

  /// The cell centre a token of [player] on [step] draws at. [token] only
  /// matters in the yard, where the four tokens have their own spots.
  static Offset cellOf(int player, int step, int token) {
    if (step == kInBase) return yardSpots(player)[token];
    if (step == kHome) return centre + const Offset(0.5, 0.5);
    if (step <= kLastRingStep) {
      return ring[ringIndexOf(player, step)] + const Offset(0.5, 0.5);
    }
    return homeColumn(player)[step - kLastRingStep - 1] + const Offset(0.5, 0.5);
  }

  /// One thing to draw on a cell. A cell can hold several tokens — a seat's own
  /// pair or stack, or tokens of different seats — and this says where each one
  /// goes and whether it stands for more than itself.
  ///
  /// Pure geometry in cell units, so the painter has no layout decisions of its
  /// own to make and the rules here can be tested without a canvas.
  static const int stackBadgeFrom = 3;

  /// Lays out everything standing on one cell.
  ///
  /// * one seat, one token — dead centre;
  /// * one seat, two tokens — fanned either side, both drawn in full, because
  ///   seeing two is faster than reading "×2";
  /// * one seat, three or more — a single token carrying a `×N` count;
  /// * several seats — each group offset side by side and shrunk to 86%, so
  ///   every identity on the cell stays visible and none is hidden under
  ///   another.
  ///
  /// [occupants] is `(player, token)` pairs; the result is in draw order.
  static List<TokenPlacement> placeOnCell(List<(int, int)> occupants) {
    final bySeat = <int, List<int>>{};
    for (final (p, i) in occupants) {
      bySeat.putIfAbsent(p, () => []).add(i);
    }
    final seats = bySeat.keys.toList()..sort();
    final mixed = seats.length > 1;
    final scale = mixed ? 0.86 : 1.0;

    final out = <TokenPlacement>[];
    for (var k = 0; k < seats.length; k++) {
      final player = seats[k];
      final tokens = bySeat[player]!..sort();
      // Wide enough that two heads clear each other rather than merging into
      // one blob — a pin head is about half a cell across.
      final dx = mixed ? 0.40 * (k - (seats.length - 1) / 2) : 0.0;

      if (tokens.length >= stackBadgeFrom) {
        out.add(TokenPlacement(
            player: player,
            token: tokens.first,
            count: tokens.length,
            offset: Offset(dx, 0),
            scale: scale));
      } else if (tokens.length == 2) {
        final fan = 0.30 * scale;
        for (var j = 0; j < 2; j++) {
          out.add(TokenPlacement(
              player: player,
              token: tokens[j],
              count: 1,
              offset: Offset(dx + fan * (j * 2 - 1), 0),
              scale: scale));
        }
      } else {
        out.add(TokenPlacement(
            player: player,
            token: tokens.first,
            count: 1,
            offset: Offset(dx, 0),
            scale: scale));
      }
    }
    return out;
  }

  /// The cells a token walks through going from [from] to [to] — used to hop
  /// the token one square at a time rather than sliding it across the board.
  static List<Offset> pathBetween(int player, int from, int to, int token) {
    if (from == kInBase) return [cellOf(player, to, token)];
    return [
      for (var s = from + 1; s <= to; s++) cellOf(player, s, token),
    ];
  }
}

/// One token drawn on a cell, positioned relative to that cell's centre.
@immutable
class TokenPlacement {
  const TokenPlacement({
    required this.player,
    required this.token,
    required this.count,
    required this.offset,
    required this.scale,
  });

  final int player;

  /// The token actually drawn. When [count] is greater than one the others in
  /// its stack are behind it and interchangeable with it.
  final int token;

  /// How many of that seat's tokens this stands for. Above one it carries a
  /// `×N` badge instead of being fanned out.
  final int count;

  /// Offset from the cell centre, **in cells**.
  final Offset offset;

  /// 1 when this seat has the cell to itself, less when sharing it.
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is TokenPlacement &&
      other.player == player &&
      other.token == token &&
      other.count == count &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(player, token, count, offset, scale);

  @override
  String toString() => 'P$player T$token ×$count @$offset';
}
