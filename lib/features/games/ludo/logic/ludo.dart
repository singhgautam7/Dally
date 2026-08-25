import 'package:flutter/foundation.dart';

import '../../../../core/util/dally_random.dart';

/// Where a token sits on its own journey.
///
/// One integer carries the whole position, which is what keeps the rules
/// arithmetic rather than a pile of cases:
///
/// * `kInBase` — still in the yard.
/// * `1 … 51`  — on the shared ring, `ringStart(player) + step - 1` mod 52.
/// * `52 … 56` — the player's private home column, five squares nobody else
///   can reach or capture on.
/// * `kHome`   — finished.
const int kInBase = 0;
const int kRingSquares = 52;
const int kLastRingStep = 51;
const int kHome = 57;

/// Each seat joins the ring a quarter turn apart.
int ringStart(int player) => player * 13;

/// The ring square a token on [step] occupies, or -1 when it is not on the ring.
int ringIndexOf(int player, int step) =>
    (step >= 1 && step <= kLastRingStep) ? (ringStart(player) + step - 1) % kRingSquares : -1;

/// Squares where a token can never be captured: the four entry squares plus the
/// four star squares eight along from each.
const Set<int> kSafeRingSquares = {0, 8, 13, 21, 26, 34, 39, 47};

/// The rule switches the setup screen exposes. The defaults are the ones people
/// actually play with.
class LudoRules {
  const LudoRules({
    this.sixToLeaveBase = true,
    this.extraTurnOnSix = true,
    this.extraTurnOnCapture = true,
    this.exactFinish = true,
  });

  /// A token only leaves the yard on a six. Off makes for much shorter games.
  final bool sixToLeaveBase;

  /// A six is rolled again — capped at three in a row, which forfeits the turn.
  final bool extraTurnOnSix;

  final bool extraTurnOnCapture;

  /// The home square must be reached on an exact count; an overshoot is not a
  /// legal move. Off lets any roll that reaches or passes it finish the token.
  final bool exactFinish;
}

/// One legal application of the current die.
class LudoMove {
  const LudoMove({
    required this.token,
    required this.from,
    required this.to,
    required this.captured,
  });

  /// Index of the moving token within its player's four.
  final int token;
  final int from;
  final int to;

  /// Tokens sent back to the yard, as `(player, token)` pairs.
  final List<(int, int)> captured;

  bool get leavesBase => from == kInBase;
  bool get finishes => to == kHome;
}

/// The result of applying a move — enough for the screen to narrate and animate
/// without re-deriving anything.
class LudoTurn {
  const LudoTurn({
    required this.move,
    required this.extraTurn,
    required this.playerFinished,
    required this.winner,
  });

  final LudoMove move;
  final bool extraTurn;

  /// True when this move brought the mover's last token home.
  final bool playerFinished;
  final int? winner;
}

/// Ludo — the Pachisi family, four tokens a seat around a shared ring.
///
/// Pure rules: no widgets, no clock, no randomness of its own beyond the
/// [DallyRandom] handed to [roll], so a whole game replays from a seed.
class LudoGame {
  LudoGame({
    required this.playerCount,
    this.rules = const LudoRules(),
    int firstPlayer = 0,
  })  : assert(playerCount >= 2 && playerCount <= 4),
        current = firstPlayer,
        tokens = List.generate(playerCount, (_) => List.filled(4, kInBase));

  final int playerCount;
  final LudoRules rules;

  /// `tokens[player][token]` — the step each token stands on.
  final List<List<int>> tokens;

  int current;

  /// The face showing, or null before the first roll of a turn.
  int? die;

  /// Consecutive sixes this turn; three forfeits it.
  int _sixesInARow = 0;

  /// True when the last roll could not be used and the turn passed with it.
  /// The die stays on screen so the strip can explain why.
  bool stuck = false;

  int? winner;
  bool get isFinished => winner != null;

  /// True once the die has been rolled and there is something to do with it.
  bool get awaitingMove => die != null && !stuck && !isFinished;

