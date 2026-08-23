import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/game_registry.dart';

/// The active home filters — a set of player modes and a set of vibes. Within a
/// dimension the match is OR; across dimensions it is AND. Empty = show all.
class HomeFilterState {
  const HomeFilterState({this.players = const {}, this.vibes = const {}});

  final Set<PlayerMode> players;
  final Set<Vibe> vibes;

  bool get isEmpty => players.isEmpty && vibes.isEmpty;

  bool matches(GameModule m) {
    final playerOk = players.isEmpty || m.players.any(players.contains);
    final vibeOk = vibes.isEmpty || m.vibes.any(vibes.contains);
    return playerOk && vibeOk;
  }

  HomeFilterState copyWith({Set<PlayerMode>? players, Set<Vibe>? vibes}) =>
      HomeFilterState(players: players ?? this.players, vibes: vibes ?? this.vibes);
}

class HomeFilterController extends Notifier<HomeFilterState> {
  @override
  HomeFilterState build() => const HomeFilterState();

  void togglePlayer(PlayerMode p) {
    final next = Set<PlayerMode>.from(state.players);
    next.contains(p) ? next.remove(p) : next.add(p);
    state = state.copyWith(players: next);
  }

  void toggleVibe(Vibe v) {
    final next = Set<Vibe>.from(state.vibes);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(vibes: next);
  }

  void clear() => state = const HomeFilterState();
}

final homeFilterProvider =
    NotifierProvider<HomeFilterController, HomeFilterState>(HomeFilterController.new);

/// The vibes actually present across registered games, in enum order — so the
/// filter row never offers a vibe (e.g. mental math) that no game has yet.
final availableVibesProvider = Provider<List<Vibe>>((ref) {
  final present = <Vibe>{};
  for (final m in ref.watch(gameRegistryProvider)) {
    present.addAll(m.vibes);
  }
  return Vibe.values.where(present.contains).toList();
});

/// The player modes present across registered games, in enum order.
final availablePlayersProvider = Provider<List<PlayerMode>>((ref) {
  final present = <PlayerMode>{};
  for (final m in ref.watch(gameRegistryProvider)) {
    present.addAll(m.players);
  }
  return PlayerMode.values.where(present.contains).toList();
});

/// Games passing the current filter, in registry order.
final filteredGamesProvider = Provider<List<GameModule>>((ref) {
  final filter = ref.watch(homeFilterProvider);
  return ref.watch(gameRegistryProvider).where(filter.matches).toList();
});
