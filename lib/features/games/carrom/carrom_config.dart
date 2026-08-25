import '../../../core/game/game_module.dart';
import 'logic/carrom_game.dart';

/// Carrom setup: seats, names and the rule switches.
class CarromConfig extends GameConfig {
  const CarromConfig({
    required this.playerCount,
    required this.names,
    required this.rules,
  });

  /// 2, or 4 playing as two teams.
  final int playerCount;
  final List<String> names;
  final CarromRules rules;

  String nameOf(int player) => names[player];

  /// With four seats it is seats 0+2 against 1+3.
  String teamName(int team) => playerCount == 2
      ? names[team]
      : '${names[team]} & ${names[team + 2]}';

  String get label =>
      playerCount == 2 ? '${names[0]} vs ${names[1]}' : '${teamName(0)} vs ${teamName(1)}';

  String get configLabel => playerCount == 2 ? 'Singles' : 'Doubles';
}
