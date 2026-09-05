/// Difficulty is the **distance between the two words**, and it is the only
/// knob that changes how hard a game is.
enum WordDifficulty { easy, normal, hard }

WordDifficulty difficultyFromId(String id) => switch (id) {
      'easy' => WordDifficulty.easy,
      'hard' => WordDifficulty.hard,
      _ => WordDifficulty.normal,
    };

extension WordDifficultyX on WordDifficulty {
  String get id => name;
  String get label => switch (this) {
        WordDifficulty.easy => 'Easy',
        WordDifficulty.normal => 'Normal',
        WordDifficulty.hard => 'Hard',
      };
  String get caption => switch (this) {
        WordDifficulty.easy => 'Obviously adjacent — a careless clue gives it away.',
        WordDifficulty.normal => 'The same family, one step apart.',
        WordDifficulty.hard => 'Almost the same thing. A careless clue fits both.',
      };
}

/// One bundled pair: the majority word and the related-but-different one the
/// undercover sees instead. They are never synonyms — the second word sits
/// *near* the first, not on it.
class UndercoverWordPair {
  const UndercoverWordPair({
    required this.id,
    required this.civilian,
    required this.undercover,
    required this.difficulty,
  });

  final String id;
  final String civilian;
  final String undercover;
  final WordDifficulty difficulty;

  /// The same pair the other way round. Which of the two is the majority word
  /// is drawn per game, so a pair does not always play the same way.
  UndercoverWordPair get swapped => UndercoverWordPair(
        id: id,
        civilian: undercover,
        undercover: civilian,
        difficulty: difficulty,
      );

  @override
  String toString() => 'UndercoverWordPair($civilian / $undercover)';
}
