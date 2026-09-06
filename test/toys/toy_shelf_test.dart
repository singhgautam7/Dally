import 'package:dally/core/game/game_category.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/storage/stats_repository.dart';
import 'package:dally/core/game/toy_module.dart';
import 'package:dally/core/storage/game_session.dart';
import 'package:dally/core/storage/stat_aggregate.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Toy is a sandbox: no win, no loss, no score, no turns and no opponent
/// (`.agents/CLAUDE.md` §11a). These are the structural guards — the same class
/// of bug as the BY GAME leak, caught in the shared path rather than per screen.
void main() {
  final toys = [for (final m in kGameModules) if (m is ToyModule) m];

  test('the shelf is registered, and every toy is in the Toys section', () {
    expect(toys, isNotEmpty);
    for (final t in toys) {
      expect(t.category, GameCategory.toy, reason: t.id);
      expect(t.category.section, HomeSection.toys, reason: t.id);
    }
  });

  test('every toy declares itself outcome-less', () {
    for (final t in toys) {
      expect(t.hasSessionOutcome, isFalse, reason: t.id);
    }
  });

  test('a toy renders no stats at all, played or not', () {
    // Not "renders zeros" and not "renders a dash" — nothing. A toy is absent
    // from Stats rather than present and empty.
    final busy = GameAggregate(
      sessions: 99,
      seconds: 1234,
      outcomes: {for (final o in SessionOutcome.values) o.name: 9},
      metrics: const {'score': MetricRollup(count: 9, sum: 90, min: 1, max: 40)},
    );
    for (final t in toys) {
      expect(t.statBlocks(busy), isEmpty, reason: t.id);
      expect(t.statSummary(busy), isNull, reason: t.id);
      expect(t.statBlocks(const GameAggregate()), isEmpty, reason: t.id);
      expect(t.statSummary(const GameAggregate()), isNull, reason: t.id);
    }
  });

  test('the home tile says what a toy is instead of a record it cannot have',
      () {
    for (final t in toys) {
      expect(t.homeBestLabel(_NoStats()), 'Sandbox', reason: t.id);
    }
  });

  test('a toy has nothing to save and nothing to explain', () {
    for (final t in toys) {
      expect(t.supportsSaveResume, isFalse, reason: t.id);
      expect(t.buildHowToPlay(_FakeContext()), isNull, reason: t.id);
      expect(t.firstRunHint.trim(), isNotEmpty, reason: t.id);
    }
  });

  test('toys carry searchable tags and a tagline, like everything else', () {
    for (final t in toys) {
      expect(t.tags, isNotEmpty, reason: t.id);
      expect(t.tagline.trim(), isNotEmpty, reason: t.id);
      expect(t.title.trim(), isNotEmpty, reason: t.id);
    }
  });

  test('the Toys category exists in the catalogue because a toy declared it',
      () {
    final categories = {for (final m in kGameModules) m.category};
    expect(categories, contains(GameCategory.toy));
    final sections = {for (final m in kGameModules) m.category.section};
    expect(sections, contains(HomeSection.toys));
  });

  test('every toy id is unique and stable-looking', () {
    final ids = [for (final m in kGameModules) m.id];
    expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    for (final t in toys) {
      expect(t.id, matches(RegExp(r'^[a-z0-9_]+$')), reason: t.id);
    }
  });

  test('a non-toy game is unaffected — it still counts things', () {
    final games = [for (final m in kGameModules) if (m is! ToyModule) m];
    expect(games, isNotEmpty);
    for (final g in games) {
      expect(g.hasSessionOutcome, isTrue, reason: g.id);
    }
  });

  test('Toys is labelled BETA, the same way Arcade is', () {
    expect(GameCategory.toy.label, 'Toys $kBetaSuffix');
    expect(HomeSection.toys.label, 'Toys $kBetaSuffix');
    // The same mechanism, not a second hardcoded string.
    expect(GameCategory.toy.beta, isTrue);
    expect(GameCategory.arcade.beta, isTrue);
    expect(GameCategory.arcade.label, 'Arcade $kBetaSuffix');
    expect(HomeSection.arcade.label, 'Arcade $kBetaSuffix');
  });

  test('nothing else claims to be BETA', () {
    for (final c in GameCategory.values) {
      expect(c.label.contains(kBetaSuffix), c.beta, reason: c.name);
      expect(c.name_, isNot(contains(kBetaSuffix)),
          reason: '${c.name}: the suffix belongs to the flag, not the name');
    }
    for (final s in HomeSection.values) {
      expect(s.label.contains(kBetaSuffix), s.beta, reason: s.name);
    }
  });
}

/// The home tile asks the stats repository for a best; a toy must not — so
/// this one fails the test if it is ever consulted.
class _NoStats implements StatsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('a toy asked the stats repository for a number');
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}