import '../../../core/game/game_module.dart';
import 'logic/mafia_rules.dart';
import 'logic/mafia_word_pair.dart';

/// How the table votes.
enum MafiaVoting {
  /// One ballot on the table — agree aloud, tap once.
  open,

  /// The phone goes round again; each player votes privately.
  private,
}

MafiaVoting votingFromId(String id) => id == 'private' ? MafiaVoting.private : MafiaVoting.open;

extension MafiaVotingX on MafiaVoting {
  String get id => name;
  String get label => this == MafiaVoting.private ? 'Private' : 'Open';
}

/// The dealt-game configuration produced by the setup screen: who's playing, how
/// hard the words are, and how the table votes. Roles and the word pair are
/// assigned at deal time (not stored here) so every game is fresh.
class MafiaConfig extends GameConfig {
  const MafiaConfig({
    required this.names,
    required this.difficulty,
    required this.voting,
  });

  final List<String> names;
  final MafiaDifficulty difficulty;
  final MafiaVoting voting;

  int get imposters => MafiaRules.imposterCount(names.length);

  String get label => '${names.length} players · ${difficulty.label}';

  MafiaConfig copyWith({List<String>? names, MafiaDifficulty? difficulty, MafiaVoting? voting}) =>
      MafiaConfig(
        names: names ?? this.names,
        difficulty: difficulty ?? this.difficulty,
        voting: voting ?? this.voting,
      );
}
