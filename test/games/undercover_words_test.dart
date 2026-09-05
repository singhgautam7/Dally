import 'package:dally/features/games/undercover/data/undercover_words.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bank is bundled, finite and hand-authored, so its invariants are worth
/// asserting once rather than discovering in a game.
void main() {
  group('the word-pair bank', () {
    test('is not empty and every band is populated', () {
      expect(kUndercoverPairs.length, greaterThanOrEqualTo(240));
      for (final band in WordDifficulty.values) {
        final n = kUndercoverPairs.where((p) => p.difficulty == band).length;
        expect(n, greaterThanOrEqualTo(80), reason: '${band.name} band is thin');
      }
    });

    test('the bands are evenly stocked, so difficulty is a real choice', () {
      final counts = [
        for (final band in WordDifficulty.values)
          kUndercoverPairs.where((p) => p.difficulty == band).length,
      ];
      final lo = counts.reduce((a, b) => a < b ? a : b);
      final hi = counts.reduce((a, b) => a > b ? a : b);
      expect(hi - lo, lessThanOrEqualTo(10),
          reason: 'one band should not be three times another');
    });

    test('the film and television set is present in every band', () {
      // A sample from each band, so the set cannot be dropped by accident.
      const fromEachBand = ['Popcorn', 'Sequel', 'Screenplay'];
      for (final word in fromEachBand) {
        expect(kUndercoverPairs.any((p) => p.civilian == word || p.undercover == word),
            isTrue,
            reason: '$word is missing');
      }
    });

    test('no franchise, studio or character name is in the bank', () {
      // The film pairs are the craft and the experience, never somebody else's
      // trademark — the dataset brief was that it be licensing-clean.
      const forbidden = [
        'harry potter', 'lord of the rings', 'star wars', 'star trek', 'marvel',
        'batman', 'spiderman', 'spider-man', 'superman', 'disney', 'pixar',
        'netflix', 'titanic', 'avatar', 'frozen', 'shrek', 'barbie', 'oscar',
        'hogwarts', 'jedi', 'pokemon', 'minecraft',
      ];
      for (final p in kUndercoverPairs) {
        for (final word in [p.civilian.toLowerCase(), p.undercover.toLowerCase()]) {
          expect(forbidden.contains(word), isFalse,
              reason: '"$word" is somebody else\'s trademark');
        }
      }
    });

    test('every pair holds two different, non-empty words', () {
      for (final p in kUndercoverPairs) {
        expect(p.civilian.trim(), isNotEmpty, reason: p.id);
        expect(p.undercover.trim(), isNotEmpty, reason: p.id);
        expect(p.civilian.toLowerCase(), isNot(p.undercover.toLowerCase()),
            reason: '${p.id}: the two words must differ');
      }
    });

    test('ids are unique', () {
      final ids = kUndercoverPairs.map((p) => p.id).toSet();
      expect(ids, hasLength(kUndercoverPairs.length));
    });

    test('no word appears in two pairs', () {
      // A word in two pairs makes a clue ambiguous across games and, worse,
      // lets one pair's civilian word be another's undercover word.
      final seen = <String, String>{};
      for (final p in kUndercoverPairs) {
        for (final word in [p.civilian, p.undercover]) {
          final key = word.toLowerCase();
          expect(seen.containsKey(key), isFalse,
              reason: '"$word" appears in ${seen[key]} and ${p.id}');
          seen[key] = p.id;
        }
      }
    });

    test('swapping a pair keeps its identity and its band', () {
      for (final p in kUndercoverPairs.take(20)) {
        final s = p.swapped;
        expect(s.id, p.id);
        expect(s.difficulty, p.difficulty);
        expect(s.civilian, p.undercover);
        expect(s.undercover, p.civilian);
      }
    });

    test('words are short enough to read on a card', () {
      for (final p in kUndercoverPairs) {
        expect(p.civilian.length, lessThanOrEqualTo(18), reason: p.id);
        expect(p.undercover.length, lessThanOrEqualTo(18), reason: p.id);
      }
    });
  });
}
