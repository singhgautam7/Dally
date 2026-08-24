/// How a session ended. Games pick the members that mean something for them —
/// a Sudoku is `solved`/`failed`, a Chess game is `won`/`lost`/`drawn`, an
/// arcade run is just `completed`. Nothing forces a game to report an outcome
/// it can't produce.
enum SessionOutcome {
  won('Won'),
  lost('Lost'),
  drawn('Drawn'),
  solved('Solved'),
  failed('Failed'),
  completed('Played'),
  abandoned('Left');

  const SessionOutcome(this.label);
  final String label;

  static SessionOutcome? parse(Object? raw) {
    if (raw is! String) return null;
    for (final o in SessionOutcome.values) {
      if (o.name == raw) return o;
    }
    return null;
  }
}

/// One finished (or abandoned) play of one game. This is the only thing games
/// write; every derived number — streaks, averages, records, most played — is
/// rolled up from these, so a new game never touches the Stats screen.
class GameSession {
  const GameSession({
    required this.gameId,
    required this.startedAt,
    required this.durationSeconds,
    required this.outcome,
    this.configLabel = '',
    this.score,
    this.extras = const {},
  });

  final String gameId;
  final DateTime startedAt;
  final int durationSeconds;
  final SessionOutcome outcome;

  /// Human config line — "Expert", "5×5 · Ana vs Bo", "Normal · Large".
  final String configLabel;

  /// The game's headline number, if it has one (score, length, distance).
  final num? score;

  /// Game-specific metrics, declared by the module's stat schema. Numbers only
  /// so they roll up without special cases.
  final Map<String, num> extras;

  /// The local calendar day this session belongs to, `YYYY-MM-DD`. Defined
  /// against local midnight so the activity grid and streaks match what the
  /// player actually experienced, across timezone and DST changes.
  String get dayKey => dayKeyOf(startedAt);

  static String dayKeyOf(DateTime t) {
    final l = t.toLocal();
    final m = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    return '${l.year}-$m-$d';
  }

  /// Local midnight of the day [t] falls in. Built through the [DateTime]
  /// constructor rather than by subtracting hours, so a DST boundary can't
  /// shift it into the previous day.
  static DateTime startOfDay(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// The calendar day [days] before [t]'s day. Again constructor-normalised —
  /// `DateTime(2026, 3, 0)` is the last day of February.
  static DateTime dayBefore(DateTime t, [int days = 1]) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day - days);
  }

  Map<String, Object?> toJson() => {
        'g': gameId,
        't': startedAt.millisecondsSinceEpoch,
        'd': durationSeconds,
        'o': outcome.name,
        if (configLabel.isNotEmpty) 'c': configLabel,
        if (score != null) 's': score,
        if (extras.isNotEmpty) 'x': extras,
      };

  static GameSession? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final gameId = raw['g'];
    final millis = raw['t'];
    final outcome = SessionOutcome.parse(raw['o']);
    if (gameId is! String || millis is! int || outcome == null) return null;
    final extras = <String, num>{};
    final x = raw['x'];
    if (x is Map) {
      x.forEach((k, v) {
        if (k is String && v is num) extras[k] = v;
      });
    }
    final duration = raw['d'];
    final score = raw['s'];
    return GameSession(
      gameId: gameId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      durationSeconds: duration is int ? duration : 0,
      outcome: outcome,
      configLabel: raw['c'] is String ? raw['c'] as String : '',
      score: score is num ? score : null,
      extras: extras,
    );
  }
}
