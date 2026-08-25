import 'package:flutter/foundation.dart';

/// What a guessed letter turned out to be.
enum LetterMark {
  /// Right letter, right place.
  correct,

  /// The letter is in the word, but not here.
  present,

  /// Not in the word — or not in it any more, once its copies are accounted for.
  absent,
}

/// One scored guess.
@immutable
class GuessResult {
  const GuessResult(this.word, this.marks);

  final String word;
  final List<LetterMark> marks;

  bool get isWin => marks.every((m) => m == LetterMark.correct);
}

/// Scores [guess] against [answer].
///
/// Two passes, because one is wrong: exact matches are claimed first, and only
/// the *unclaimed* copies of a letter can then be marked present. Without that,
/// guessing "geese" against "large" reports two greens' worth of e's.
List<LetterMark> markGuess(String guess, String answer) {
  assert(guess.length == answer.length);
  final marks = List.filled(guess.length, LetterMark.absent);
  final unclaimed = <String, int>{};

  for (var i = 0; i < guess.length; i++) {
    if (guess[i] == answer[i]) {
      marks[i] = LetterMark.correct;
    } else {
      unclaimed[answer[i]] = (unclaimed[answer[i]] ?? 0) + 1;
    }
  }
  for (var i = 0; i < guess.length; i++) {
    if (marks[i] == LetterMark.correct) continue;
    final left = unclaimed[guess[i]] ?? 0;
    if (left > 0) {
      marks[i] = LetterMark.present;
      unclaimed[guess[i]] = left - 1;
    }
  }
  return marks;
}

/// Why a guess was refused. Refusing is not a turn — nothing is spent.
enum GuessRejection { wrongLength, notAWord, alreadyOver }

/// Word Guess — a hidden word, a fixed number of tries, per-letter feedback.
class WordGuessGame {
  WordGuessGame({
    required this.answer,
    required bool Function(String) isWord,
    this.maxTries = 6,
  }) : _isWord = isWord;

  final String answer;
  final int maxTries;
  final bool Function(String) _isWord;

  final List<GuessResult> guesses = [];

  bool get isWon => guesses.isNotEmpty && guesses.last.isWin;
  bool get isLost => !isWon && guesses.length >= maxTries;
  bool get isOver => isWon || isLost;
  int get triesLeft => maxTries - guesses.length;
  int get length => answer.length;

  /// The best mark seen for each letter so far — what the keyboard colours by.
  Map<String, LetterMark> get keyboardMarks {
    final best = <String, LetterMark>{};
    for (final guess in guesses) {
      for (var i = 0; i < guess.word.length; i++) {
        final letter = guess.word[i];
        final mark = guess.marks[i];
        final current = best[letter];
        if (current == null || mark.index < current.index) best[letter] = mark;
      }
    }
    return best;
  }

  /// Submits a guess. Returns null on success, or why it was refused.
  GuessRejection? guess(String word) {
    if (isOver) return GuessRejection.alreadyOver;
    final candidate = word.toLowerCase();
    if (candidate.length != answer.length) return GuessRejection.wrongLength;
    if (!_isWord(candidate)) return GuessRejection.notAWord;
    guesses.add(GuessResult(candidate, markGuess(candidate, answer)));
    return null;
  }
}
