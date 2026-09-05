import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/games/chess/chess_module.dart';
import '../../features/games/dots_and_boxes/dots_and_boxes_module.dart';
import '../../features/games/fifteen_puzzle/fifteen_puzzle_module.dart';
import '../../features/games/four_in_a_row/four_module.dart';
import '../../features/games/frog_hop/frog_hop_module.dart';
import '../../features/games/game_2048/game_2048_module.dart';
import '../../features/games/ludo/ludo_module.dart';
import '../../features/games/memory/memory_module.dart';
import '../../features/games/undercover/undercover_module.dart';
import '../../features/games/minesweeper/minesweeper_module.dart';
import '../../features/games/snake/snake_module.dart';
import '../../features/games/snakes_and_ladders/snakes_module.dart';
import '../../features/games/solitaire/solitaire_module.dart';
import '../../features/games/sudoku/sudoku_module.dart';
import '../../features/games/tic_tac_toe/tic_tac_toe_module.dart';
import '../../features/games/words/words_modules.dart';
import '../../features/games/quick_play/bottle_spinner/bottle_spinner_module.dart';
import '../../features/games/quick_play/coin_flip/coin_flip_module.dart';
import '../../features/games/quick_play/dice/dice_module.dart';
import '../../features/games/quick_play/random_choice/random_choice_module.dart';
import '../../features/games/quick_play/random_number/random_number_module.dart';
import '../../features/games/arcade/avoider_module.dart';
import '../../features/games/arcade/updraft_module.dart';
import '../../features/games/arcade/jumper_module.dart';
import '../../features/games/arcade/racer_module.dart';
import '../../features/games/arcade/reaction_module.dart';
import '../../features/games/arcade/tower_builder_module.dart';
import '../../features/games/mental_math/arithmetic_sprint_module.dart';
import '../../features/games/mental_math/calcudoku_module.dart';
import '../../features/games/mental_math/missing_operator_module.dart';
import '../../features/games/mental_math/sequence_module.dart';
import '../../features/games/mental_math/target_number_module.dart';
import '../../features/games/mental_math/true_false_module.dart';
import 'game_category.dart';
import 'game_module.dart';

/// The single place games are wired into the app. Home, filtering, stats and
/// routing all derive from this list — nothing else references a game module
/// directly. Adding a game means appending its module here (and nowhere else).
///
/// Order is the home-grid order from the design.
final List<GameModule> kGameModules = <GameModule>[
  Game2048Module(),
  MinesweeperModule(),
  SudokuModule(),
  SnakeModule(),
  MemoryModule(),
  FifteenPuzzleModule(),
  TicTacToeModule(),
  FourInARowModule(),
  ChessModule(),
  UndercoverModule(),
  DotsAndBoxesModule(),
  FrogHopModule(),
  LudoModule(),
  SnakesAndLaddersModule(),
  SolitaireModule(),

  // Word — two games sharing one bundled, offline word list.
  AnagramsModule(),
  WordSearchModule(),

  // Mental Math — six drills sharing one difficulty, set on home.
  ArithmeticSprintModule(),
  TrueFalseModule(),
  MissingOperatorModule(),
  TargetModule(),
  SequenceModule(),
  CalcudokuModule(),

  // Quick Play — no setup screen; opening one is using it.
  CoinFlipModule(),
  DiceModule(),
  BottleSpinnerModule(),
  RandomNumberModule(),
  RandomChoiceModule(),

  // Tiny Arcade — five one-input runs on the shared real-time loop.
  JumperModule(),
  UpdraftModule(),
  TowerBuilderModule(),
  ReactionModule(),
  RacerModule(),
  AvoiderModule(),
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

/// How many games are registered. Every counted string in the app derives from
/// this — nothing hardcodes the number of games.
final gameCountProvider = Provider<int>((ref) => ref.watch(gameRegistryProvider).length);

/// How many catalogue categories have at least one game.
final categoryCountProvider = Provider<int>((ref) {
  final present = <GameCategory>{};
  for (final m in ref.watch(gameRegistryProvider)) {
    present.add(m.category);
  }
  return present.length;
});

/// `"22 games · 6 categories"`, with singular forms. Used on Welcome and About.
final catalogueLineProvider = Provider<String>((ref) {
  final g = ref.watch(gameCountProvider);
  final c = ref.watch(categoryCountProvider);
  return '$g game${g == 1 ? '' : 's'} · $c categor${c == 1 ? 'y' : 'ies'}';
});
