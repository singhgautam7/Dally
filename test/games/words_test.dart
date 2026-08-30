import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/words/logic/anagrams.dart';
import 'package:dally/features/games/words/logic/word_list.dart';
import 'package:dally/features/games/words/logic/word_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<WordList> loadList() => WordList.load(bundle: rootBundle);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled list', () {
    late WordList list;
    setUpAll(() async => list = await loadList());

    test('answers are 4–8 letters, unique, and all valid words', () {
      final seen = <String>{};
      for (var n = 1; n <= 12; n++) {
        for (final word in list.answersOfLength(n)) {
          expect(word.length, inInclusiveRange(4, 8), reason: '"$word"');
          expect(RegExp(r'^[a-z]+$').hasMatch(word), isTrue, reason: '"$word"');
          expect(seen.add(word), isTrue, reason: '"$word" is listed twice');
          expect(list.isWord(word), isTrue,
              reason: '"$word" is an answer but not in the dictionary');
        }
      }
      expect(seen.length, greaterThan(500));
    });

    test('the dictionary is large and validates offline', () {
      expect(list.dictionarySize, greaterThan(50000));
      expect(list.isWord('house'), isTrue);
      expect(list.isWord('HOUSE'), isTrue, reason: 'case is normalised');
      expect(list.isWord('zzzzz'), isFalse);
    });

    test('picking is deterministic and respects the difficulty band', () {
      for (final difficulty in WordDifficulty.values) {
        final a = list.pick(DallyRandom.seeded(11), difficulty);
        final b = list.pick(DallyRandom.seeded(11), difficulty);
        expect(a, b);
        for (var seed = 0; seed < 60; seed++) {
          final word = list.pick(DallyRandom.seeded(seed), difficulty);
          expect(word.length,
              inInclusiveRange(difficulty.minLength, difficulty.maxLength),
              reason: '$difficulty produced "$word"');
          expect(list.isWord(word), isTrue);
        }
      }
    });

    test('easy words really are the more familiar ones', () {
      final easy = list.poolFor(WordDifficulty.easy);
      final hard = list.poolFor(WordDifficulty.hard);
      expect(easy, isNotEmpty);
      expect(hard, isNotEmpty);
      expect(easy.toSet().intersection(hard.toSet()), isEmpty,
          reason: 'the two bands do not overlap in length');
    });
  });

  group('anagrams', () {
    test('a scramble is never the word itself', () {
      for (var seed = 0; seed < 100; seed++) {
        expect(scramble(DallyRandom.seeded(seed), 'garden'), isNot('garden'));
      }
    });

    test('a scramble keeps exactly the same letters', () {
      final s = scramble(DallyRandom.seeded(3), 'letters');
      expect(usesSameLetters(s, 'letters'), isTrue);
    });

    test('a word with only one arrangement gives up rather than looping', () {
      expect(scramble(DallyRandom.seeded(1), 'aaaa'), 'aaaa');
    });

    test('letter multisets are compared, not sets', () {
      expect(usesSameLetters('aab', 'aba'), isTrue);
      expect(usesSameLetters('abb', 'aab'), isFalse);
      expect(usesSameLetters('ab', 'aba'), isFalse);
    });

    test('any real word using the letters is accepted', () {
      final round = AnagramRound(
        answer: 'listen',
        scrambled: 'tliens',
        isWord: (w) => {'listen', 'silent', 'enlist'}.contains(w),
      );
      expect(round.accepts('silent'), isTrue, reason: 'a different valid anagram');
      expect(round.accepts('listen'), isTrue);
      expect(round.accepts('tinsel'), isFalse, reason: 'not in this dictionary');
      expect(round.accepts('lines'), isFalse, reason: 'wrong letter count');
      expect(round.submit('silent'), isTrue);
      expect(round.submit('listen'), isFalse, reason: 'already solved');
    });
  });

  group('word search', () {
    const candidates = [
      'house', 'water', 'plant', 'stone', 'river', 'cloud', 'grass', 'light',
      'music', 'paper', 'field', 'beach',
    ];

    test('generation is deterministic', () {
      String render(int seed) => generateWordSearch(DallyRandom.seeded(seed),
              size: 10, candidates: candidates)
          .grid
          .map((r) => r.join())
          .join('/');
      expect(render(2), render(2));
      expect(render(2), isNot(render(3)));
    });

    test('every placed word really reads out of the grid', () {
      for (var seed = 0; seed < 30; seed++) {
        final puzzle =
            generateWordSearch(DallyRandom.seeded(seed), size: 10, candidates: candidates);
        expect(puzzle.words, isNotEmpty);
        for (final placed in puzzle.words) {
          final read = [
            for (final (r, c) in placed.cells) puzzle.letterAt(r, c)
          ].join();
          expect(read, placed.word, reason: 'seed $seed');
          for (final (r, c) in placed.cells) {
            expect(r, inInclusiveRange(0, puzzle.size - 1));
            expect(c, inInclusiveRange(0, puzzle.size - 1));
          }
        }
      }
    });

    test('the grid is completely filled with letters', () {
      final puzzle =
          generateWordSearch(DallyRandom.seeded(5), size: 8, candidates: candidates);
      for (final row in puzzle.grid) {
        expect(row.every((c) => RegExp(r'^[a-z]$').hasMatch(c)), isTrue);
      }
    });

    test('a selection along a placement finds the word, either way round', () {
      final puzzle =
          generateWordSearch(DallyRandom.seeded(7), size: 10, candidates: candidates);
      final game = WordSearchGame(puzzle);
      final target = puzzle.words.first;
      expect(game.submit(target.end, (target.row, target.column)), target.word,
          reason: 'read backwards');
      expect(game.found, contains(target.word));
      expect(game.submit((target.row, target.column), target.end), isNull,
          reason: 'already found');
    });

    test('a crooked selection is not a line', () {
      expect(WordSearchGame.lineBetween((0, 0), (1, 3)), isNull);
      expect(WordSearchGame.lineBetween((0, 0), (2, 2)), [(0, 0), (1, 1), (2, 2)]);
      expect(WordSearchGame.lineBetween((2, 0), (0, 0)), [(2, 0), (1, 0), (0, 0)]);
    });

    test('finding every word completes the puzzle', () {
      final puzzle =
          generateWordSearch(DallyRandom.seeded(9), size: 10, candidates: candidates);
      final game = WordSearchGame(puzzle);
      expect(game.isComplete, isFalse);
      for (final placed in puzzle.words) {
        expect(game.submit((placed.row, placed.column), placed.end), placed.word);
      }
      expect(game.isComplete, isTrue);
      expect(game.remaining, 0);
      expect(game.foundCells, isNotEmpty);
    });
  });
}
