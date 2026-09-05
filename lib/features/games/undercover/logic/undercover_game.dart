import '../../../../core/util/dally_random.dart';
import 'word_pair.dart';

/// What a player is holding.
///
/// Civilians share the majority word. The undercover holds a
/// related-but-different one. **Mr. White holds no word at all** and has to work
/// out what everyone else is describing.
enum UndercoverRole { civilian, undercover, mrWhite }

extension UndercoverRoleX on UndercoverRole {
  String get label => switch (this) {
        UndercoverRole.civilian => 'Civilian',
        UndercoverRole.undercover => 'Undercover',
        UndercoverRole.mrWhite => 'Mr. White',
      };

  /// Everyone who is not a civilian is hiding, and the civilians win only when
  /// every one of them is out.
  bool get isHiding => this != UndercoverRole.civilian;
}

/// One player in a dealt game.
class UndercoverPlayer {
  const UndercoverPlayer({required this.name, required this.role, this.alive = true});

  final String name;
  final UndercoverRole role;
  final bool alive;

  UndercoverPlayer copyWith({bool? alive}) =>
      UndercoverPlayer(name: name, role: role, alive: alive ?? this.alive);

  @override
  String toString() => 'UndercoverPlayer($name, ${role.name}, ${alive ? 'in' : 'out'})';
}

/// Who won.
enum UndercoverOutcome {
  /// Every Undercover and Mr. White is out.
  civilians,

  /// The hiding players equal the civilians still in.
  undercover,

  /// Mr. White named the civilians' word after being voted out — alone, and
  /// immediately.
  mrWhite,
}

/// The result of resolving one vote.
class VoteResult {
  const VoteResult.eliminated(this.eliminated) : tied = false;
  const VoteResult.tie()
      : eliminated = null,
        tied = true;

  /// Index of the player voted out, or null on a tie.
  final int? eliminated;

  /// A tied vote eliminates nobody; play goes straight to the next describe
  /// round with the speaking order rotated by one.
  final bool tied;
}

/// One dealt game of Undercover.
///
/// The loop is `describe → vote → reveal`, repeated. There is **no night
/// phase**: nothing happens between rounds that the table cannot see.
///
/// Pure rules: no widgets, no clock. Randomness is injected, so a seeded
/// instance deals the same roles and the same pair every time.
class UndercoverGame {
  UndercoverGame._({
    required this.pair,
    required this.players,
    required List<int> order,
  }) : _order = order;

  /// Deals [names] into roles.
  ///
  /// [undercover] of them become Undercover, and one more becomes Mr. White if
  /// [mrWhite] is set. Roles are drawn with [rng] and never from the names, so
  /// sitting first is not a tell.
  factory UndercoverGame.deal({
    required List<String> names,
    required int undercover,
    required bool mrWhite,
    required UndercoverWordPair pair,
    required DallyRandom rng,
  }) {
    assert(names.length >= UndercoverRules.minPlayers);
    assert(undercover >= 1);
    assert(undercover + (mrWhite ? 1 : 0) < names.length,
        'the civilians must outnumber the people hiding at the deal');

    final shuffled = rng.sample(undercover + (mrWhite ? 1 : 0), names.length);
    final undercoverSeats = shuffled.take(undercover).toSet();
    final whiteSeat = mrWhite ? shuffled.last : null;

    final players = [
      for (var i = 0; i < names.length; i++)
        UndercoverPlayer(
          name: names[i],
          role: i == whiteSeat
              ? UndercoverRole.mrWhite
              : undercoverSeats.contains(i)
                  ? UndercoverRole.undercover
                  : UndercoverRole.civilian,
        ),
    ];

    // The speaking order is its own shuffle: who opens should not follow from
    // who is holding what.
    final order = rng.shuffled(List<int>.generate(names.length, (i) => i));
    return UndercoverGame._(pair: pair, players: players, order: order);
  }

  final UndercoverWordPair pair;
  List<UndercoverPlayer> players;

  /// Seat indexes in speaking order. Rotated by one after a tied vote so the
  /// same person does not open twice.
  final List<int> _order;

  int round = 1;

  /// voter → candidate. The tally is **derived** from this rather than kept
  /// alongside it: a ballot box that stores only counts cannot take a vote back
  /// without guessing whose it was.
  final Map<int, int> _ballots = {};

