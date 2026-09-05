import '../../../core/game/game_module.dart';
import 'logic/undercover_game.dart';
import 'logic/word_pair.dart';

/// How the table votes.
enum UndercoverVoting {
  /// One ballot on the table — one tap each, in the open.
  open,

  /// The phone goes round again; each player votes privately.
  private,
}

UndercoverVoting votingFromId(String id) =>
    id == 'private' ? UndercoverVoting.private : UndercoverVoting.open;

extension UndercoverVotingX on UndercoverVoting {
  String get id => name;
  String get label => this == UndercoverVoting.private ? 'Private' : 'Open ballot';
}

/// The dealt-game configuration the setup screen produces: who is playing, how
/// many are hiding, how close the two words are, and how the table votes.
/// Roles and the pair are drawn at deal time, so every game is fresh.
class UndercoverConfig extends GameConfig {
  const UndercoverConfig({
    required this.names,
    required this.undercover,
    required this.mrWhite,
    required this.difficulty,
    required this.voting,
  });

  final List<String> names;

  /// How many Undercover, 1–3. Three unlocks at 11 players.
  final int undercover;

  /// Whether one player sees no word at all.
  final bool mrWhite;

  final WordDifficulty difficulty;
  final UndercoverVoting voting;

  int get playerCount => names.length;

  int get hiding => undercover + (mrWhite ? 1 : 0);

  String get label =>
      '${names.length} players · ${difficulty.label}${mrWhite ? ' · Mr. White' : ''}';

  /// Stat key, so each table size keeps its own record.
  String get configLabel => '${names.length} players';

  /// Clamps [undercover] to what the roster can carry, so a shrinking table can
  /// never deal more hiders than civilians.
  UndercoverConfig normalised() {
    final maxUndercover = UndercoverRules.maxUndercoverFor(names.length);
    var u = undercover.clamp(1, maxUndercover);
    // The civilians must outnumber the people hiding at the deal.
    while (u + (mrWhite ? 1 : 0) >= names.length - 1 && u > 1) {
      u--;
    }
    return UndercoverConfig(
      names: names,
      undercover: u,
      mrWhite: mrWhite,
      difficulty: difficulty,
      voting: voting,
    );
  }

  UndercoverConfig copyWith({
    List<String>? names,
    int? undercover,
    bool? mrWhite,
    WordDifficulty? difficulty,
    UndercoverVoting? voting,
  }) =>
      UndercoverConfig(
        names: names ?? this.names,
        undercover: undercover ?? this.undercover,
        mrWhite: mrWhite ?? this.mrWhite,
        difficulty: difficulty ?? this.difficulty,
        voting: voting ?? this.voting,
      );
}
