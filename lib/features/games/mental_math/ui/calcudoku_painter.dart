import 'package:flutter/material.dart';

import '../../../../core/theme/type_scale.dart';
import '../logic/calcudoku.dart';

/// The Calcudoku board in one painter.
///
/// Cells are a **uniform hairline grid**; cages are one heavier outline drawn
/// on top, with the target in the cage's top-left cell. Bordering the cells
/// themselves would double the lines and make 6×6 unreadable.
class CalcudokuPainter extends CustomPainter {
  CalcudokuPainter({
    required this.puzzle,
    required this.values,
    required this.notes,
    required this.selected,
    required this.conflict,
    required this.ink,
    required this.accent,
    required this.border,
    required this.faint,
    required this.danger,
  });

  final CalcudokuPuzzle puzzle;

  /// Row-major entries, 0 for empty.
  final List<int> values;

  /// Row-major pencil marks.
  final List<Set<int>> notes;

  final int? selected;

  /// The two cells that disagree, once both are filled.
  final (int, int)? conflict;

  final Color ink;
  final Color accent;
  final Color border;
  final Color faint;
  final Color danger;

  @override
  void paint(Canvas canvas, Size size) {
    final n = puzzle.size;
    final cell = size.width / n;
    final cageOf = puzzle.cageOfCell;

    if (selected != null) {
      final r = selected! ~/ n, c = selected! % n;
      canvas.drawRect(
        Rect.fromLTWH(c * cell, r * cell, cell, cell),
        Paint()..color = accent.withValues(alpha: 0.14),
      );
    }
    if (conflict != null) {
      for (final cellIndex in [conflict!.$1, conflict!.$2]) {
        final r = cellIndex ~/ n, c = cellIndex % n;
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          Paint()..color = danger.withValues(alpha: 0.16),
        );
      }
    }

    final hairline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= n; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), hairline);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), hairline);
    }

    // The cage outline: only the edges where the neighbouring cell is in a
    // different cage (or off the board).
    final cageStroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;
    for (var index = 0; index < n * n; index++) {
      final r = index ~/ n, c = index % n;
      final mine = cageOf[index];
      final left = Offset(c * cell, r * cell);
      if (r == 0 || cageOf[index - n] != mine) {
        canvas.drawLine(left, left + Offset(cell, 0), cageStroke);
      }
      if (r == n - 1 || cageOf[index + n] != mine) {
        canvas.drawLine(left + Offset(0, cell), left + Offset(cell, cell), cageStroke);
      }
      if (c == 0 || cageOf[index - 1] != mine) {
        canvas.drawLine(left, left + Offset(0, cell), cageStroke);
      }
      if (c == n - 1 || cageOf[index + 1] != mine) {
        canvas.drawLine(left + Offset(cell, 0), left + Offset(cell, cell), cageStroke);
      }
    }

    for (final cage in puzzle.cages) {
      final head = cage.cells.first;
      final r = head ~/ n, c = head % n;
      _text(canvas, cage.label, Offset(c * cell + 4, r * cell + 3), faint, cell * 0.19);
    }

    for (var index = 0; index < n * n; index++) {
      final r = index ~/ n, c = index % n;
      final centre = Offset(c * cell + cell / 2, r * cell + cell / 2);
      final value = values[index];
      if (value != 0) {
        final isWrong = conflict != null && (conflict!.$1 == index || conflict!.$2 == index);
        _centred(canvas, '$value', centre, isWrong ? danger : ink, cell * 0.42);
      } else if (notes[index].isNotEmpty) {
        final marks = (notes[index].toList()..sort()).join(' ');
        _centred(canvas, marks, centre, faint, cell * 0.16);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: DallyType.monoSm.copyWith(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  void _centred(Canvas canvas, String s, Offset centre, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: DallyType.monoChip.copyWith(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(CalcudokuPainter old) => true;
}