  /// True once Mr. White has been voted out and is taking his one guess.
  bool awaitingWhiteGuess = false;

  UndercoverOutcome? _outcome;
  UndercoverOutcome? get outcome => _outcome;

  /// The word Mr. White named, once he has guessed.
  String? whiteGuess;

  /// candidate → votes, derived from the ballots.
  Map<int, int> get tally {
    final out = <int, int>{};
    for (final candidate in _ballots.values) {
      out.update(candidate, (v) => v + 1, ifAbsent: () => 1);
    }
    return out;
  }

  List<int> get aliveIndexes =>
      [for (var i = 0; i < players.length; i++) if (players[i].alive) i];

  int get aliveCount => aliveIndexes.length;

  int get civiliansLeft => players
      .where((p) => p.alive && p.role == UndercoverRole.civilian)
      .length;

  int get hidingLeft =>
      players.where((p) => p.alive && p.role.isHiding).length;

  int get undercoverLeft =>
      players.where((p) => p.alive && p.role == UndercoverRole.undercover).length;

  /// The living players in speaking order, for the describe round.
  List<int> get speakingOrder => [for (final i in _order) if (players[i].alive) i];

  /// What a player sees on their card: their word, or nothing for Mr. White.
  String? wordFor(int index) => switch (players[index].role) {
        UndercoverRole.civilian => pair.civilian,
        UndercoverRole.undercover => pair.undercover,
        UndercoverRole.mrWhite => null,
      };

  // ── Voting ────────────────────────────────────────────────────────────────

  /// Who [voter] may vote for: everyone still in except themselves.
  List<int> candidatesFor(int voter) =>
      [for (final i in aliveIndexes) if (i != voter) i];

  bool hasVoted(int voter) => _ballots.containsKey(voter);

  /// Who [voter] voted for, or null.
  int? ballotOf(int voter) => _ballots[voter];

  int get votesCast => _ballots.length;

  /// Every living player has had their say.
  bool get ballotComplete => _ballots.length == aliveCount;

  /// The next living player who has not voted, or null once the ballot is in.
  int? get nextVoter {
    for (final i in aliveIndexes) {
      if (!_ballots.containsKey(i)) return i;
    }
    return null;
  }

  /// Records one ballot. A player may not vote for themselves, and may not vote
  /// twice — [retract] takes a vote back instead.
  void castVote({required int voter, required int candidate}) {
    if (!players[voter].alive) {
      throw ArgumentError('$voter is out and cannot vote');
    }
    if (voter == candidate) {
      throw ArgumentError('a player may not vote for themselves');
    }
    if (!players[candidate].alive) {
      throw ArgumentError('$candidate is already out');
    }
    if (_ballots.containsKey(voter)) return;
    _ballots[voter] = candidate;
  }

  /// Takes [voter]'s ballot back, whoever it was for.
  void retract(int voter) => _ballots.remove(voter);

  /// Takes back the most recent vote cast **for [candidate]** — "tap again to
  /// take a vote back". Returns the voter freed, or null when nobody voted for
  /// them, so a tap on a name with no votes can never remove someone else's.
  int? retractVoteFor(int candidate) {
    int? last;
    for (final e in _ballots.entries) {
      if (e.value == candidate) last = e.key;
    }
    if (last != null) _ballots.remove(last);
    return last;
  }

  /// The seat(s) on the most votes. More than one is a tie.
  List<int> get leaders {
    final counts = tally;
    if (counts.isEmpty) return const [];
    final top = counts.values.reduce((a, b) => a > b ? a : b);
    final out = [for (final e in counts.entries) if (e.value == top) e.key];
    out.sort();
    return out;
  }

  /// Tallies the vote. A clear top is eliminated; a tie eliminates nobody.
  VoteResult resolve() {
    final top = leaders;
    _ballots.clear();
    if (top.length != 1) {
      // The order rotates by one so the same person does not open twice.
      _order.add(_order.removeAt(0));
      return const VoteResult.tie();
    }
    return VoteResult.eliminated(top.first);
  }

