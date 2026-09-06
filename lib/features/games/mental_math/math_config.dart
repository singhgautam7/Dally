import '../../../core/game/game_module.dart';
import 'math_difficulty.dart';

/// What a Mental Math setup screen produces: the level for this run.
///
/// The six drills used to share one level chosen from a control on Home, with
/// no setup screen of their own — so a drill started the moment you tapped it
/// and the only place to see what it was were the words on the tile. They now
/// follow the same Home → Setup → Play flow as every other game.
class MathConfig extends GameConfig {
  const MathConfig({required this.difficulty});

  final MathDifficulty difficulty;

  String get label => difficulty.label;
}
