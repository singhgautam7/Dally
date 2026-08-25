import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/word_guess.dart';

/// The guess grid — one painter for every tile, never a widget per cell.
///
/// The newest row flips its tiles open one after another; the tile shows the
/// guessed letter unmarked until it passes half-turn, which is what makes the
/// reveal read as the board answering rather than the answer appearing.
class GuessBoardPainter extends CustomPainter {
  GuessBoardPainter({
    required this.game,
    required this.draft,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.onAccent,
    required this.accent,
    required this.success,
    required this.reveal,
    required this.shake,
  });

  final WordGuessGame game;

  /// What the player is typing into the next row.
  final String draft;

  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color onAccent;
  final Color accent;
  final Color success;

  /// 0→1 across the newest row's flip; 1 when nothing is revealing.
  final double reveal;

  /// Sideways nudge on the draft row when a guess is refused.
  final double shake;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = game.length;
    final rows = game.maxTries;
    const gap = 6.0;
    final tile = math.min(
      (size.width - gap * (columns - 1)) / columns,
      (size.height - gap * (rows - 1)) / rows,
    );
    final width = tile * columns + gap * (columns - 1);
    final left = (size.width - width) / 2;

    for (var r = 0; r < rows; r++) {
      final guess = r < game.guesses.length ? game.guesses[r] : null;
      final isDraft = guess == null && r == game.guesses.length;
      final revealing = r == game.guesses.length - 1 && reveal < 1;

      for (var c = 0; c < columns; c++) {
        final rect = Rect.fromLTWH(
          left + c * (tile + gap) + (isDraft ? shake : 0),
          r * (tile + gap),
          tile,
          tile,
        );

        var letter = '';
        LetterMark? mark;
        if (guess != null) {
          letter = guess.word[c];
          mark = guess.marks[c];
          if (revealing) {
            // Each tile turns a beat after the one before it.
            final start = c / columns;
            final local = ((reveal - start) / (1 / columns)).clamp(0.0, 1.0);
            if (!local.flipPastHalf) mark = null;
            _tile(canvas, rect, letter, mark, scaleX: local.flipScaleX);
            continue;
          }
        } else if (isDraft && c < draft.length) {
          letter = draft[c];
        }
        _tile(canvas, rect, letter, mark);
      }
    }
  }

  void _tile(Canvas canvas, Rect rect, String letter, LetterMark? mark,
      {double scaleX = 1}) {
    canvas.save();
    if (scaleX != 1) {
      canvas
        ..translate(rect.center.dx, rect.center.dy)
        ..scale(math.max(scaleX, 0.001), 1)
        ..translate(-rect.center.dx, -rect.center.dy);
    }
    final (fill, textColour) = switch (mark) {
      LetterMark.correct => (success, onAccent),
      LetterMark.present => (accent, onAccent),
      LetterMark.absent => (surfaceAlt, ink),
      null => (surface, ink),
    };
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.cell));
    canvas.drawRRect(rrect, Paint()..color = fill);
    if (mark == null) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = letter.isEmpty ? border : ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = letter.isEmpty ? 1 : 1.6,
      );
    }
    if (letter.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: letter.toUpperCase(),
          style: DallyType.bodyStrong.copyWith(
            fontSize: rect.width * 0.46,
            fontWeight: FontWeight.w600,
            color: textColour,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GuessBoardPainter old) => true;
}
