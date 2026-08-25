import 'dart:ui';

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
  static List<Offset> yardSpots(int player) {
    final o = yardOrigin(player);
    return [
      o + const Offset(2.0, 2.0),
      o + const Offset(4.0, 2.0),
      o + const Offset(2.0, 4.0),
      o + const Offset(4.0, 4.0),
    ];
  }

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

  /// The cells a token walks through going from [from] to [to] — used to hop
  /// the token one square at a time rather than sliding it across the board.
  static List<Offset> pathBetween(int player, int from, int to, int token) {
    if (from == kInBase) return [cellOf(player, to, token)];
    return [
      for (var s = from + 1; s <= to; s++) cellOf(player, s, token),
    ];
  }
}
