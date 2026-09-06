import 'package:dally/core/app_providers.dart';
import 'package:dally/core/game/game_category.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/game/toy_module.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/features/shell/home/home_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A toy registers once and lights up Home, Search and Filter with **zero
/// edits** to those screens (`.agents/CLAUDE.md` §2.1, §11a.1). These read the
/// same providers those screens do, so the claim is measured rather than
/// asserted in a comment.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = await KeyValueStore.open();
    container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  final toys = [for (final m in kGameModules) if (m is ToyModule) m];

  test('Home grows a Toys section holding exactly the toys', () {
    final sections = container.read(homeSectionsProvider);
    final toySection =
        sections.where((s) => s.$1 == HomeSection.toys).toList();
    expect(toySection, hasLength(1), reason: 'the shelf appeared on its own');
    expect(
      toySection.single.$2.map((m) => m.id).toSet(),
      toys.map((m) => m.id).toSet(),
    );
  });

  test('the Toys section sits alongside the game sections, not instead of them',
      () {
    final sections = container.read(homeSectionsProvider);
    expect(sections.map((s) => s.$1), contains(HomeSection.games));
    expect(sections.map((s) => s.$1), contains(HomeSection.toys));
  });

  test('the category chip row offers Toys because a toy declared it', () {
    expect(container.read(availableCategoriesProvider), contains(GameCategory.toy));
  });

  test('filtering to Toys returns the toys and nothing else', () {
    container.read(homeFilterProvider.notifier).selectCategory(GameCategory.toy);
    final shown = container.read(filteredGamesProvider);
    expect(shown.map((m) => m.id).toSet(), toys.map((m) => m.id).toSet());
    for (final m in shown) {
      expect(m, isA<ToyModule>(), reason: m.id);
    }
  });

  test('filtering to a game category never shows a toy', () {
    for (final c in GameCategory.values.where((c) => c != GameCategory.toy)) {
      container.read(homeFilterProvider.notifier).selectCategory(null);
      container.read(homeFilterProvider.notifier).selectCategory(c);
      for (final m in container.read(filteredGamesProvider)) {
        expect(m, isNot(isA<ToyModule>()), reason: '${c.label} showed ${m.id}');
      }
    }
  });

  test('every toy is findable by name', () {
    for (final t in toys) {
      container.read(searchQueryProvider.notifier).set(t.title);
      final hits = container.read(searchResultsProvider);
      expect(hits.map((h) => h.module.id), contains(t.id), reason: t.title);
    }
  });

  test('every toy is findable by its own tags', () {
    for (final t in toys) {
      for (final tag in t.tags) {
        container.read(searchQueryProvider.notifier).set(tag);
        final hits = container.read(searchResultsProvider);
        expect(hits.map((h) => h.module.id), contains(t.id),
            reason: '${t.id} is not findable by "$tag"');
      }
    }
  });

  test('"sandbox" finds the shelf', () {
    container.read(searchQueryProvider.notifier).set('sandbox');
    final hits = container.read(searchResultsProvider);
    expect(hits.map((h) => h.module.id).toSet().containsAll(toys.map((m) => m.id)),
        isTrue);
  });

  test('the catalogue line counts toys apart from games', () {
    final line = container.read(catalogueLineProvider);
    final toyCount = container.read(toyCountProvider);
    expect(toyCount, toys.length);
    expect(line, contains('$toyCount toy'));
    // …and the game count excludes them, so the copy never over-claims.
    final games = container.read(gameCountProvider) - toyCount;
    expect(line, startsWith('$games game'));
  });

  test('a toy never claims a player mode it does not have', () {
    for (final t in toys) {
      expect(t.players, {PlayerMode.single}, reason: t.id);
      expect(t.playerCount, PlayerCount.solo, reason: t.id);
    }
  });
}
