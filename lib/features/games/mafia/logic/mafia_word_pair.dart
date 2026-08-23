/// Difficulty band for a word pair. Easy pairs have an obvious relationship;
/// Hard pairs a looser one that gives the imposter more room to hide.
enum MafiaDifficulty { easy, normal, hard }

MafiaDifficulty difficultyFromId(String id) => switch (id) {
      'easy' => MafiaDifficulty.easy,
      'hard' => MafiaDifficulty.hard,
      _ => MafiaDifficulty.normal,
    };

extension MafiaDifficultyX on MafiaDifficulty {
  String get id => name;
  String get label => switch (this) {
        MafiaDifficulty.easy => 'Easy',
        MafiaDifficulty.normal => 'Normal',
        MafiaDifficulty.hard => 'Hard',
      };
}

/// One bundled secret word and the related hint the imposter sees instead. The
/// two are never synonyms — the hint sits *near* the word, not on it.
class MafiaWordPair {
  const MafiaWordPair({
    required this.id,
    required this.word,
    required this.hint,
    required this.difficulty,
  });

  final String id;
  final String word;
  final String hint;
  final MafiaDifficulty difficulty;

  @override
  String toString() => 'MafiaWordPair($id: $word → $hint)';
}
