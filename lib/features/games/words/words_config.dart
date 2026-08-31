import '../../../core/game/game_module.dart';
import 'logic/word_list.dart';

/// Shared setup for every Word game: how hard, and how many rounds.
class WordsConfig extends GameConfig {
  const WordsConfig({required this.difficulty, required this.rounds});

  final WordDifficulty difficulty;
  final int rounds;

  String get label => '${difficulty.label} · $rounds rounds';

  String get configLabel => difficulty.label;
}
