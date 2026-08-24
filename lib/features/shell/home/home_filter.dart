import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/game_registry.dart';

/// The active home filters. A category is single-select (the chip row); the
/// sheet dimensions are multi-select and intersect with it.
///
/// Filter state survives navigation within a session and is deliberately not
/// persisted across launches.
class HomeFilterState {
  const HomeFilterState({
    this.category,
    this.players = const {},
    this.lengths = const {},
    this.neverPlayedOnly = false,
  });

  final GameCategory? category;
  final Set<PlayerCount> players;
  final Set<GameLength> lengths;
  final bool neverPlayedOnly;

  bool get isEmpty =>
      category == null && players.isEmpty && lengths.isEmpty && !neverPlayedOnly;

  /// Filters set in the More sheet, i.e. everything but the category chip.
  int get sheetCount =>
      players.length + lengths.length + (neverPlayedOnly ? 1 : 0);

  bool matches(GameModule m, {required bool played}) {
    if (category != null && m.category != category) return false;
    if (players.isNotEmpty && !players.contains(m.playerCount)) return false;
    if (lengths.isNotEmpty && !lengths.contains(m.typicalLength)) return false;
    if (neverPlayedOnly && played) return false;
    return true;
  }

  /// A mono summary of what's in force, for the line under the chip row.
  String get summary {
    final parts = <String>[
      if (category != null) category!.label,
      ...players.map((p) => p.label),
      ...lengths.map((l) => l.label),
      if (neverPlayedOnly) 'Never played',
    ];
    return parts.join(' · ');
  }

  HomeFilterState copyWith({
    GameCategory? category,
    bool clearCategory = false,
    Set<PlayerCount>? players,
    Set<GameLength>? lengths,
    bool? neverPlayedOnly,
  }) =>
      HomeFilterState(
        category: clearCategory ? null : (category ?? this.category),
        players: players ?? this.players,
        lengths: lengths ?? this.lengths,
        neverPlayedOnly: neverPlayedOnly ?? this.neverPlayedOnly,
      );
}

class HomeFilterController extends Notifier<HomeFilterState> {
  @override
  HomeFilterState build() => const HomeFilterState();

  /// Tapping the active category clears it (the All chip does the same).
  void selectCategory(GameCategory? c) => state = c == null || c == state.category
      ? state.copyWith(clearCategory: true)
      : state.copyWith(category: c);

  void apply(HomeFilterState next) => state = next;

  void clear() => state = const HomeFilterState();
}

final homeFilterProvider =
    NotifierProvider<HomeFilterController, HomeFilterState>(HomeFilterController.new);

/// The search query. Empty means search mode is showing its idle state.
final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
  void clear() => state = '';
}

/// Catalogue categories with at least one registered game, in enum order — so
/// the chip row never offers a category nothing lives in.
final availableCategoriesProvider = Provider<List<GameCategory>>((ref) {
  final present = <GameCategory>{};
  for (final m in ref.watch(gameRegistryProvider)) {
    present.add(m.category);
  }
  return GameCategory.values.where(present.contains).toList();
});

/// Game ids with at least one recorded session — powers the "Never played only"
/// filter and the recents fallback.
final playedGameIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(historyRepositoryProvider).allAggregates().keys.toSet();
});

/// Games passing the current filter, in registry order.
final filteredGamesProvider = Provider<List<GameModule>>((ref) {
  final filter = ref.watch(homeFilterProvider);
  final played = ref.watch(playedGameIdsProvider);
  return ref
      .watch(gameRegistryProvider)
      .where((m) => filter.matches(m, played: played.contains(m.id)))
      .toList();
});

/// The games grouped into home's labelled bands, in section order. Sections
/// with no matching game are dropped entirely.
final homeSectionsProvider = Provider<List<(HomeSection, List<GameModule>)>>((ref) {
  final games = ref.watch(filteredGamesProvider);
  final out = <(HomeSection, List<GameModule>)>[];
  for (final section in HomeSection.values) {
    final inSection = games.where((m) => m.category.section == section).toList();
    if (inSection.isNotEmpty) out.add((section, inSection));
  }
  return out;
});

/// How many games a filter combination would return — used to disable
/// combinations in the sheet rather than let them empty the grid.
int countFor(List<GameModule> registry, HomeFilterState f, Set<String> played) =>
    registry.where((m) => f.matches(m, played: played.contains(m.id))).length;

/// How strongly a game matched a query. Lower is a stronger match; name hits
/// render as tiles in the grid, weaker hits drop into the labelled list.
enum MatchStrength { namePrefix, nameSubstring, category, vibe, tag }

class SearchHit {
  const SearchHit(this.module, this.strength, this.matchedOn);
  final GameModule module;
  final MatchStrength strength;

  /// The fragment that matched, shown in accent so the ranking is legible.
  final String matchedOn;

  bool get isNameMatch =>
      strength == MatchStrength.namePrefix || strength == MatchStrength.nameSubstring;
}

/// Case- and diacritic-insensitive fold, so "Cafe" finds "Café".
String foldTerm(String s) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
  const to = 'aaaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase().trim();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i == -1 ? ch : to[i]);
  }
  return buf.toString();
}

/// Ranks the catalogue against a query. Search and filters intersect: only
/// games that pass the active filter are searched.
List<SearchHit> searchGames(List<GameModule> games, String query) {
  final q = foldTerm(query);
  if (q.isEmpty) return const [];
  final hits = <SearchHit>[];
  for (final m in games) {
    final name = foldTerm(m.title);
    if (name.startsWith(q)) {
      hits.add(SearchHit(m, MatchStrength.namePrefix, m.title));
      continue;
    }
    if (name.contains(q)) {
      hits.add(SearchHit(m, MatchStrength.nameSubstring, m.title));
      continue;
    }
    if (foldTerm(m.category.label).contains(q)) {
      hits.add(SearchHit(m, MatchStrength.category, m.category.label));
      continue;
    }
    final vibe = m.vibes.where((v) => foldTerm(v.label).contains(q));
    if (vibe.isNotEmpty) {
      hits.add(SearchHit(m, MatchStrength.vibe, vibe.first.label));
      continue;
    }
    final tag = m.tags.where((t) => foldTerm(t).contains(q));
    if (tag.isNotEmpty) {
      hits.add(SearchHit(m, MatchStrength.tag, tag.first));
    }
  }
  hits.sort((a, b) => a.strength.index.compareTo(b.strength.index));
  return hits;
}

/// The live search result for the current query, intersected with filters.
final searchResultsProvider = Provider<List<SearchHit>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return searchGames(ref.watch(filteredGamesProvider), query);
});

/// The five chips offered under an empty search query — most recently played
/// first, falling back to catalogue order.
final suggestedGamesProvider = Provider<List<GameModule>>((ref) {
  final registry = ref.watch(gameRegistryProvider);
  final aggregates = ref.watch(historyRepositoryProvider).allAggregates();
  final recent = registry
      .where((m) => aggregates[m.id]?.lastPlayedMillis != null)
      .toList()
    ..sort((a, b) => (aggregates[b.id]!.lastPlayedMillis!)
        .compareTo(aggregates[a.id]!.lastPlayedMillis!));
  final out = <GameModule>[...recent];
  for (final m in registry) {
    if (out.length >= 5) break;
    if (!out.contains(m)) out.add(m);
  }
  return out.take(5).toList();
});
