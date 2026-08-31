import '../../../core/game/game_module.dart';
import 'logic/ludo.dart';

/// Ludo setup: how many seats, their names, and the rule switches.
class LudoConfig extends GameConfig {
  const LudoConfig({
    required this.playerCount,
    required this.names,
    required this.rules,
    required this.firstPlayer,
  });

  final int playerCount;
  final List<String> names;
  final LudoRules rules;
  final int firstPlayer;

  String nameOf(int player) => names[player];

  String get label => '$playerCount players · ${names.join(', ')}';

  /// Stat key, so each player count keeps its own record.
  String get configLabel => '$playerCount players';
}
