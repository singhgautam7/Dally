import 'dart:math' as math;
import 'dart:ui';

import 'carrom_table.dart';

/// The rule switches the setup screen exposes.
class CarromRules {
  const CarromRules({this.queenMustBeCovered = true, this.strikerFoulReturnsCoin = true});

  /// Potting the queen only counts if you pot one of your own coins to cover
  /// it. Off, the queen counts the moment it drops.
  final bool queenMustBeCovered;

  /// Pocketing your own striker puts one of your potted coins back on the
  /// board. Off, a striker foul only costs the turn.
  final bool strikerFoulReturnsCoin;
}

/// Everything one shot did, in the order a player would say it.
class ShotOutcome {
  const ShotOutcome({
    required this.player,
    required this.ownPotted,
    required this.opponentPotted,
    required this.strikerPotted,
    required this.queenPotted,
    required this.queenReturned,
    required this.touchedNothing,
    required this.extraTurn,
    required this.winner,
  });

  final int player;
  final int ownPotted;
  final int opponentPotted;
  final bool strikerPotted;
  final bool queenPotted;

  /// The queen went down earlier but was not covered, so it came back.
  final bool queenReturned;

  final bool touchedNothing;
  final bool extraTurn;
  final int? winner;

  bool get isFoul => strikerPotted || touchedNothing;
}

/// Carrom rules over the pure [CarromTable] physics.
///
/// Two or four players; with four, seats 0 and 2 are one team and 1 and 3 the
/// other, so a team's coins are shared. The board never rotates — each seat
/// simply shoots from its own edge, which is how it works on a real board and
/// avoids spinning the whole layout between turns.
class CarromGame {
  CarromGame({
    this.playerCount = 2,
    this.rules = const CarromRules(),
    CarromPhysics physics = const CarromPhysics(),
    int firstPlayer = 0,
  })  : assert(playerCount == 2 || playerCount == 4),
        table = CarromTable(physics: physics),
        current = firstPlayer {
    _arrange();
    _placeStriker();
  }

  final int playerCount;
  final CarromRules rules;
  final CarromTable table;

  int current;
  int? winner;
  bool get isFinished => winner != null;

  /// Coins each team has banked, by team index (0 or 1).
  final List<int> banked = [0, 0];

  /// The team that owns the queen once it is settled.
  int? queenOwner;

  /// The team that potted the queen and still owes a cover.
  int? queenPending;

  int teamOf(int player) => player % 2;

  CoinKind suitOfTeam(int team) => team == 0 ? CoinKind.light : CoinKind.dark;

  CoinKind get currentSuit => suitOfTeam(teamOf(current));

  /// Nine a side.
  static const int coinsPerSide = 9;

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// The opening flower: the queen at the centre, six coins around it, twelve
  /// around those, alternating so neither side is clustered.
  void _arrange() {
    final p = table.physics;
    const centre = Offset(0.5, 0.5);
    table.discs.add(Disc(
      kind: CoinKind.queen,
      position: centre,
      radius: p.coinRadius,
      mass: 1,
    ));
    void ring(int count, double radius, int phase) {
      for (var i = 0; i < count; i++) {
        final angle = (i / count) * math.pi * 2 + phase * 0.15;
        table.discs.add(Disc(
          kind: (i.isEven ? CoinKind.light : CoinKind.dark),
          position: centre + Offset(math.cos(angle), math.sin(angle)) * radius,
          radius: p.coinRadius,
          mass: 1,
        ));
      }
    }

    ring(6, p.coinRadius * 2.05, 0);
    ring(12, p.coinRadius * 4.1, 1);
  }

  void _placeStriker() {
    final existing = table.striker;
    if (existing != null) return;
    table.discs.add(Disc(
      kind: CoinKind.striker,
      position: strikerHome(current),
      radius: table.physics.strikerRadius,
      mass: 1.6,
    ));
  }

  /// How far in from the rail a seat's baseline sits.
  static const double baselineInset = 0.14;

  /// The centre of [player]'s baseline. Seats sit opposite one another, so the
  /// two-player game is bottom against top.
  Offset strikerHome(int player) => switch (player) {
        0 => const Offset(0.5, 1 - baselineInset),
        1 => const Offset(0.5, baselineInset),
        2 => const Offset(baselineInset, 0.5),
        _ => const Offset(1 - baselineInset, 0.5),
      };

  /// True when [player]'s baseline runs left-to-right rather than up-and-down.
  bool baselineIsHorizontal(int player) => player < 2;

  /// How far along its baseline the striker may be placed, as a fraction 0–1.
  static const double baselineHalfLength = 0.28;

