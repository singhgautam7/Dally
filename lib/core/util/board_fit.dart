import 'dart:math' as math;
import 'dart:ui';

/// The one board fitter, used by every grid game.
///
/// `cell = clamp(floor, min(availW / cols, availH / rows), cap)` — take the
/// available box, divide by the column and row counts, take the **smaller** of
/// the two scales, clamp it, and centre what comes out. Nothing in game code
/// knows a pixel size, which is what makes a 10 × 6 and a 6 × 10 both legal and
/// both fill the screen properly.
///
/// It replaces four hand-tuned constants (Dots & Boxes, Four-in-a-Row, Word
/// Search, Frog Hop). Landscape needs no special case: width and height swap,
/// and the board re-derives its cell.
class BoardFit {
  const BoardFit({required this.cell, required this.cols, required this.rows});

  /// The side of one square cell.
  final double cell;
  final int cols;
  final int rows;

  double get width => cell * cols;
  double get height => cell * rows;
  Size get size => Size(width, height);

  /// True when the fit hit the floor and the board is wider or taller than the
  /// box it was given. Below the floor a board **scrolls** rather than shrinking
  /// past a usable touch target — which only the largest grids on the smallest
  /// phones can trigger.
  bool overflows(Size available) =>
      width > available.width + 0.5 || height > available.height + 0.5;

  /// The top-left corner that centres the board inside [available].
  Offset originIn(Size available) => Offset(
        math.max(0, (available.width - width) / 2),
        math.max(0, (available.height - height) / 2),
      );
}

/// Fits a [cols] × [rows] grid into [available].
///
/// [padding] is taken off both axes first — the margin a board keeps from the
/// screen edge. [floor] is the smallest cell that is still a usable touch
/// target; [cap] stops a 3 × 3 board from becoming three enormous squares on a
/// tablet.
BoardFit fitBoard({
  required Size available,
  required int cols,
  required int rows,
  double floor = 26,
  double cap = 64,
  double padding = 0,
}) {
  assert(cols > 0 && rows > 0);
  assert(floor <= cap);
  final w = math.max(0.0, available.width - padding * 2);
  final h = math.max(0.0, available.height - padding * 2);
  final raw = math.min(w / cols, h / rows);
  return BoardFit(cell: raw.clamp(floor, cap), cols: cols, rows: rows);
}
