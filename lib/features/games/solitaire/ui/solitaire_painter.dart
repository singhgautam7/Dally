import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/cards.dart';
import '../logic/solitaire.dart';
import '../logic/solitaire_layout.dart';

/// The two card faces. Geometry only — every colour comes from tokens, which is
/// what lets one style work in all eight palettes. Suits are the standard
/// typographic glyphs, drawn as text: no licensed deck art anywhere.
enum CardStyle { glyph, numeral }

CardStyle cardStyleFromId(String id) =>
    id == 'numeral' ? CardStyle.numeral : CardStyle.glyph;

/// The whole table in one painter: stock, waste, foundations, every column, and
/// whatever card is currently in flight.
class SolitairePainter extends CustomPainter {
  SolitairePainter({
    required this.game,
    required this.style,
    required this.ink,
    required this.red,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.accent,
    required this.textFaint,
    required this.flight,
    required this.shake,
  });

  final Solitaire game;
  final CardStyle style;

  /// Black suits use the ink colour; red suits the danger token, the only red
  /// that is guaranteed to read in every palette.
  final Color ink;
  final Color red;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color accent;
  final Color textFaint;

  /// Cards mid-move: what is flying, from where, to where, and how far along.
  final (List<PlayingCard> cards, Offset from, Offset to, double t)? flight;

  /// Sideways nudge on a rejected card.
  final (CardRef ref, double dx)? shake;

  late SolitaireLayout _layout;

  @override
  void paint(Canvas canvas, Size size) {
    _layout = SolitaireLayout(game, size);
    final flying = {...?flight?.$1};

    _slot(canvas, _layout.stockRect, glyph: game.stock.isEmpty ? '↻' : null);
    if (game.stock.isNotEmpty) _back(canvas, _layout.stockRect);

    _slot(canvas, _layout.wasteRect);
    // Draw-3 shows the last three, oldest behind.
    final shown = math.min(game.drawCount, game.waste.length);
    for (var i = shown - 1; i >= 0; i--) {
      final index = game.waste.length - 1 - i;
      final card = game.waste[index];
      if (flying.contains(card)) continue;
      _face(canvas, _layout.wasteCardRect(i), card,
          nudge: _nudgeFor(CardRef(PileKind.waste, 0, index)));
    }

    for (var f = 0; f < 4; f++) {
      final pile = game.foundations[f];
      _slot(canvas, _layout.foundationRect(f), glyph: Suit.values[f].glyph);
      if (pile.isNotEmpty && !flying.contains(pile.last)) {
        _face(canvas, _layout.foundationRect(f), pile.last);
      }
    }

    for (var c = 0; c < Solitaire.columns; c++) {
      final column = game.tableau[c];
      if (column.isEmpty) {
        _slot(canvas, _layout.tableauSlot(c));
        continue;
      }
      for (var i = 0; i < column.length; i++) {
        if (flying.contains(column[i])) continue;
        final rect = _layout.tableauRect(c, i);
        game.isFaceUp(c, i)
            ? _face(canvas, rect, column[i],
                nudge: _nudgeFor(CardRef(PileKind.tableau, c, i)))
            : _back(canvas, rect);
      }
    }

    final inFlight = flight;
    if (inFlight != null) {
      final origin = Offset.lerp(inFlight.$2, inFlight.$3, inFlight.$4)!;
      for (var i = 0; i < inFlight.$1.length; i++) {
        _face(
          canvas,
          Rect.fromLTWH(origin.dx, origin.dy + i * _layout.faceUpStep,
              _layout.cardWidth, _layout.cardHeight),
          inFlight.$1[i],
        );
      }
    }
  }

  double _nudgeFor(CardRef ref) {
    final s = shake;
    return s != null && s.$1 == ref ? s.$2 : 0;
  }

  void _slot(Canvas canvas, Rect rect, {String? glyph}) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.cell));
    canvas.drawRRect(rrect, Paint()..color = surfaceAlt.withValues(alpha: 0.45));
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (glyph != null) {
      _text(canvas, rect.center, glyph, rect.width * 0.4, textFaint, centred: true);
    }
  }

  void _back(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.cell));
    canvas.drawRRect(rrect, Paint()..color = accent.withValues(alpha: 0.85));
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // A quiet lattice, so a face-down card is never mistaken for a slot.
    canvas.save();
    canvas.clipRRect(rrect.deflate(rect.width * 0.12));
    final line = Paint()
      ..color = surface.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = -rect.height; x < rect.width; x += rect.width * 0.18) {
      canvas.drawLine(rect.topLeft + Offset(x, 0),
          rect.topLeft + Offset(x + rect.height, rect.height), line);
    }
    canvas.restore();
  }

  void _face(Canvas canvas, Rect where, PlayingCard card, {double nudge = 0}) =>
      paintCardFace(canvas, where.translate(nudge, 0), card, style,
          ink: ink, red: red, surface: surface, border: border);

  void _text(Canvas canvas, Offset at, String text, double size, Color colour,
          {bool centred = false}) =>
      _paintText(canvas, at, text, size, colour, centred: centred);

  @override
  bool shouldRepaint(SolitairePainter old) => true;
}

/// One card face. Top-level so the style picker's preview draws with exactly
/// the code the board does, rather than a look-alike.
void paintCardFace(
  Canvas canvas,
  Rect rect,
  PlayingCard card,
  CardStyle style, {
  required Color ink,
  required Color red,
  required Color surface,
  required Color border,
}) {
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.cell));
  canvas.drawRRect(rrect, Paint()..color = surface);
  canvas.drawRRect(
    rrect.deflate(0.5),
    Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  final colour = card.isRed ? red : ink;
  final pad = rect.width * 0.12;
  final corner = rect.topLeft + Offset(pad, pad * 0.7);

  switch (style) {
    case CardStyle.glyph:
      _paintText(canvas, corner, card.rankLabel, rect.width * 0.30, colour);
      _paintText(canvas, corner + Offset(0, rect.width * 0.34), card.suit.glyph,
          rect.width * 0.24, colour);
      _paintText(canvas, rect.center + Offset(rect.width * 0.16, rect.height * 0.14),
          card.suit.glyph, rect.width * 0.42, colour.withValues(alpha: 0.55),
          centred: true);
    case CardStyle.numeral:
      _paintText(canvas, corner, '${card.rankLabel}${card.suit.glyph}',
          rect.width * 0.26, colour);
      _paintText(canvas, rect.center + Offset(0, rect.height * 0.10), card.rankLabel,
          rect.width * 0.52, colour.withValues(alpha: 0.5), centred: true);
  }
}

void _paintText(Canvas canvas, Offset at, String text, double size, Color colour,
    {bool centred = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text, style: DallyType.monoChip.copyWith(fontSize: size, color: colour)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centred ? at - Offset(tp.width / 2, tp.height / 2) : at);
}
