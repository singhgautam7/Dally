import 'package:dally/core/storage/history_repository.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/game/game_stats_schema.dart';
import 'package:dally/core/storage/game_session.dart';
import 'package:dally/features/shell/stats/game_stats_screen.dart';
import 'package:dally/features/shell/stats/stats_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Opening any game from the Stats overview's BY GAME list showed a blank
/// screen. A two-cell stat block laid its pair out in a `Row` with
/// `CrossAxisAlignment.stretch`, which asks the children for an *infinite*
/// height inside a scroll view — the layout threw and the body never painted.
///
/// This walks every registered game, so the next block kind that cannot survive
/// a scroll view fails the build instead of shipping as an empty screen.
void main() {
  /// Prefs holding one finished session for [gameId], with a value under every
  /// metric key the registry's modules ask for.
  ///
  /// Built by running the real repository over a scratch store and reading its
  /// documents back, so the fixture cannot drift from the storage format.
  Future<Map<String, Object>> playedOnce(String gameId) async {
    SharedPreferences.setMockInitialValues({});
    final store = await KeyValueStore.open();
    await HistoryRepository(store).record(GameSession(
          gameId: gameId,
          startedAt: DateTime.now(),
          durationSeconds: 90,
          outcome: SessionOutcome.won,
          score: 42,
          extras: const {
            'moves': 30,
            'score': 42,
            'duration': 90,
            'cleanDuration': 90,
            'puzzleMoves': 18,
            'longestChain': 3,
            'pillars': 12,
            'accuracy': 80,
          },
        ));
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in [HistoryRepository.rollupKey, HistoryRepository.sessionsKey])
        if (prefs.getString(key) != null) key: prefs.getString(key)!,
    };
  }

  for (final module in kGameModules) {
    testWidgets('${module.id}: its stats page renders once it has been played',
        (tester) async {
      final prefs = await playedOnce(module.id);
      await pumpGameScreen(tester, GameStatsScreen(gameId: module.id),
          size: const Size(320, 568), prefs: prefs);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: '${module.id} threw while laying out its stats');
      // The title is always there; the body must be too.
      expect(find.text(module.title), findsWidgets);
      if (module.hasSessionOutcome) {
        expect(find.byType(StatBlockView), findsWidgets,
            reason: '${module.id} rendered no blocks at all');
      }
    });
  }

  testWidgets('a two-cell block survives the narrowest phone', (tester) async {
    // The exact shape that used to throw: a cells block, in a scroll view.
    await pumpGameScreen(
      tester,
      const _Harness(
        block: StatBlock.cells(cells: [
          StatCell('Games', '12'),
          StatCell('Play time', '01:30'),
        ]),
      ),
      size: const Size(320, 568),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Play time'), findsOneWidget);
  });

  testWidgets('an odd cell count keeps its partner slot empty, not broken',
      (tester) async {
    await pumpGameScreen(
      tester,
      const _Harness(
        block: StatBlock.cells(cells: [
          StatCell('Games', '12'),
          StatCell('Play time', '01:30'),
          StatCell('Best', '900'),
        ]),
      ),
      size: const Size(320, 568),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Best'), findsOneWidget);
  });

  testWidgets('a toy is absent from stats rather than blank in it',
      (tester) async {
    final toy = kGameModules.firstWhere((m) => !m.hasSessionOutcome);
    await pumpGameScreen(tester, GameStatsScreen(gameId: toy.id));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(StatBlockView), findsNothing);
  });
}

/// One block in the same scrolling context the real screen uses.
class _Harness extends StatelessWidget {
  const _Harness({required this.block});
  final StatBlock block;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(children: [StatBlockView(block: block)]),
        ),
      );
}
