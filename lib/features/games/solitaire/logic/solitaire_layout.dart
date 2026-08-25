import 'dart:math' as math;
import 'dart:ui';

import 'solitaire.dart';

/// Where every card sits for a given board size. Pure geometry, shared by the
/// painter and the hit test so the card you tap is always the card you see.
///
/// The board is seven columns wide: stock and waste on the left of the top row,
/// the four foundations on the right, and the seven tableau columns below. The
/// fan spacing shrinks as a column grows, so a long column never runs off the
/// bottom instead of being scrolled.
class SolitaireLayout {
  SolitaireLayout(this.game, this.size) {
    const gapRatio = 0.08;
    cardWidth = size.width / (Solitaire.columns + gapRatio * (Solitaire.columns - 1));
    gap = cardWidth * gapRatio;
    cardHeight = cardWidth * 1.42;

    final tallest = game.tableau.fold<int>(1, (m, c) => math.max(m, c.length));
    final available = size.height - cardHeight - gap * 2.2 - cardHeight;
    // Face-down cards sit tighter than face-up ones, the way a real fan does.
    final wanted = cardHeight * 0.30;
    faceUpStep = tallest <= 1
        ? wanted
        : math.min(wanted, math.max(cardHeight * 0.10, available / (tallest - 1)));
    faceDownStep = faceUpStep * 0.55;
  }

  final Solitaire game;
  final Size size;

  late final double cardWidth;
  late final double cardHeight;
  late final double gap;
  late final double faceUpStep;
  late final double faceDownStep;

  double get tableauTop => cardHeight + gap * 2.2;

  double _columnLeft(int column) => column * (cardWidth + gap);

  Rect get stockRect => Rect.fromLTWH(_columnLeft(0), 0, cardWidth, cardHeight);

  Rect get wasteRect => Rect.fromLTWH(_columnLeft(1), 0, cardWidth, cardHeight);

  /// Draw-3 fans the waste sideways so all three are visible.
  Rect wasteCardRect(int fromTop) => wasteRect.translate(
      -fromTop * cardWidth * 0.22, 0);

  Rect foundationRect(int index) =>
      Rect.fromLTWH(_columnLeft(3 + index), 0, cardWidth, cardHeight);

  /// The rect of the card at [index] in tableau column [column].
  Rect tableauRect(int column, int index) {
    var y = tableauTop;
    for (var i = 0; i < index; i++) {
      y += game.isFaceUp(column, i) ? faceUpStep : faceDownStep;
    }
    return Rect.fromLTWH(_columnLeft(column), y, cardWidth, cardHeight);
  }

  /// The empty slot outline for a column with nothing in it.
  Rect tableauSlot(int column) =>
      Rect.fromLTWH(_columnLeft(column), tableauTop, cardWidth, cardHeight);

  Rect rectFor(CardRef ref) => switch (ref.kind) {
        PileKind.stock => stockRect,
        PileKind.waste => wasteCardRect(game.waste.length - 1 - ref.index),
        PileKind.foundation => foundationRect(ref.pile),
        PileKind.tableau => tableauRect(ref.pile, ref.index),
      };

  /// How tall the board actually needs to be for this deal.
  double get requiredHeight {
    var tallest = tableauTop + cardHeight;
    for (var c = 0; c < Solitaire.columns; c++) {
      final column = game.tableau[c];
      if (column.isEmpty) continue;
      tallest = math.max(tallest, tableauRect(c, column.length - 1).bottom);
    }
    return tallest;
  }

  /// The topmost card under [point], or null. Tableau columns are searched from
  /// the bottom of the pile up, so the card drawn on top is the one hit.
  CardRef? hitTest(Offset point) {
    for (var c = 0; c < Solitaire.columns; c++) {
      final column = game.tableau[c];
      for (var i = column.length - 1; i >= 0; i--) {
        // Every card but the last is clipped to the sliver that shows.
        final rect = tableauRect(c, i);
        final visible = i == column.length - 1
            ? rect
            : Rect.fromLTWH(rect.left, rect.top, cardWidth,
                tableauRect(c, i + 1).top - rect.top);
        if (visible.contains(point)) return CardRef(PileKind.tableau, c, i);
      }
    }
    if (game.waste.isNotEmpty && wasteRect.contains(point)) {
      return CardRef(PileKind.waste, 0, game.waste.length - 1);
    }
    for (var f = 0; f < 4; f++) {
      if (game.foundations[f].isNotEmpty && foundationRect(f).contains(point)) {
        return CardRef(PileKind.foundation, f, game.foundations[f].length - 1);
      }
    }
    if (stockRect.contains(point)) return const CardRef(PileKind.stock, 0, 0);
    return null;
  }

  /// The pile a drop at [point] lands on, empty slots included.
  (PileKind, int)? dropTargetAt(Offset point) {
    for (var f = 0; f < 4; f++) {
      if (foundationRect(f).contains(point)) return (PileKind.foundation, f);
    }
    for (var c = 0; c < Solitaire.columns; c++) {
      final column = game.tableau[c];
      final rect = column.isEmpty
          ? tableauSlot(c)
          : tableauRect(c, column.length - 1).expandToInclude(tableauSlot(c));
      if (rect.contains(point)) return (PileKind.tableau, c);
    }
    return null;
  }
}
