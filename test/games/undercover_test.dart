import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/undercover/data/undercover_words.dart';
import 'package:dally/features/games/undercover/logic/undercover_game.dart';
import 'package:dally/features/games/undercover/logic/word_deck.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything here is seeded: roles, the pair and the speaking order all come
/// from an injected [DallyRandom], so a game replays exactly.
void main() {
  const names = ['Ravi', 'Ana', 'Priya', 'Noor', 'Sam', 'Iris'];

  UndercoverGame deal({
    int seed = 1,
    int undercover = 1,
    bool mrWhite = false,
    List<String> roster = names,
  }) =>
      UndercoverGame.deal(
        names: roster,
        undercover: undercover,
        mrWhite: mrWhite,
        pair: const UndercoverWordPair(
          id: 'violin|viola',
          civilian: 'Violin',
          undercover: 'Viola',
          difficulty: WordDifficulty.hard,
        ),
        rng: DallyRandom.seeded(seed),
      );

  /// Votes everyone still in onto [target] — the shortest way to a known
  /// elimination without modelling a table's opinions.
  void voteOut(UndercoverGame g, int target) {
    for (final v in g.aliveIndexes) {
      g.castVote(voter: v, candidate: v == target ? g.candidatesFor(v).first : target);
    }
  }

  group('word-pair selection', () {
    test('a seeded deck draws the same pairs in the same order', () {
      List<String> draw(int seed) {
        final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(seed));
        return [for (var i = 0; i < 12; i++) deck.draw().id];
      }

      expect(draw(7), draw(7));
    });

    test('different seeds draw a different order', () {
      List<String> draw(int seed) {
        final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(seed));
        return [for (var i = 0; i < 12; i++) deck.draw().id];
      }

      expect(draw(1), isNot(draw(2)));
    });

    test('no pair repeats within a session', () {
      final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(3));
      final seen = <String>{};
      for (var i = 0; i < kUndercoverPairs.length; i++) {
        expect(seen.add(deck.draw().id), isTrue, reason: 'draw $i repeated');
      }
    });

    test('the bag reshuffles rather than running dry, and never repeats at the seam', () {
      final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(4));
      String? last;
      for (var i = 0; i < kUndercoverPairs.length + 5; i++) {
        final id = deck.draw().id;
        expect(id, isNot(last), reason: 'draw $i repeated the previous pair');
        last = id;
      }
    });

    test('a difficulty draw only ever returns that band', () {
      for (final band in WordDifficulty.values) {
        final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(5));
        for (var i = 0; i < 25; i++) {
          expect(deck.draw(difficulty: band).difficulty, band);
        }
      }
    });

    test('which of the two words is the majority one is drawn per game', () {
      final deck = UndercoverWordDeck(kUndercoverPairs, random: DallyRandom.seeded(11));
      final orientations = <bool>{};
      for (var i = 0; i < 30; i++) {
        final drawn = deck.draw();
        final source = kUndercoverPairs.firstWhere((p) => p.id == drawn.id);
        orientations.add(drawn.civilian == source.civilian);
      }
      expect(orientations, hasLength(2), reason: 'both orientations must occur');
    });
  });

  group('the deal', () {
    test('roles are dealt in the counts asked for', () {
      final g = deal(undercover: 2, mrWhite: true);
      expect(g.players.where((p) => p.role == UndercoverRole.undercover), hasLength(2));
      expect(g.players.where((p) => p.role == UndercoverRole.mrWhite), hasLength(1));
      expect(g.players.where((p) => p.role == UndercoverRole.civilian), hasLength(3));
    });

    test('no Mr. White when the toggle is off', () {
      final g = deal(undercover: 1, mrWhite: false);
      expect(g.players.any((p) => p.role == UndercoverRole.mrWhite), isFalse);
    });

    test('civilians see the majority word, undercover the other, Mr. White none', () {
      final g = deal(undercover: 1, mrWhite: true);
      for (var i = 0; i < g.players.length; i++) {
        switch (g.players[i].role) {
          case UndercoverRole.civilian:
            expect(g.wordFor(i), 'Violin');
          case UndercoverRole.undercover:
            expect(g.wordFor(i), 'Viola');
          case UndercoverRole.mrWhite:
            expect(g.wordFor(i), isNull);
        }
      }
    });

    test('the same seed deals the same roles', () {
      List<UndercoverRole> roles(int seed) =>
          deal(seed: seed, undercover: 2, mrWhite: true).players.map((p) => p.role).toList();
      expect(roles(9), roles(9));
    });

    test('a different seed deals different roles', () {
      List<UndercoverRole> roles(int seed) =>
          deal(seed: seed, undercover: 2, mrWhite: true).players.map((p) => p.role).toList();
      expect(roles(1), isNot(roles(2)));
    });

    test('the speaking order holds every seat exactly once', () {
      final g = deal();
      expect(g.speakingOrder.toSet(), {0, 1, 2, 3, 4, 5});
      expect(g.speakingOrder, hasLength(6));
    });

    test('the speaking order does not follow the deal order', () {
      // Over several seeds, at least one order must differ from 0..n-1 — a
      // shuffle that always returned the identity would be a real tell.
      final identities = [
        for (var seed = 1; seed <= 8; seed++)
          deal(seed: seed).speakingOrder.toString() == '[0, 1, 2, 3, 4, 5]',
      ];
      expect(identities.every((x) => x), isFalse);
    });
  });

  group('voting and elimination', () {
    test('a player may not vote for themselves', () {
      final g = deal();
      expect(() => g.castVote(voter: 0, candidate: 0), throwsArgumentError);
    });

    test('a player may not vote twice', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      g.castVote(voter: 0, candidate: 2);
      expect(g.tally[1], 1);
      expect(g.tally[2], isNull);
      expect(g.votesCast, 1);
    });

    test('a vote can be taken back', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      expect(g.votesCast, 1);
      g.retract(0);
      expect(g.votesCast, 0);
      expect(g.tally[1], isNull);
      // …and re-cast somewhere else.
      g.castVote(voter: 0, candidate: 2);
      expect(g.tally[2], 1);
    });

    test('taking a vote back off a name frees the voter who cast it', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 3);
      g.castVote(voter: 1, candidate: 3);
      expect(g.tally[3], 2);

      // The most recent ballot for that name comes off, and only that one.
      expect(g.retractVoteFor(3), isTrue);
      expect(g.tally[3], 1);
      expect(g.hasVoted(1), isFalse);
      expect(g.hasVoted(0), isTrue);
    });

    test('taking a vote back off a name with no votes removes nothing', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      // The bug this guards: a tap on an unvoted name used to free an
      // unrelated voter and leave the tally out of step with the ballot.
      expect(g.retractVoteFor(4), isFalse);
      expect(g.votesCast, 1);
      expect(g.tally[1], 1);
    });

    test('the tally always agrees with the ballots behind it', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      g.castVote(voter: 2, candidate: 1);
      g.castVote(voter: 3, candidate: 4);
      var counted = 0;
      for (final n in g.tally.values) {
        counted += n;
      }
      expect(counted, g.votesCast);

      g.retractVoteFor(1);
      counted = 0;
      for (final n in g.tally.values) {
        counted += n;
      }
      expect(counted, g.votesCast);
    });

    test('nextVoter walks the living players and then runs out', () {
      final g = deal();
      final seen = <int>[];
      while (g.nextVoter != null) {
        final v = g.nextVoter!;
        seen.add(v);
        g.castVote(voter: v, candidate: g.candidatesFor(v).first);
      }
      expect(seen, g.aliveIndexes);
      expect(g.ballotComplete, isTrue);
    });

    test('the ballot is complete only when every living player has voted', () {
      final g = deal();
      for (final v in g.aliveIndexes.take(5)) {
        g.castVote(voter: v, candidate: v == 0 ? 1 : 0);
      }
      expect(g.ballotComplete, isFalse);
      g.castVote(voter: 5, candidate: 0);
      expect(g.ballotComplete, isTrue);
    });

    test('the most-voted player is eliminated', () {
      final g = deal();
      voteOut(g, 2);
      final result = g.resolve();
      expect(result.tied, isFalse);
      expect(result.eliminated, 2);
      g.eliminate(2);
      expect(g.players[2].alive, isFalse);
      expect(g.aliveCount, 5);
    });

    test('a tie eliminates nobody and rotates the order by one', () {
      final g = deal();
      final orderBefore = g.speakingOrder;
      // Three each on two names.
      g.castVote(voter: 0, candidate: 1);
      g.castVote(voter: 2, candidate: 1);
      g.castVote(voter: 1, candidate: 0);
      g.castVote(voter: 3, candidate: 0);
      final result = g.resolve();
      expect(result.tied, isTrue);
      expect(result.eliminated, isNull);
      expect(g.aliveCount, 6);
      expect(g.speakingOrder, isNot(orderBefore));
      expect(g.speakingOrder.toSet(), orderBefore.toSet());
    });

    test('a dead player cannot vote or be voted for', () {
      final g = deal();
      g.eliminate(2);
      expect(() => g.castVote(voter: 2, candidate: 0), throwsArgumentError);
      expect(() => g.castVote(voter: 0, candidate: 2), throwsArgumentError);
      expect(g.candidatesFor(0), isNot(contains(2)));
    });

    test('the tally and the ballot clear between rounds', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      g.resolve();
      g.nextRound();
      expect(g.tally, isEmpty);
      expect(g.votesCast, 0);
      expect(g.round, 2);
    });
  });

  group('the open ballot', () {
    // The phone is on the table and taps are anonymous, so the screen cannot
    // know who is tapping — and several people voting for the same suspect is
    // the normal case, not an error.
    test('several votes can land on the same candidate', () {
      final g = deal();
      expect(g.castOpenVote(3), isTrue);
      expect(g.castOpenVote(3), isTrue);
      expect(g.castOpenVote(3), isTrue);
      expect(g.tally[3], 3);
      expect(g.votesCast, 3);
      expect(g.leaders, [3]);
    });

    test('the very bug: a candidate stays tappable after voting for them', () {
      // The sequential-voter model disabled a row the moment the queue reached
      // that player, so the second vote for a suspect was impossible to cast.
      final g = deal();
      g.castOpenVote(1);
      expect(g.castOpenVote(1), isTrue, reason: 'a second vote for the same name');
      expect(g.tally[1], 2);
    });

    test('voting stops when every living player has had their say', () {
      final g = deal();
      for (var i = 0; i < g.aliveCount; i++) {
        expect(g.castOpenVote(2), isTrue, reason: 'vote $i');
      }
      expect(g.ballotComplete, isTrue);
      expect(g.votesRemaining, 0);
      expect(g.castOpenVote(2), isFalse, reason: 'the ballot is full');
      expect(g.votesCast, g.aliveCount);
    });

    test('a full ballot makes room again when a vote is taken back', () {
      final g = deal();
      for (var i = 0; i < g.aliveCount; i++) {
        g.castOpenVote(2);
      }
      expect(g.castOpenVote(3), isFalse);
      expect(g.retractVoteFor(2), isTrue);
      expect(g.ballotComplete, isFalse);
      expect(g.castOpenVote(3), isTrue, reason: 'the corrected vote lands');
      expect(g.tally[2], g.aliveCount - 1);
      expect(g.tally[3], 1);
    });

    test('a dead candidate takes no votes', () {
      final g = deal();
      g.eliminate(4);
      expect(g.castOpenVote(4), isFalse);
      expect(g.votesCast, 0);
    });

    test('an off-board candidate takes no votes', () {
      final g = deal();
      expect(g.castOpenVote(-1), isFalse);
      expect(g.castOpenVote(99), isFalse);
      expect(g.votesCast, 0);
    });

    test('the dots are in the order they were cast', () {
      final g = deal();
      g.castOpenVote(1);
      g.castOpenVote(2);
      g.castOpenVote(1);
      expect(g.ballots.map((v) => v.candidate).toList(), [1, 2, 1]);
      // Open votes are anonymous, which is what lets anybody cast them.
      expect(g.ballots.every((v) => v.voter == null), isTrue);
    });

    test('an open ballot resolves like any other', () {
      final g = deal();
      g.castOpenVote(3);
      g.castOpenVote(3);
      g.castOpenVote(1);
      final result = g.resolve();
      expect(result.tied, isFalse);
      expect(result.eliminated, 3);
      expect(g.votesCast, 0, reason: 'the box empties on resolve');
    });

    test('an open ballot can tie', () {
      final g = deal();
      g.castOpenVote(1);
      g.castOpenVote(2);
      expect(g.leaders, [1, 2]);
      expect(g.resolve().tied, isTrue);
    });

    test('named and anonymous votes never get mixed up', () {
      final g = deal();
      g.castVote(voter: 0, candidate: 1);
      g.castOpenVote(1);
      expect(g.tally[1], 2);
      expect(g.hasVoted(0), isTrue);
      // Taking one back off the name removes the anonymous one first — it was
      // the most recent — and leaves the named ballot intact.
      expect(g.retractVoteFor(1), isTrue);
      expect(g.hasVoted(0), isTrue);
      expect(g.ballotOf(0), 1);
    });
  });

  group('win conditions', () {
    test('civilians win the moment every Undercover and Mr. White is out', () {
      final g = deal(undercover: 1, mrWhite: true);
      final hiding = [
        for (var i = 0; i < g.players.length; i++)
          if (g.players[i].role.isHiding) i,
      ];
      expect(hiding, hasLength(2));
      // Take the Undercover out first; Mr. White is still in, so nobody has won.
      final undercover =
          hiding.firstWhere((i) => g.players[i].role == UndercoverRole.undercover);
      g.eliminate(undercover);
      expect(g.outcome, isNull);

      final white = hiding.firstWhere((i) => g.players[i].role == UndercoverRole.mrWhite);
      g.eliminate(white);
      // Mr. White gets his guess first; a wrong one leaves the civilians clear.
      expect(g.awaitingWhiteGuess, isTrue);
      expect(g.guessWord('Kazoo'), isFalse);
      expect(g.outcome, UndercoverOutcome.civilians);
    });

    test('undercover win at parity with the civilians', () {
      // Two hiding against four civilians: take three civilians out.
      final g = deal(undercover: 2, mrWhite: false);
      final civilians = [
        for (var i = 0; i < g.players.length; i++)
          if (g.players[i].role == UndercoverRole.civilian) i,
      ];
      expect(civilians, hasLength(4));
      g.eliminate(civilians[0]);
      expect(g.outcome, isNull, reason: '2 hiding vs 3 civilians is not parity');
      g.eliminate(civilians[1]);
      expect(g.outcome, UndercoverOutcome.undercover, reason: '2 vs 2 is parity');
    });

    test('parity counts Mr. White among the people hiding', () {
      final g = deal(undercover: 1, mrWhite: true, roster: names);
      final civilians = [
        for (var i = 0; i < g.players.length; i++)
          if (g.players[i].role == UndercoverRole.civilian) i,
      ];
      expect(civilians, hasLength(4));
      g.eliminate(civilians[0]);
      expect(g.outcome, isNull);
      g.eliminate(civilians[1]);
      expect(g.outcome, UndercoverOutcome.undercover);
    });

    test('the game is not over while both sides still have someone', () {
      final g = deal(undercover: 1);
      expect(g.isOver, isFalse);
      expect(g.outcome, isNull);
    });
  });

  group("Mr. White's last chance", () {
    UndercoverGame withWhiteOut({int seed = 1}) {
      final g = deal(seed: seed, undercover: 1, mrWhite: true);
      final white = g.players.indexWhere((p) => p.role == UndercoverRole.mrWhite);
      g.eliminate(white);
      return g;
    }

    test('being voted out opens the guess rather than ending the round', () {
      final g = withWhiteOut();
      expect(g.awaitingWhiteGuess, isTrue);
      expect(g.outcome, isNull);
    });

    test('naming the civilians\' word wins the whole game, alone', () {
      final g = withWhiteOut();
      expect(g.guessWord('Violin'), isTrue);
      expect(g.outcome, UndercoverOutcome.mrWhite);
      expect(g.isOver, isTrue);
    });

    test('the undercover word is not the answer', () {
      final g = withWhiteOut();
      expect(g.guessWord('Viola'), isFalse);
      expect(g.outcome, isNot(UndercoverOutcome.mrWhite));
    });

    test('a wrong guess simply leaves him out and play continues', () {
      final g = withWhiteOut();
      expect(g.guessWord('Trombone'), isFalse);
      expect(g.awaitingWhiteGuess, isFalse);
      // One undercover still in against four civilians: nobody has won.
      expect(g.outcome, isNull);
      expect(g.isOver, isFalse);
    });

    test('giving up is a wrong guess without the guess', () {
      final g = withWhiteOut();
      g.declineGuess();
      expect(g.awaitingWhiteGuess, isFalse);
      expect(g.whiteGuess, isNull);
      expect(g.outcome, isNull);
    });

    test('spelling is forgiven — near misses count', () {
      expect(UndercoverRules.guessMatches('violin', 'Violin'), isTrue);
      expect(UndercoverRules.guessMatches('  VIOLIN  ', 'Violin'), isTrue);
      expect(UndercoverRules.guessMatches('violn', 'Violin'), isTrue, reason: 'a deletion');
      expect(UndercoverRules.guessMatches('violinn', 'Violin'), isTrue, reason: 'an insertion');
      expect(UndercoverRules.guessMatches('violan', 'Violin'), isTrue, reason: 'a substitution');
      expect(UndercoverRules.guessMatches("shepherds pie", "Shepherd's pie"), isTrue);
    });

    test('forgiveness stops well short of a different word', () {
      expect(UndercoverRules.guessMatches('viola', 'Violin'), isFalse);
      expect(UndercoverRules.guessMatches('cello', 'Violin'), isFalse);
      expect(UndercoverRules.guessMatches('', 'Violin'), isFalse);
      expect(UndercoverRules.guessMatches('   ', 'Violin'), isFalse);
      // Short words get no leeway at all: one edit is most of the word.
      expect(UndercoverRules.guessMatches('cat', 'Cap'), isFalse);
      expect(UndercoverRules.guessMatches('Cat', 'Cat'), isTrue);
    });
  });

  group('rules', () {
    test('three undercover unlock at eleven players', () {
      expect(UndercoverRules.maxUndercoverFor(6), 1);
      expect(UndercoverRules.maxUndercoverFor(7), 2);
      expect(UndercoverRules.maxUndercoverFor(10), 2);
      expect(UndercoverRules.maxUndercoverFor(11), 3);
      expect(UndercoverRules.maxUndercoverFor(20), 3);
    });

    test('a roster is validated before the deal', () {
      expect(UndercoverRules.rosterError(['A', 'B', 'C', 'D']), isNull);
      expect(UndercoverRules.rosterError(['A', 'B', 'C']), contains('at least'));
      expect(UndercoverRules.rosterError(['A', 'B', 'C', '']), contains('name'));
      expect(UndercoverRules.rosterError(['A', 'a', 'C', 'D']), contains('unique'));
      expect(
          UndercoverRules.rosterError([for (var i = 0; i < 21; i++) 'P$i']),
          contains('At most'));
    });
  });
}