  int homeCount(int player) => tokens[player].where((t) => t == kHome).length;

  /// Rolls for the player on turn. Returns the face. When nothing can be done
  /// with it the turn passes immediately and [die] is left showing so the
  /// screen can say why.
  int roll(DallyRandom random) => rollFace(random.range(1, 6));

  /// The roll with the face already decided. Public so a test can put a rule
  /// under a specific face instead of fishing for it in a seeded stream.
  @visibleForTesting
  int rollFace(int face) {
    if (isFinished) throw StateError('roll after the game ended');
    if (awaitingMove) throw StateError('roll while a move is pending');
    stuck = false;
    die = face;
    _sixesInARow = face == 6 ? _sixesInARow + 1 : 0;

    // Three sixes in a row forfeits the turn, tokens untouched. Without it a
    // lucky streak never ends.
    if (rules.extraTurnOnSix && _sixesInARow >= 3) {
      _passTurn(keepDie: true);
      return face;
    }
    if (legalMoves().isEmpty) _passTurn(keepDie: true);
    return face;
  }

  /// Every move available to the player on turn with the current [die].
  List<LudoMove> legalMoves() {
    final face = die;
    if (face == null || stuck || isFinished) return const [];
    final moves = <LudoMove>[];
    for (var i = 0; i < 4; i++) {
      final move = _moveFor(i, face);
      if (move != null) moves.add(move);
    }
    return moves;
  }

  LudoMove? _moveFor(int token, int face) {
    final from = tokens[current][token];
    if (from == kHome) return null;

    late final int to;
    if (from == kInBase) {
      if (rules.sixToLeaveBase && face != 6) return null;
      to = 1;
    } else {
      final target = from + face;
      if (target > kHome) {
        if (rules.exactFinish) return null;
        to = kHome;
      } else {
        to = target;
      }
    }

    // A seat never stacks two of its own tokens on one square.
    if (to != kHome && tokens[current].contains(to)) return null;

    return LudoMove(token: token, from: from, to: to, captured: _capturesAt(to));
  }

  /// Opponents standing on the ring square [to] lands on. Nothing is capturable
  /// off the ring, and nothing on a safe square.
  List<(int, int)> _capturesAt(int to) {
    final ring = ringIndexOf(current, to);
    if (ring < 0 || kSafeRingSquares.contains(ring)) return const [];
    final hits = <(int, int)>[];
    for (var p = 0; p < playerCount; p++) {
      if (p == current) continue;
      for (var i = 0; i < 4; i++) {
        if (ringIndexOf(p, tokens[p][i]) == ring) hits.add((p, i));
      }
    }
    return hits;
  }

  /// Applies [move], sends any captures home, and hands on the turn unless the
  /// mover earned another. Returns null if the move is not currently legal.
  LudoTurn? play(LudoMove move) {
    final face = die;
    if (face == null || stuck || isFinished) return null;
    final verified = _moveFor(move.token, face);
    if (verified == null || verified.to != move.to) return null;

    tokens[current][verified.token] = verified.to;
    for (final (p, i) in verified.captured) {
      tokens[p][i] = kInBase;
    }

    final mover = current;
    final finished = homeCount(mover) == 4;
    if (finished) winner = mover;

    final extra = !finished &&
        ((rules.extraTurnOnSix && face == 6) ||
            (rules.extraTurnOnCapture && verified.captured.isNotEmpty));

    die = null;
    if (finished) {
      // Game over; the turn stays put so the board reads as the mover's.
    } else if (extra) {
      if (face != 6) _sixesInARow = 0;
    } else {
      _passTurn();
    }

    return LudoTurn(
      move: verified,
      extraTurn: extra,
      playerFinished: finished,
      winner: winner,
    );
  }

  void _passTurn({bool keepDie = false}) {
    if (keepDie) {
      stuck = true;
    } else {
      die = null;
    }
    _sixesInARow = 0;
    current = (current + 1) % playerCount;
  }
}
