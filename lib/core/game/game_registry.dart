import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_module.dart';

/// The single place games are wired into the app. Home, filtering, stats and
/// routing all derive from this list — nothing else references a game module
/// directly. Adding a game means appending its module here (and nowhere else).
///
/// Populated as each game module lands in `features/games/…`.
const List<GameModule> kGameModules = <GameModule>[
  // game_2048, minesweeper, sudoku, snake, memory, fifteen_puzzle,
  // tic_tac_toe, chess … registered here as they are implemented.
];

/// Exposes the ordered module list to the widget tree.
final gameRegistryProvider = Provider<List<GameModule>>((ref) => kGameModules);

/// Looks up a module by its stable id, or null if unknown (e.g. a stale deep
/// link after a game is removed).
final gameByIdProvider = Provider.family<GameModule?, String>((ref, id) {
  for (final m in ref.watch(gameRegistryProvider)) {
    if (m.id == id) return m;
  }
  return null;
});
