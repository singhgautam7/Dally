import '../../../../core/util/dally_random.dart';

/// The letters of [word], shuffled into an order that is *not* the word.
///
/// Anagram puzzles that happen to shuffle back to the answer are the one bug
/// players actually notice, so the scramble retries; on a word whose letters
/// cannot be rearranged at all (`aaa`) it gives up and returns them as they are
/// rather than looping.
String scramble(DallyRandom random, String word) {
  final letters = word.split('');
  for (var attempt = 0; attempt < 12; attempt++) {
    final shuffled = random.shuffled(letters).join();
    if (shuffled != word) return shuffled;
  }
  return letters.join();
}

/// True when [attempt] uses exactly the letters of [scrambled] — the same
/// multiset, no more and no fewer.
bool usesSameLetters(String attempt, String scrambled) {
  if (attempt.length != scrambled.length) return false;
  final counts = <String, int>{};
  for (final c in scrambled.split('')) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  for (final c in attempt.split('')) {
    final left = counts[c] ?? 0;
    if (left == 0) return false;
    counts[c] = left - 1;
  }
  return true;
}

/// One anagram round: a scramble, and whatever the player can make of it.
class AnagramRound {
  AnagramRound({
    required this.answer,
    required this.scrambled,
    required bool Function(String) isWord,
    // `this._isWord` is what the lint asks for, but a named parameter may not
    // have a private name — it would be undeclarable by callers.
    // ignore: prefer_initializing_formals
  }) : _isWord = isWord;

  final String answer;
  final String scrambled;
  final bool Function(String) _isWord;

  bool solved = false;

  /// True when [attempt] is a real word made of exactly these letters. Any such
  /// word is accepted, not only the one the puzzle was built from — refusing a
  /// legitimate anagram would just look broken.
  bool accepts(String attempt) {
    final candidate = attempt.toLowerCase();
    return usesSameLetters(candidate, scrambled) && _isWord(candidate);
  }

  bool submit(String attempt) {
    if (solved || !accepts(attempt)) return false;
    solved = true;
    return true;
  }
}
