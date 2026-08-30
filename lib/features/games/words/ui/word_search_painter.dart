import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/word_search.dart';

/// The letter grid, the words already found, and the line being dragged — all
/// in one painter. A 12×12 grid is 144 cells; one widget each is exactly the
/// explosion the performance contract rules out.
class WordSearchPainter extends CustomPainter {
  WordSearchPainter({
    required this.game,
    required this.selection,
    required this.ink,
    required this.textMuted,
    required this.surface,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.success,
  });

  final WordSearchGame game;

  /// The cells currently under the finger.
  final List<(int, int)> selection;

  final Color ink;
  final Color textMuted;
  final Color surface;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color success;

  /// Cell size for the last painted size — the hit test asks for it.
  static double cellSizeFor(Size size, int gridSize) =>
      math.min(size.width, size.height) / gridSize;

  /// The cell at [point], or null when the point is outside the grid.
  static (int, int)? cellAt(Offset point, Size size, int gridSize) {
    final cell = cellSizeFor(size, gridSize);
    final extent = cell * gridSize;
    final origin = Offset((size.width - extent) / 2, 0);
    final local = point - origin;
    if (local.dx < 0 || local.dy < 0 || local.dx >= extent || local.dy >= extent) {
      return null;
    }
    return ((local.dy ~/ cell).clamp(0, gridSize - 1),
        (local.dx ~/ cell).clamp(0, gridSize - 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = game.puzzle.size;
    final cell = cellSizeFor(size, n);
    final extent = cell * n;
    final origin = Offset((size.width - extent) / 2, 0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx, origin.dy, extent, extent),
          const Radius.circular(Radii.cell)),
      Paint()..color = surface,
    );

    final found = game.foundCells;
    final selected = selection.toSet();

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(
            origin.dx + c * cell, origin.dy + r * cell, cell, cell);
        final isFound = found.contains((r, c));
        final isSelected = selected.contains((r, c));
        if (isFound || isSelected) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.deflate(cell * 0.06), Radius.circular(cell * 0.26)),
            Paint()
              ..color = isSelected
                  ? accent
                  : success.withValues(alpha: 0.32),
          );
        }
        final tp = TextPainter(
          text: TextSpan(
            text: game.puzzle.letterAt(r, c).toUpperCase(),
            style: DallyType.monoChip.copyWith(
              fontSize: cell * 0.46,
              color: isSelected ? onAccent : (isFound ? ink : textMuted),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx, origin.dy, extent, extent).deflate(0.5),
          const Radius.circular(Radii.cell)),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(WordSearchPainter old) => true;
}
