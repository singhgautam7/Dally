import 'dart:math';

import 'mafia_player.dart';
import 'mafia_rules.dart';
import 'mafia_word_pair.dart';

enum MafiaOutcome { villagersWin, impostersWin }

/// The result of resolving a vote round.
class MafiaVoteResult {
  const MafiaVoteResult.eliminated(this.eliminated)
      : tieBreak = const [],
        noElimination = false;
  const MafiaVoteResult.tieBreak(this.tieBreak)
      : eliminated = null,
        noElimination = false;
  const MafiaVoteResult.none()
      : eliminated = null,
        tieBreak = const [],
        noElimination = true;

  /// Index of the eliminated player, when there was a clear top vote.
  final int? eliminated;

  /// Tied player indexes to run a tie-break among (non-empty ⇒ start tie-break).
  final List<int> tieBreak;

  /// A tie persisted through the tie-break: nobody is eliminated this round.
  final bool noElimination;
}

/// One dealt game of Mafia: the fixed roster (dead and alive), the secret word
/// pair, the round counter, and the vote tally. All rules come from
/// [MafiaRules]; this class only holds state and sequences it. UI-agnostic and
/// fully unit-testable.
class MafiaGame {
  MafiaGame._({required this.wordPair, required this.players});

  /// Deals [names] into roles: [imposters] of them become imposters, chosen with
  /// [rng] (never seeded by names). Everyone shares [wordPair].
  factory MafiaGame.deal({
    required List<String> names,
    required int imposters,
    required MafiaWordPair wordPair,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final indexes = List.generate(names.length, (i) => i)..shuffle(r);
    final impSet = indexes.take(imposters).toSet();
    final players = [
      for (var i = 0; i < names.length; i++)
        MafiaPlayer(
          name: names[i],
          role: impSet.contains(i) ? MafiaRole.imposter : MafiaRole.villager,
        ),
    ];
    return MafiaGame._(wordPair: wordPair, players: players);
  }

  final MafiaWordPair wordPair;
  List<MafiaPlayer> players;
  int round = 1;

  final Map<int, int> _tally = {};
  Set<int>? _tieCandidates;

  Map<int, int> get tally => Map.unmodifiable(_tally);
  bool get inTieBreak => _tieCandidates != null;

  /// Indexes eligible to be voted for this round (alive; narrowed to the tied
  /// set during a tie-break).
  List<int> get candidates {
    final alive = [for (var i = 0; i < players.length; i++) if (players[i].alive) i];
    final tie = _tieCandidates;
    return tie == null ? alive : [for (final i in alive) if (tie.contains(i)) i];
  }

  int get aliveCount => players.where((p) => p.alive).length;

  /// Candidates a specific [voter] may pick — the round's candidates minus the
  /// voter themselves (you can never vote for yourself).
  List<int> candidatesFor(int voter) =>
      [for (final i in candidates) if (i != voter) i];

  /// The role each player sees on their card: villagers get the word, imposters
  /// the hint. Nothing here leaks who else holds which.
  String cardText(int index) =>
      players[index].isImposter ? wordPair.hint : wordPair.word;

  /// Records one ballot for [candidate]. Throws if the target isn't a valid
  /// candidate this round (dead, or outside a tie-break set).
  void castVote(int candidate) {
    if (!candidates.contains(candidate)) {
      throw ArgumentError('$candidate is not a valid candidate this round');
    }
    _tally.update(candidate, (v) => v + 1, ifAbsent: () => 1);
  }

  /// Tallies the votes and returns the outcome. A clear top → eliminated; a
  /// first-time tie → a tie-break among the tied; a tie that survives the
  /// tie-break → nobody out.
  MafiaVoteResult resolve() {
    final top = MafiaRules.topVoted(_tally);
    if (top.length == 1) {
      _tieCandidates = null;
      _tally.clear();
      return MafiaVoteResult.eliminated(top.first);
    }
    if (_tieCandidates != null) {
      // Tie again during the tie-break → no elimination, move on.
      _tieCandidates = null;
      _tally.clear();
      return const MafiaVoteResult.none();
    }
    _tieCandidates = top.toSet();
    _tally.clear();
    return MafiaVoteResult.tieBreak(top);
  }

  /// Open voting shortcut: the table agreed aloud, so eliminate directly.
  void eliminate(int index) {
    players[index] = players[index].copyWith(alive: false);
    _tieCandidates = null;
    _tally.clear();
  }

  /// Villagers win first (all imposters gone), else imposters (parity), else the
  /// game continues.
  MafiaOutcome? winner() {
    if (MafiaRules.villagersWin(players)) return MafiaOutcome.villagersWin;
    if (MafiaRules.impostersWin(players)) return MafiaOutcome.impostersWin;
    return null;
  }

  void nextRound() {
    round++;
    _tally.clear();
    _tieCandidates = null;
  }

  List<MafiaPlayer> get imposters =>
      [for (final p in players) if (p.isImposter) p];
}
