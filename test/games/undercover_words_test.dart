import 'package:dally/features/games/undercover/data/undercover_words.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bank is bundled, finite and hand-authored, so its invariants are worth
/// asserting once rather than discovering in a game.
void main() {
  group('the word-pair bank', () {
    test('is not empty and every band is populated', () {
      expect(kUndercoverPairs.length, greaterThanOrEqualTo(150));
      for (final band in WordDifficulty.values) {
        final n = kUndercoverPairs.where((p) => p.difficulty == band).length;
        expect(n, greaterThanOrEqualTo(40), reason: '${band.name} band is thin');
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