  /// Eliminates [index] and works out what that means.
  ///
  /// Voting out Mr. White does **not** end the round: he gets one last chance to
  /// name the civilians' word, and [awaitingWhiteGuess] is set until he does.
  UndercoverRole eliminate(int index) {
    final role = players[index].role;
    players[index] = players[index].copyWith(alive: false);
    if (role == UndercoverRole.mrWhite) {
      awaitingWhiteGuess = true;
    } else {
      _outcome = _check();
    }
    return role;
  }

  /// Mr. White's last chance. A correct guess wins the whole game for him
  /// alone, immediately; a wrong one simply leaves him eliminated and play
  /// continues.
  bool guessWord(String guess) {
    awaitingWhiteGuess = false;
    whiteGuess = guess.trim();
    final right = UndercoverRules.guessMatches(guess, pair.civilian);
    _outcome = right ? UndercoverOutcome.mrWhite : _check();
    return right;
  }

  /// Mr. White gave up rather than guessing.
  void declineGuess() {
    awaitingWhiteGuess = false;
    _outcome = _check();
  }

  UndercoverOutcome? _check() => UndercoverRules.outcomeFor(players);

  bool get isOver => _outcome != null;

  void nextRound() {
    round++;
    _ballots.clear();
  }

  /// Everyone's role, for the end-of-game card.
  List<UndercoverPlayer> get roster => List.unmodifiable(players);
}

/// Every policy that might be tuned, kept out of the game loop.
class UndercoverRules {
  const UndercoverRules._();

  static const int minPlayers = 4;
  static const int maxPlayers = 20;

  /// How many Undercover a table of [players] may have. Three unlocks at 11,
  /// which is the line the setup screen draws.
  static int maxUndercoverFor(int players) {
    if (players >= 11) return 3;
    if (players >= 7) return 2;
    return 1;
  }

  /// The suggested count for a fresh table.
  static int suggestedUndercoverFor(int players) => players >= 11 ? 2 : 1;

  /// Civilians win the moment every Undercover **and** Mr. White is out.
  static bool civiliansWin(List<UndercoverPlayer> players) =>
      !players.any((p) => p.alive && p.role.isHiding);

  /// Undercover win at parity — when the players still hiding equal the
  /// civilians still in. Checked only after [civiliansWin] is false.
  static bool undercoverWin(List<UndercoverPlayer> players) {
    var hiding = 0, civilians = 0;
    for (final p in players) {
      if (!p.alive) continue;
      p.role.isHiding ? hiding++ : civilians++;
    }
    return hiding > 0 && hiding >= civilians;
  }

  static UndercoverOutcome? outcomeFor(List<UndercoverPlayer> players) {
    if (civiliansWin(players)) return UndercoverOutcome.civilians;
    if (undercoverWin(players)) return UndercoverOutcome.undercover;
    return null;
  }

  /// Spelling is forgiven — near misses count.
  ///
  /// The comparison is case- and space-insensitive, ignores anything that is
  /// not a letter, and allows one edit (an insertion, a deletion or a
  /// substitution) for words of five letters or more. A guess shouted across a
  /// table should not lose on a doubled consonant.
  static bool guessMatches(String guess, String word) {
    final a = _normalise(guess);
    final b = _normalise(word);
    if (a.isEmpty) return false;
    if (a == b) return true;
    if (b.length < 5) return false;
    return _withinOneEdit(a, b);
  }

  static String _normalise(String s) {
    final buffer = StringBuffer();
    for (final rune in s.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      if (RegExp('[a-z]').hasMatch(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  /// Levenshtein distance ≤ 1, without building the whole matrix.
  static bool _withinOneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length == b.length) {
        i++;
        j++;
      } else if (a.length > b.length) {
        i++;
      } else {
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }

  /// Validates a roster, returning a human error or null when it is good to
  /// deal. Names are trimmed and unique case-insensitively.
  static String? rosterError(List<String> names) {
    final trimmed = names.map((n) => n.trim()).toList();
    if (trimmed.any((n) => n.isEmpty)) return 'Every player needs a name';
    final lower = trimmed.map((n) => n.toLowerCase()).toList();
    if (lower.toSet().length != lower.length) return 'Names must be unique';
    if (trimmed.length < minPlayers) return 'Need at least $minPlayers players';
    if (trimmed.length > maxPlayers) return 'At most $maxPlayers players';
    return null;
  }
}
