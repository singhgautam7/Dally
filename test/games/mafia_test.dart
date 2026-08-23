import 'dart:math';

import 'package:dally/features/games/mafia/data/mafia_words.dart';
import 'package:dally/features/games/mafia/logic/mafia_game.dart';
import 'package:dally/features/games/mafia/logic/mafia_player.dart';
import 'package:dally/features/games/mafia/logic/mafia_rules.dart';
import 'package:dally/features/games/mafia/logic/mafia_word_deck.dart';
import 'package:dally/features/games/mafia/logic/mafia_word_pair.dart';
import 'package:flutter_test/flutter_test.dart';

MafiaWordPair get _pair =>
    const MafiaWordPair(id: 'beach_vacation', word: 'Beach', hint: 'Vacation', difficulty: MafiaDifficulty.easy);

List<String> _names(int n) => [for (var i = 0; i < n; i++) 'P$i'];

void main() {
  group('MafiaRules.imposterCount', () {
    test('bands per spec', () {
      expect(MafiaRules.imposterCount(4), 1);
      expect(MafiaRules.imposterCount(6), 1);
      expect(MafiaRules.imposterCount(7), 2);
      expect(MafiaRules.imposterCount(10), 2);
      expect(MafiaRules.imposterCount(11), 3);
      expect(MafiaRules.imposterCount(15), 3);
      expect(MafiaRules.imposterCount(16), 4);
      expect(MafiaRules.imposterCount(20), 4);
    });
  });

  group('rosterError', () {
    test('too few players', () {
      expect(MafiaRules.rosterError(_names(3)), isNotNull);
    });
    test('empty name rejected', () {
      expect(MafiaRules.rosterError(['A', 'B', 'C', '  ']), isNotNull);
    });
    test('duplicate name rejected (case-insensitive)', () {
      expect(MafiaRules.rosterError(['Sam', 'sam', 'Bob', 'Ann']), isNotNull);
    });
    test('valid roster passes', () {
      expect(MafiaRules.rosterError(['Sam', 'Bob', 'Ann', 'Eve']), isNull);
    });
    test('too many players', () {
      expect(MafiaRules.rosterError(_names(21)), isNotNull);
    });
  });

  group('role assignment', () {
    test('exactly N imposters, unique, roles applied', () {
      final rng = Random(1);
      final g = MafiaGame.deal(names: _names(10), imposters: 2, wordPair: _pair, rng: rng);
      final imps = g.players.where((p) => p.isImposter).toList();
      expect(imps.length, 2);
      // no name appears twice among imposters (unique indexes)
      expect(imps.map((p) => p.name).toSet().length, 2);
      expect(g.players.length, 10);
    });

    test('imposters see the hint, villagers the word', () {
      final g = MafiaGame.deal(names: _names(4), imposters: 1, wordPair: _pair, rng: Random(2));
      for (var i = 0; i < g.players.length; i++) {
        expect(g.cardText(i), g.players[i].isImposter ? 'Vacation' : 'Beach');
      }
    });
  });

  group('MafiaWordDeck', () {
    test('no repeat within a full cycle', () {
      final deck = MafiaWordDeck(kMafiaWordPairs, random: Random(3));
      final seen = <String>{};
      for (var i = 0; i < kMafiaWordPairs.length; i++) {
        final p = deck.draw();
        expect(seen.add(p.id), isTrue, reason: 'repeat before deck emptied: ${p.id}');
      }
      expect(deck.remaining, 0);
    });

    test('reshuffles for a new cycle and avoids immediate repeat', () {
      final deck = MafiaWordDeck(kMafiaWordPairs, random: Random(4));
      MafiaWordPair? last;
      for (var i = 0; i < kMafiaWordPairs.length; i++) last = deck.draw();
      final next = deck.draw(); // triggers refill
      expect(next.id, isNot(last!.id));
    });

    test('difficulty filter returns matching band', () {
      final deck = MafiaWordDeck(kMafiaWordPairs, random: Random(5));
      for (var i = 0; i < 20; i++) {
        expect(deck.draw(difficulty: MafiaDifficulty.hard).difficulty, MafiaDifficulty.hard);
      }
    });
  });

  group('voting', () {
    MafiaGame game() => MafiaGame.deal(names: _names(5), imposters: 1, wordPair: _pair, rng: Random(6));

    test('cannot vote for a dead player', () {
      final g = game();
      g.eliminate(0);
      expect(() => g.castVote(0), throwsArgumentError);
    });

    test('self-vote is excluded from a voter ballot', () {
      final g = game();
      expect(g.candidatesFor(2).contains(2), isFalse);
      expect(g.candidatesFor(2).length, g.aliveCount - 1);
    });

    test('clear majority eliminates the top', () {
      final g = game();
      g..castVote(1)..castVote(1)..castVote(3);
      final r = g.resolve();
      expect(r.eliminated, 1);
    });

    test('a tie starts a tie-break among the tied only', () {
      final g = game();
      g..castVote(1)..castVote(2);
      final r = g.resolve();
      expect(r.eliminated, isNull);
      expect(r.tieBreak.toSet(), {1, 2});
      expect(g.inTieBreak, isTrue);
      expect(g.candidates.toSet(), {1, 2});
    });

    test('tie persisting through tie-break eliminates nobody', () {
      final g = game();
      g..castVote(1)..castVote(2);
      g.resolve(); // enter tie-break {1,2}
      g..castVote(1)..castVote(2); // tie again
      final r = g.resolve();
      expect(r.noElimination, isTrue);
      expect(g.aliveCount, 5);
      expect(g.inTieBreak, isFalse);
    });
  });

  group('win conditions', () {
    test('villagers win when all imposters are out', () {
      final players = [
        const MafiaPlayer(name: 'a', role: MafiaRole.imposter, alive: false),
        const MafiaPlayer(name: 'b', role: MafiaRole.villager),
        const MafiaPlayer(name: 'c', role: MafiaRole.villager),
      ];
      expect(MafiaRules.villagersWin(players), isTrue);
      expect(MafiaRules.impostersWin(players), isFalse);
    });

    test('imposters win at parity', () {
      final players = [
        const MafiaPlayer(name: 'a', role: MafiaRole.imposter),
        const MafiaPlayer(name: 'b', role: MafiaRole.villager),
        const MafiaPlayer(name: 'c', role: MafiaRole.villager, alive: false),
      ];
      expect(MafiaRules.villagersWin(players), isFalse);
      expect(MafiaRules.impostersWin(players), isTrue);
    });

    test('game continues while villagers outnumber imposters', () {
      final g = MafiaGame.deal(names: _names(5), imposters: 1, wordPair: _pair, rng: Random(7));
      expect(g.winner(), isNull);
    });
  });

  group('play again', () {
    test('fresh roles and a new word pair, same names', () {
      final names = _names(6);
      final deck = MafiaWordDeck(kMafiaWordPairs, random: Random(8));
      final first = MafiaGame.deal(
          names: names, imposters: 1, wordPair: deck.draw(), rng: Random(9));
      final again = MafiaGame.deal(
          names: names, imposters: 1, wordPair: deck.draw(), rng: Random(10));
      expect(again.players.map((p) => p.name).toList(), names);
      expect(again.wordPair.id, isNot(first.wordPair.id));
      expect(again.players.every((p) => p.alive), isTrue);
      expect(again.round, 1);
    });
  });

  group('dataset', () {
    test('at least 500 pairs', () => expect(kMafiaWordPairs.length, greaterThanOrEqualTo(500)));
    test('ids unique', () {
      final ids = kMafiaWordPairs.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
    test('no empty word or hint, no self-synonym-as-identical', () {
      for (final p in kMafiaWordPairs) {
        expect(p.word.trim(), isNotEmpty);
        expect(p.hint.trim(), isNotEmpty);
        expect(p.word.toLowerCase(), isNot(p.hint.toLowerCase()));
      }
    });
    test('every band represented', () {
      final bands = kMafiaWordPairs.map((p) => p.difficulty).toSet();
      expect(bands, {MafiaDifficulty.easy, MafiaDifficulty.normal, MafiaDifficulty.hard});
    });
  });
}
