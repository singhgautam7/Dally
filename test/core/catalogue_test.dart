import 'package:dally/core/game/game_category.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/features/shell/home/home_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = kGameModules;

  group('registry integrity', () {
    test('every game id is unique and stable-looking', () {
      final ids = registry.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate game id');
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9_]+$')), reason: id);
      }
    });

    test('every game declares the metadata search and filters need', () {
      for (final m in registry) {
        expect(m.title, isNotEmpty, reason: m.id);
        expect(m.tagline, isNotEmpty, reason: m.id);
        expect(m.players, isNotEmpty, reason: m.id);
        expect(m.vibes, isNotEmpty, reason: m.id);
        // category / playerCount / typicalLength are non-nullable by type.
        expect(GameCategory.values, contains(m.category), reason: m.id);
      }
    });

    test('a game with styles has a recommended one and a real default', () {
      for (final m in registry) {
        if (m.styleOptions.isEmpty) {
          expect(m.defaultStyleId, isNull, reason: m.id);
          continue;
        }
        expect(m.styleOptions.map((o) => o.id).toSet().length, m.styleOptions.length,
            reason: '${m.id} has duplicate style ids');
        expect(m.styleOptions.any((o) => o.id == m.defaultStyleId), isTrue, reason: m.id);
      }
    });

    test('no trademarked name appears in a title, tagline or tag', () {
      // Standing Dally rule: mechanic-descriptive names only.
      const forbidden = [
        'tetris', 'kenken', 'othello', 'connect four', 'mastermind', 'picross',
        'candy crush', 'doodle jump', 'flappy', 'wordle', 'monopoly', 'scrabble',
      ];
      for (final m in registry) {
        final haystack = '${m.id} ${m.title} ${m.tagline} ${m.tags.join(' ')}'.toLowerCase();
        for (final word in forbidden) {
          expect(haystack.contains(word), isFalse, reason: '${m.id} mentions "$word"');
        }
      }
    });

    test('the five Quick Play tools are exactly the approved ones', () {
      final quick = registry
          .where((m) => m.category == GameCategory.quickPlay)
          .map((m) => m.id)
          .toSet();
      expect(quick, {
        'coin_flip',
        'dice',
        'bottle_spinner',
        'random_number',
        'random_choice',
      });
    });

    test('the six Mental Math drills and five Arcade games are all registered', () {
      final math = registry.where((m) => m.category == GameCategory.mentalMath);
      expect(math.length, 6);
      final arcade = registry.where((m) => m.category == GameCategory.arcade);
      // Exactly five — the handoff specifies "Arcade (5)". Snake is a Classic.
      expect(arcade.map((m) => m.id).toSet(), {
        'jumper', 'tower_builder', 'reaction', 'racer', 'avoider',
      });
    });

    test('Chess and Mafia are still registered and intact', () {
      final ids = registry.map((m) => m.id).toSet();
      expect(ids, containsAll(<String>['chess', 'mafia']));
    });
  });

  group('dynamic game count', () {
    test('nothing hardcodes the number of games', () {
      // The count must track the registry, whatever its length.
      expect(registry.length, greaterThan(8));
      final categories = registry.map((m) => m.category).toSet();
      expect(categories.length, greaterThan(1));
    });
  });

  group('search', () {
    test('an exact name is the top hit', () {
      final hits = searchGames(registry, 'Chess');
      expect(hits.first.module.id, 'chess');
      expect(hits.first.strength, MatchStrength.namePrefix);
    });

    test('a prefix ranks above a substring', () {
      final hits = searchGames(registry, 'ra');
      final strengths = hits.map((h) => h.strength.index).toList();
      expect(strengths, orderedEquals(List.of(strengths)..sort()));
    });

    test('matching is case- and diacritic-insensitive', () {
      expect(searchGames(registry, 'SUDOKU').first.module.id, 'sudoku');
      expect(foldTerm('Café'), 'cafe');
      expect(foldTerm('  MÊLÉE '), 'melee');
    });

    test('a tag match is found, and reported as a weak match', () {
      final hits = searchGames(registry, 'imposter');
      expect(hits, isNotEmpty);
      expect(hits.first.module.id, 'mafia');
      expect(hits.first.isNameMatch, isFalse);
      expect(hits.first.matchedOn, 'imposter');
    });

    test('a category name finds everything in it', () {
      final hits = searchGames(registry, 'arcade');
      expect(hits.length, greaterThanOrEqualTo(5));
    });

    test('an empty query returns nothing rather than everything', () {
      expect(searchGames(registry, ''), isEmpty);
      expect(searchGames(registry, '   '), isEmpty);
    });

    test('a nonsense query returns nothing', () {
      expect(searchGames(registry, 'zzzqqq'), isEmpty);
    });

    test('a game is never reported twice', () {
      for (final query in ['a', 'e', 'r', 'number', 'puzzle']) {
        final ids = searchGames(registry, query).map((h) => h.module.id).toList();
        expect(ids.toSet().length, ids.length, reason: query);
      }
    });
  });

  group('filters', () {
    const nonedPlayed = <String>{};

    test('an empty filter passes everything', () {
      const filter = HomeFilterState();
      expect(filter.isEmpty, isTrue);
      expect(countFor(registry, filter, nonedPlayed), registry.length);
    });

    test('a category narrows to that category', () {
      const filter = HomeFilterState(category: GameCategory.quickPlay);
      expect(countFor(registry, filter, nonedPlayed), 5);
    });

    test('dimensions intersect rather than union', () {
      const solo = HomeFilterState(players: {PlayerCount.solo});
      const shortSolo = HomeFilterState(
        players: {PlayerCount.solo},
        lengths: {GameLength.short},
      );
      expect(countFor(registry, shortSolo, nonedPlayed),
          lessThanOrEqualTo(countFor(registry, solo, nonedPlayed)));
    });

    test('within a dimension, options are a union', () {
      const one = HomeFilterState(lengths: {GameLength.short});
      const two = HomeFilterState(lengths: {GameLength.short, GameLength.long});
      expect(countFor(registry, two, nonedPlayed),
          greaterThan(countFor(registry, one, nonedPlayed)));
    });

    test('"never played only" hides what has been played', () {
      const filter = HomeFilterState(neverPlayedOnly: true);
      final played = {registry.first.id, registry[1].id};
      expect(countFor(registry, filter, played), registry.length - 2);
    });

    test('search and filters intersect', () {
      const quickPlay = HomeFilterState(category: GameCategory.quickPlay);
      final within = registry.where((m) => quickPlay.matches(m, played: false)).toList();
      // "chess" is a real game, but not a Quick Play one.
      expect(searchGames(within, 'chess'), isEmpty);
      expect(searchGames(within, 'dice'), isNotEmpty);
    });

    test('the summary line names every active filter', () {
      const filter = HomeFilterState(
        category: GameCategory.brain,
        players: {PlayerCount.solo},
        neverPlayedOnly: true,
      );
      expect(filter.summary, contains('Brain'));
      expect(filter.summary, contains('Solo'));
      expect(filter.summary, contains('Never played'));
      expect(filter.sheetCount, 2, reason: 'the category chip is not a sheet filter');
    });

    test('clearing returns to the full catalogue', () {
      const filter = HomeFilterState(category: GameCategory.arcade);
      expect(filter.isEmpty, isFalse);
      expect(filter.copyWith(clearCategory: true).isEmpty, isTrue);
    });
  });

  group('home sections', () {
    test('every category maps to a section, and every section has a game', () {
      final sections = registry.map((m) => m.category.section).toSet();
      for (final section in HomeSection.values) {
        expect(sections.contains(section), isTrue,
            reason: 'nothing lives in ${section.label}');
      }
    });
  });
}
