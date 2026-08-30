import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/cards.dart';
import '../logic/solitaire.dart';
import '../logic/solitaire_layout.dart';

/// The two card faces from the design. Geometry only; the *colours* of a card
/// face are a deliberate token exception, on the same footing as the two chess
/// piece colours — a card is a card in every theme, and only the back and the
/// empty slots follow the palette. In particular the red is a fixed brick red
/// rather than the danger token, so an invalid-move flash can never be mistaken
/// for "this card is a heart".
enum CardStyle {
  /// Rank and suit in the top-left corner, a larger suit at bottom-right — the
  /// reading position that still works when a card is 19px from the one below.
  classic,

  /// Rank centred and large with the suit beneath it. Cleaner as a whole table,
  /// but only legible on the exposed card of a pile.
  minimal,
}

CardStyle cardStyleFromId(String id) =>
    id == 'minimal' ? CardStyle.minimal : CardStyle.classic;

/// The fixed card-face palette (design §10: "face #EEEAE1, black suits #26241F,
/// red suits #C1443B").
///
/// **A deliberate token exception**, and one of only three in the app — the
/// others are Chess's two piece colours and `PlayerIdentity`'s four seats. A
/// playing card whose face and suits followed the palette would stop being a
/// playing card: "red suit" is a rule of the game, not a style choice, and a
/// theme that recoloured it would make the board unreadable. These are the only
/// literals allowed outside `core/theme/`; everything around them — the table,
/// the slot outlines, the hairlines — still reads tokens.
const Color kCardFace = Color(0xFFEEEAE1);
const Color kCardInk = Color(0xFF26241F);
const Color kCardRed = Color(0xFFC1443B);

/// How many cards the Klondike deal puts on the table: 1+2+…+7.
const int _dealtCards = 28;

/// The whole table in one painter: stock, waste, foundations, every column, and
/// whatever card is currently in flight.
class SolitairePainter extends CustomPainter {
  SolitairePainter({
    required this.game,
    required this.style,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.accent,
    required this.textFaint,
    required this.flight,
    required this.shake,
    required this.drag,
    required this.deal,
  });

  final Solitaire game;
  final CardStyle style;

  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color accent;
  final Color textFaint;

  /// Cards mid-move: what is flying, from where, to where, and how far along.
  final (List<PlayingCard> cards, Offset from, Offset to, double t)? flight;

  /// Sideways nudge on a rejected card.
  final (CardRef ref, double dx)? shake;

  /// The run currently under the finger: where it came from, the cards, and the
  /// top-left it is drawn at right now.
  final (CardRef from, List<PlayingCard> cards, Offset at)? drag;

  /// Deal progress, `0 … 1`. Below 1 the 28 tableau cards fly out of the stock
  /// one after another; at 1 the table is simply dealt.
  final double deal;

  late SolitaireLayout _layout;

  @override
  void paint(Canvas canvas, Size size) {
    _layout = SolitaireLayout(game, size);
    final flying = {...?flight?.$1, ...?drag?.$2};

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
        var rect = _layout.tableauRect(c, i);
        if (deal < 1) {
          // Card k of the deal leaves the stock at k × (1/28) of the run.
          final order = c * (c + 1) ~/ 2 + i;
          final t = (deal * _dealtCards - order).clamp(0.0, 1.0);
          if (t <= 0) continue;
          rect = Rect.fromLTWH(
            lerpDouble(_layout.stockRect.left, rect.left, t)!,
            lerpDouble(_layout.stockRect.top, rect.top, t)!,
            rect.width,
            rect.height,
          );
        }
        game.isFaceUp(c, i)
            ? _face(canvas, rect, column[i],
                nudge: _nudgeFor(CardRef(PileKind.tableau, c, i)))
            : _back(canvas, rect);
      }
    }

    final held = drag;
    if (held != null) {
      for (var i = 0; i < held.$2.length; i++) {
        _face(
          canvas,
          Rect.fromLTWH(held.$3.dx, held.$3.dy + i * _layout.faceUpStep,
              _layout.cardWidth, _layout.cardHeight),
          held.$2[i],
        );
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
      paintCardFace(canvas, where.translate(nudge, 0), card, style, border: border);

  void _text(Canvas canvas, Offset at, String text, double size, Color colour,
          {bool centred = false}) =>
      _paintText(canvas, at, text, size, colour, centred: centred);

  @override
  bool shouldRepaint(SolitairePainter old) => true;
}

/// One card face. Top-level so the style picker's preview draws with exactly
/// the code the board does, rather than a look-alike.
///
/// [border] is the only themed colour here — a hairline that keeps the fixed
/// cream face separated from a light board.
void paintCardFace(
  Canvas canvas,
  Rect rect,
  PlayingCard card,
  CardStyle style, {
  required Color border,
}) {
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.cell));
  canvas.drawRRect(rrect, Paint()..color = kCardFace);
  canvas.drawRRect(
    rrect.deflate(0.5),
    Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  final colour = card.isRed ? kCardRed : kCardInk;

  switch (style) {
    case CardStyle.classic:
      // Corner index: rank over suit, inside the 19px sliver a fanned card
      // leaves showing. The second suit sits bottom-right at full weight.
      final corner = rect.topLeft + Offset(rect.width * 0.11, rect.height * 0.05);
      _paintText(canvas, corner, card.rankLabel, rect.width * 0.32, colour);
      _paintText(canvas, corner + Offset(rect.width * 0.02, rect.width * 0.36),
          card.suit.glyph, rect.width * 0.26, colour);
      _paintText(
          canvas,
          Offset(rect.right - rect.width * 0.26, rect.bottom - rect.height * 0.20),
          card.suit.glyph,
          rect.width * 0.34,
          colour,
          centred: true);
    case CardStyle.minimal:
      // Rank centred and large, suit directly beneath it.
      _paintText(canvas, Offset(rect.center.dx, rect.top + rect.height * 0.38),
          card.rankLabel, rect.width * 0.56, colour,
          centred: true);
      _paintText(canvas, Offset(rect.center.dx, rect.top + rect.height * 0.72),
          card.suit.glyph, rect.width * 0.30, colour,
          centred: true);
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
