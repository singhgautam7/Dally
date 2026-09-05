import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../storage/game_session.dart';

/// The one call a game makes when a play ends. It writes the session (which
/// rolls up into every statistic the Stats screens show) and bumps the legacy
/// per-game counters the home tiles still read.
///
/// Fire-and-forget by design: it is awaited off the frame, never inside a
/// gesture handler that is holding up the UI.
Future<void> recordSession(
  WidgetRef ref, {
  required String gameId,
  required DateTime startedAt,
  required int durationSeconds,
  required SessionOutcome outcome,
  String configLabel = '',
  num? score,
  Map<String, num> extras = const {},
  bool usedUndo = false,
}) {
  // Record integrity (`.agents/CLAUDE.md` §7.3). Everything here is written
  // once, at the end of a game, from the final state — so an undone move can
  // never double-count. What undo *could* still corrupt is a record: a best
  // score or a best time earned by rewinding a mistake.
  //
  // A flagged session therefore still counts as a game played, still counts
  // toward wins, losses and play time, and still appears in history. It is
  // excluded only from the two record-shaped metrics: `score` is dropped, and
  // `cleanDuration` — the metric a best *time* is read from — is not written.
  // Plain `duration` keeps counting, so averages and play time stay true.
  final seconds = durationSeconds < 0 ? 0 : durationSeconds;
  return ref.read(historyRepositoryProvider).record(
        GameSession(
          gameId: gameId,
          startedAt: startedAt,
          durationSeconds: seconds,
          outcome: outcome,
          configLabel: configLabel,
          score: usedUndo ? null : score,
          extras: {
            ...extras,
            if (usedUndo) 'usedUndo': 1 else 'cleanDuration': seconds,
          },
        ),
      );
}
