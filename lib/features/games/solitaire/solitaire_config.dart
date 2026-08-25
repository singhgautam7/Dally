import '../../../core/game/game_module.dart';

/// Klondike setup: how many cards a deal turns.
class SolitaireConfig extends GameConfig {
  const SolitaireConfig({required this.drawCount});

  /// 1 or 3.
  final int drawCount;

  String get label => 'Draw $drawCount';

  String get configLabel => label;
}
