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
}) {
  return ref.read(historyRepositoryProvider).record(
        GameSession(
          gameId: gameId,
          startedAt: startedAt,
          durationSeconds: durationSeconds < 0 ? 0 : durationSeconds,
          outcome: outcome,
          configLabel: configLabel,
          score: score,
          extras: extras,
        ),
      );
}