  /// Clamps a proposed striker position onto [player]'s baseline.
  Offset clampToBaseline(int player, Offset proposed) {
    final home = strikerHome(player);
    if (baselineIsHorizontal(player)) {
      return Offset(
        proposed.dx.clamp(0.5 - baselineHalfLength, 0.5 + baselineHalfLength),
        home.dy,
      );
    }
    return Offset(
      home.dx,
      proposed.dy.clamp(0.5 - baselineHalfLength, 0.5 + baselineHalfLength),
    );
  }

  // ── Shooting ──────────────────────────────────────────────────────────────

  bool get awaitingShot => table.atRest && !isFinished;

  /// Places the striker (already clamped) and flicks it.
  void shoot({required Offset from, required Offset direction, required double power}) {
    if (!awaitingShot) return;
    final s = table.striker;
    if (s == null) {
      _placeStriker();
    }
    final striker = table.striker!;
    striker
      ..position = clampToBaseline(current, from)
      ..pocketed = false;
    table.shoot(direction, power);
  }

  /// Reads the finished shot and applies the rules. Call once the table is at
  /// rest; calling it twice for one shot would double-count.
  ShotOutcome resolveShot() {
    final player = current;
    final team = teamOf(player);
    final suit = suitOfTeam(team);

    var own = 0;
    var opponent = 0;
    var strikerPotted = false;
    var queenPotted = false;

    for (final disc in table.pocketedThisShot) {
      switch (disc.kind) {
        case CoinKind.striker:
          strikerPotted = true;
        case CoinKind.queen:
          queenPotted = true;
        case CoinKind.light:
        case CoinKind.dark:
          disc.kind == suit ? own++ : opponent++;
      }
    }

    banked[team] += own;
    banked[1 - team] += opponent;

    final touchedNothing = !table.strikerTouchedCoin;

    // The queen. Potting it earns nothing until it is covered by one of your
    // own coins — on the same shot, or the next one.
    var queenReturned = false;
    if (queenPotted) {
      if (!rules.queenMustBeCovered || own > 0) {
        queenOwner = team;
        queenPending = null;
      } else {
        queenPending = team;
      }
    } else if (queenPending == team) {
      if (own > 0) {
        queenOwner = team;
        queenPending = null;
      } else {
        _returnQueen();
        queenPending = null;
        queenReturned = true;
      }
    }

    if (strikerPotted && rules.strikerFoulReturnsCoin && banked[team] > 0) {
      banked[team]--;
      _returnCoin(suit);
    }

    final wonNow = banked[team] >= coinsPerSide &&
        (!rules.queenMustBeCovered || queenOwner != null) &&
        !strikerPotted;
    if (wonNow) winner = player;

    final extraTurn = !wonNow && own > 0 && !strikerPotted;
    if (!wonNow && !extraTurn) current = (current + 1) % playerCount;

    // Only now is it known whose baseline the striker belongs on.
    _resetStriker();
    table.pocketedThisShot.clear();
    return ShotOutcome(
      player: player,
      ownPotted: own,
      opponentPotted: opponent,
      strikerPotted: strikerPotted,
      queenPotted: queenPotted,
      queenReturned: queenReturned,
      touchedNothing: touchedNothing,
      extraTurn: extraTurn,
      winner: winner,
    );
  }

  void _resetStriker() {
    final s = table.striker ??
        table.discs.firstWhere((d) => d.kind == CoinKind.striker);
    s
      ..pocketed = false
      ..velocity = Offset.zero
      ..position = strikerHome(current);
  }

  void _returnQueen() {
    final queen = table.discs.firstWhere((d) => d.kind == CoinKind.queen);
    queen
      ..pocketed = false
      ..velocity = Offset.zero
      ..position = _freeSpotNearCentre(queen.radius);
  }

  void _returnCoin(CoinKind suit) {
    for (final disc in table.discs) {
      if (disc.kind == suit && disc.pocketed) {
        disc
          ..pocketed = false
          ..velocity = Offset.zero
          ..position = _freeSpotNearCentre(disc.radius);
        return;
      }
    }
  }

  /// A spot near the centre that nothing is standing on. Spiralling outwards
  /// beats a fixed point: dropping a returned coin on top of another would
  /// have the solver fling both across the board.
  Offset _freeSpotNearCentre(double radius) {
    const centre = Offset(0.5, 0.5);
    for (var ring = 0; ring < 8; ring++) {
      final distance = radius * 2.1 * ring;
      final slots = ring == 0 ? 1 : ring * 6;
      for (var i = 0; i < slots; i++) {
        final angle = (i / slots) * math.pi * 2;
        final candidate =
            centre + Offset(math.cos(angle), math.sin(angle)) * distance;
        final clear = table.live.every((d) =>
            (d.position - candidate).distance >= d.radius + radius + 0.002);
        if (clear) return candidate;
      }
    }
    return centre;
  }
}
