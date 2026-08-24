import 'package:dally/core/storage/game_session.dart';
import 'package:dally/core/storage/history_repository.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HistoryRepository> freshRepo() async {
  SharedPreferences.setMockInitialValues({});
  return HistoryRepository(await KeyValueStore.open());
}

GameSession session({
  String game = 'snake',
  DateTime? at,
  int duration = 60,
  SessionOutcome outcome = SessionOutcome.completed,
  String config = '',
  num? score,
  Map<String, num> extras = const {},
}) =>
    GameSession(
      gameId: game,
      startedAt: at ?? DateTime(2026, 8, 24, 12),
      durationSeconds: duration,
      outcome: outcome,
      configLabel: config,
      score: score,
      extras: extras,
    );

void main() {
  group('recording', () {
    test('a session lands in both the log and the aggregates', () async {
      final repo = await freshRepo();
      await repo.record(session(score: 12));

      expect(repo.totalSessions, 1);
      expect(repo.totalSeconds, 60);
      expect(repo.sessions().single.gameId, 'snake');
      expect(repo.aggregateFor('snake').metric('score').max, 12);
    });

    test('aggregates roll up across sessions', () async {
      final repo = await freshRepo();
      for (final s in [4, 9, 2]) {
        await repo.record(session(score: s, duration: 30));
      }
      final agg = repo.aggregateFor('snake');
      expect(agg.sessions, 3);
      expect(agg.seconds, 90);
      expect(agg.metric('score').max, 9);
      expect(agg.metric('score').min, 2);
      expect(agg.metric('score').average, closeTo(5, 1e-9));
    });

    test('outcomes are counted by name', () async {
      final repo = await freshRepo();
      await repo.record(session(game: 'chess', outcome: SessionOutcome.won));
      await repo.record(session(game: 'chess', outcome: SessionOutcome.won));
      await repo.record(session(game: 'chess', outcome: SessionOutcome.drawn));
      final agg = repo.aggregateFor('chess');
      expect(agg.outcome(SessionOutcome.won), 2);
      expect(agg.outcome(SessionOutcome.drawn), 1);
      expect(agg.outcome(SessionOutcome.lost), 0);
    });

    test('per-config rollups keep each difficulty separate', () async {
      final repo = await freshRepo();
      await repo.record(session(game: 'sudoku', config: 'Easy', score: 300));
      await repo.record(session(game: 'sudoku', config: 'Hard', score: 900));
      await repo.record(session(game: 'sudoku', config: 'Easy', score: 200));

      final agg = repo.aggregateFor('sudoku');
      expect(agg.config('Easy').sessions, 2);
      expect(agg.config('Easy').metric('score').min, 200);
      expect(agg.config('Hard').metric('score').min, 900);
      expect(agg.config('Nonexistent').isEmpty, isTrue);
    });

    test('game-specific extras roll up like any other metric', () async {
      final repo = await freshRepo();
      await repo.record(session(game: 'game_2048', extras: {'bestTile': 512}));
      await repo.record(session(game: 'game_2048', extras: {'bestTile': 1024}));
      expect(repo.aggregateFor('game_2048').metric('bestTile').max, 1024);
    });

    test('an unearned metric reads as empty, not zero', () async {
      final repo = await freshRepo();
      await repo.record(session());
      final m = repo.aggregateFor('snake').metric('nothingRecordsThis');
      expect(m.isEmpty, isTrue);
      expect(m.best(higherIsBetter: true), isNull);
      expect(m.average, isNull);
    });
  });

  group('scale', () {
    test('the log is capped, but the aggregates keep counting', () async {
      final repo = await freshRepo();
      for (var i = 0; i < 260; i++) {
        await repo.record(session(score: i, duration: 1));
      }
      // The session log is bounded — this is what keeps shared_preferences a
      // sound choice for history.
      expect(repo.retainedSessionCount, 200);
      // The totals still know about all 260.
      expect(repo.totalSessions, 260);
      expect(repo.totalSeconds, 260);
      expect(repo.aggregateFor('snake').metric('score').max, 259);
    });

    test('reading the overview never touches the session log', () async {
      final repo = await freshRepo();
      for (var i = 0; i < 250; i++) {
        await repo.record(session(score: i));
      }
      // Wiping the log leaves every overview number intact, which is only
      // possible because they come from the rollup document.
      final store = await KeyValueStore.open();
      await store.remove(HistoryRepository.sessionsKey);

      expect(repo.totalSessions, 250);
      expect(repo.aggregateFor('snake').sessions, 250);
      expect(repo.aggregateFor('snake').metric('score').max, 249);
      expect(repo.sessions(), isEmpty);
    });

    test('sessions page newest first', () async {
      final repo = await freshRepo();
      for (var i = 0; i < 40; i++) {
        await repo.record(session(score: i));
      }
      final first = repo.sessions(limit: 10);
      expect(first.length, 10);
      expect(first.first.score, 39);
      final second = repo.sessions(offset: 10, limit: 10);
      expect(second.first.score, 29);
      expect(repo.sessions(offset: 999), isEmpty);
    });
  });

  group('activity calendar', () {
    test('days are grouped by local calendar day', () async {
      final repo = await freshRepo();
      // 23:59 and 00:01 either side of local midnight are different days.
      await repo.record(session(at: DateTime(2026, 8, 24, 23, 59)));
      await repo.record(session(at: DateTime(2026, 8, 25, 0, 1)));
      final days = repo.activityByDay();
      expect(days['2026-08-24'], 1);
      expect(days['2026-08-25'], 1);
    });

    test('several sessions on one day count once each', () async {
      final repo = await freshRepo();
      for (var i = 0; i < 3; i++) {
        await repo.record(session(at: DateTime(2026, 8, 24, 9 + i)));
      }
      expect(repo.activityByDay()['2026-08-24'], 3);
    });

    test('a streak counts back over consecutive days', () async {
      final repo = await freshRepo();
      for (var d = 20; d <= 24; d++) {
        await repo.record(session(at: DateTime(2026, 8, d, 10)));
      }
      expect(repo.currentStreak(now: DateTime(2026, 8, 24, 20)), 5);
    });

    test('a streak survives until a whole day is missed', () async {
      final repo = await freshRepo();
      await repo.record(session(at: DateTime(2026, 8, 23, 10)));
      // Nothing played today yet — yesterday still counts.
      expect(repo.currentStreak(now: DateTime(2026, 8, 24, 10)), 1);
      // Two days idle breaks it.
      expect(repo.currentStreak(now: DateTime(2026, 8, 25, 10)), 0);
    });

    test('a streak crossing a month boundary does not skip a day', () async {
      final repo = await freshRepo();
      for (final d in [DateTime(2026, 2, 27), DateTime(2026, 2, 28), DateTime(2026, 3, 1)]) {
        await repo.record(session(at: d.add(const Duration(hours: 10))));
      }
      expect(repo.currentStreak(now: DateTime(2026, 3, 1, 20)), 3);
    });

    test('the longest streak is found anywhere in history', () async {
      final repo = await freshRepo();
      for (final d in [1, 2, 3, 4, 10, 11]) {
        await repo.record(session(at: DateTime(2026, 8, d, 10)));
      }
      expect(repo.longestStreak(), 4);
      expect(repo.currentStreak(now: DateTime(2026, 8, 11, 12)), 2);
    });

    test('no history means no streak', () async {
      final repo = await freshRepo();
      expect(repo.currentStreak(), 0);
      expect(repo.longestStreak(), 0);
      expect(repo.totalSessions, 0);
    });
  });

  group('durability', () {
    test('a corrupt rollup falls back to empty rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        HistoryRepository.rollupKey: 'not json at all',
        HistoryRepository.sessionsKey: '{"schemaVersion":1,"items":"nope"}',
      });
      final repo = HistoryRepository(await KeyValueStore.open());
      expect(repo.totalSessions, 0);
      expect(repo.sessions(), isEmpty);
      expect(repo.aggregateFor('snake').isEmpty, isTrue);
    });

    test('a newer schema is discarded, not guessed at', () async {
      SharedPreferences.setMockInitialValues({
        HistoryRepository.rollupKey: '{"schemaVersion":99,"sessions":500}',
      });
      final repo = HistoryRepository(await KeyValueStore.open());
      expect(repo.totalSessions, 0);
    });

    test('a malformed session row is skipped, not fatal', () async {
      SharedPreferences.setMockInitialValues({
        HistoryRepository.sessionsKey:
            '{"schemaVersion":1,"items":[{"g":"snake","t":1,"o":"won"},{"broken":true}]}',
      });
      final repo = HistoryRepository(await KeyValueStore.open());
      expect(repo.sessions().length, 1);
      expect(repo.sessions().single.gameId, 'snake');
    });

    test('writing still works after a corrupt read', () async {
      SharedPreferences.setMockInitialValues({
        HistoryRepository.rollupKey: '{{{ broken',
      });
      final repo = HistoryRepository(await KeyValueStore.open());
      await repo.record(session(score: 5));
      expect(repo.totalSessions, 1);
    });

    test('reset clears both documents', () async {
      final repo = await freshRepo();
      await repo.record(session());
      await repo.reset();
      expect(repo.totalSessions, 0);
      expect(repo.sessions(), isEmpty);
    });
  });

  group('GameSession', () {
    test('round-trips through JSON', () {
      final original = session(
        config: 'Expert',
        score: 42,
        extras: {'mines': 99},
        outcome: SessionOutcome.solved,
      );
      final restored = GameSession.fromJson(original.toJson())!;
      expect(restored.gameId, original.gameId);
      expect(restored.outcome, SessionOutcome.solved);
      expect(restored.configLabel, 'Expert');
      expect(restored.score, 42);
      expect(restored.extras['mines'], 99);
    });

    test('dayBefore normalises month and year ends', () {
      expect(GameSession.dayKeyOf(GameSession.dayBefore(DateTime(2026, 3, 1))), '2026-02-28');
      expect(GameSession.dayKeyOf(GameSession.dayBefore(DateTime(2026, 1, 1))), '2025-12-31');
    });
  });
}
