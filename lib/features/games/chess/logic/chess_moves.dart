import 'dart:ui';

import 'package:dartchess/dartchess.dart';

/// The file the king lands on when it castles, per side. Standard chess only —
/// this game offers no Chess960 mode, so the landing squares are fixed.
const int kKingSideLanding = 6;
const int kQueenSideLanding = 2;

/// The files the two rooks start on.
const int kKingSideRookFile = 7;
const int kQueenSideRookFile = 0;

/// Where a castling king really ends up, given the rook it castles with.
Square castlingKingDestination({required Square kingFrom, required Square rookFrom}) {
  final rank = rookFrom.rank.value;
  final kingSide = rookFrom.file.value > kingFrom.file.value;
  return Square.fromCoords(
      File(kingSide ? kKingSideLanding : kQueenSideLanding), Rank(rank));
}

/// True when [from]→[to] is a castle rather than a move onto an enemy piece.
///
/// The encoding is king-onto-own-rook, so a same-colour rook on the destination
/// is the tell. Everything that reasons about a move has to ask this: the board
/// must not fade the "captured" rook, the move list must not read `Kxh1`, and
/// the animation has to move two pieces instead of one.
bool isCastling(Board board, Square from, Square to) {
  final mover = board.pieceAt(from);
  final occupant = board.pieceAt(to);
  return mover != null &&
      occupant != null &&
      mover.role == Role.king &&
      occupant.role == Role.rook &&
      occupant.color == mover.color;
}

/// How a castle is written: kingside `O-O`, queenside `O-O-O`.
String castlingSan({required Square kingFrom, required Square rookFrom}) =>
    rookFrom.file.value > kingFrom.file.value ? 'O-O' : 'O-O-O';

/// The two travels a castle is made of, king first.
///
/// dartchess encodes castling as **king onto its own rook**, which is not where
/// either piece ends up. Before v6 the board took that pair literally: the king
/// appeared on the rook's square for a frame and the rook simply teleported.
List<(Square, Square)> castlingSlides({
  required Square kingFrom,
  required Square rookFrom,
}) {
  final rank = rookFrom.rank.value;
  final kingSide = rookFrom.file.value > kingFrom.file.value;
  final kingTo = Square.fromCoords(
      File(kingSide ? kKingSideLanding : kQueenSideLanding), Rank(rank));
  // The rook lands on the square the king crossed.
  final rookTo = Square.fromCoords(
      File(kingSide ? kKingSideLanding - 1 : kQueenSideLanding + 1), Rank(rank));
  return [(kingFrom, kingTo), (rookFrom, rookTo)];
}

/// The squares to *mark* for a selected piece.
///
/// Identical to the legal set except for a castling king, where each rook-square
/// target is swapped for the square the king truly ends on. Marking the rook
/// square read as "capture your own rook", and the only dot near the king's real
/// destination was an ordinary one-square move — so the correct castle was
/// offered nowhere.
SquareSet castlingAwareMarkers({
  required SquareSet legal,
  required Square from,
  required bool isKing,
}) {
  if (!isKing) return legal;
  final rank = from.rank.value;
  var out = legal;
  for (final rookFile in const [kKingSideRookFile, kQueenSideRookFile]) {
    final rook = Square.fromCoords(File(rookFile), Rank(rank));
    if (!legal.has(rook)) continue;
    out = out
        .withoutSquare(rook)
        .withSquare(castlingKingDestination(kingFrom: from, rookFrom: rook));
  }
  return out;
}

/// How far a travelling piece is drawn from its destination, at [progress].
///
/// A pure function of the two board positions and a 0…1 number — the number
/// comes from the Motion System's eased controller, never from a clock, so the
/// same progress always draws the same frame on a 60, 90 or 120 Hz panel.
Offset slideOffset({
  required Offset from,
  required Offset to,
  required double progress,
}) {
  final p = progress.clamp(0.0, 1.0);
  return (from - to) * (1 - p);
}
