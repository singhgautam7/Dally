import 'dart:convert';

import 'game_session.dart';
import 'key_value_store.dart';
import 'stat_aggregate.dart';

/// Session history and the rolled-up statistics derived from it.
///
/// ## Storage decision (see `specs/performance.md` §5)
///
/// `shared_preferences` rewrites its whole payload on every write, which is a
/// real scaling cliff for an unbounded log. Two things keep it the right call
/// here rather than pulling in a local database:
///
/// 1. **The log is bounded.** The design retains the last 200 sessions
///    (`_maxSessions`); older ones are dropped as they age out. 200 records is
///    roughly 20 KB of JSON — a rewrite is sub-millisecond and off the frame.
/// 2. **Stats never read the log.** Every number the Stats screens show comes
///    from [rollup], a separate key holding incremental aggregates. Opening
///    Stats is one small read whose cost does not grow with play history. The
///    session list is read only by the Activity screen, which pages it.
///
/// The three concerns live under three keys so they never interfere:
/// `history.sessions` (the capped log), `history.rollup` (aggregates + the
/// activity calendar), and — elsewhere — `settings` and `save.<gameId>`.
class HistoryRepository {
  HistoryRepository(this._store);

  final KeyValueStore _store;

  static const String sessionsKey = 'history.sessions';
  static const String rollupKey = 'history.rollup';
  static const int schemaVersion = 1;

  /// Retained sessions. Matches the design's "last 200 sessions retained".
  static const int _maxSessions = 200;

  // ── Writing ───────────────────────────────────────────────────────────────

  /// Records one finished session: appends to the capped log and folds it into
  /// the aggregates. Both writes are awaited together so the two documents can
  /// never disagree about a session that is visible in one and not the other.
  Future<void> record(GameSession session) async {
    await _appendSession(session);
    await _foldIntoRollup(session);
  }

  Future<void> _appendSession(GameSession session) async {
    final list = _rawSessions();
    list.insert(0, session.toJson());
    if (list.length > _maxSessions) list.removeRange(_maxSessions, list.length);
    await _store.setJson(sessionsKey, {
      'schemaVersion': schemaVersion,
      'items': list,
    });
  }

  Future<void> _foldIntoRollup(GameSession session) async {
    final doc = _rollupDoc();

    doc['sessions'] = (_int(doc['sessions'])) + 1;
    doc['seconds'] = (_int(doc['seconds'])) + session.durationSeconds;

    final days = Map<String, Object?>.from(_map(doc['days']));
    days[session.dayKey] = _int(days[session.dayKey]) + 1;
    doc['days'] = days;

    final games = Map<String, Object?>.from(_map(doc['games']));
    final current = GameAggregate.fromJson(games[session.gameId]);
    games[session.gameId] = _fold(current, session).toJson();
    doc['games'] = games;

    await _store.setJson(rollupKey, doc);
  }

  GameAggregate _fold(GameAggregate agg, GameSession s) {
    final outcomes = Map<String, int>.from(agg.outcomes);
    outcomes[s.outcome.name] = (outcomes[s.outcome.name] ?? 0) + 1;

    final metrics = Map<String, MetricRollup>.from(agg.metrics);
    void addMetric(String key, num value) {
      metrics[key] = (metrics[key] ?? const MetricRollup()).add(value);
    }

    if (s.score != null) addMetric('score', s.score!);
    addMetric('duration', s.durationSeconds);
    s.extras.forEach(addMetric);

    // One level of per-config breakdown (difficulty / preset / size), with the
    // same shape, so "best time per difficulty" needs no special storage.
    final configs = Map<String, GameAggregate>.from(agg.configs);
    if (s.configLabel.isNotEmpty) {
      final nested = configs[s.configLabel] ?? const GameAggregate();
      configs[s.configLabel] = GameAggregate(
        sessions: nested.sessions + 1,
        seconds: nested.seconds + s.durationSeconds,
        outcomes: {
          ...nested.outcomes,
          s.outcome.name: (nested.outcomes[s.outcome.name] ?? 0) + 1,
        },
        metrics: _foldMetrics(nested.metrics, s),
        lastPlayedMillis: s.startedAt.millisecondsSinceEpoch,
      );
    }

    return GameAggregate(
      sessions: agg.sessions + 1,
      seconds: agg.seconds + s.durationSeconds,
      outcomes: outcomes,
      metrics: metrics,
      configs: configs,
      lastPlayedMillis: s.startedAt.millisecondsSinceEpoch,
    );
  }

  Map<String, MetricRollup> _foldMetrics(
      Map<String, MetricRollup> base, GameSession s) {
    final out = Map<String, MetricRollup>.from(base);
    void add(String key, num value) {
      out[key] = (out[key] ?? const MetricRollup()).add(value);
    }

    if (s.score != null) add('score', s.score!);
    add('duration', s.durationSeconds);
    s.extras.forEach(add);
    return out;
  }

  // ── Reading (constant-time paths first) ───────────────────────────────────

  /// Total sessions ever recorded — including ones aged out of the log.
  int get totalSessions => _int(_rollupDoc()['sessions']);

  /// Total play time in seconds, all games, all time.
  int get totalSeconds => _int(_rollupDoc()['seconds']);

  /// Aggregates for one game. Constant time — never touches the session log.
  GameAggregate aggregateFor(String gameId) =>
      GameAggregate.fromJson(_map(_rollupDoc()['games'])[gameId]);

  /// Every game with at least one recorded session, id → aggregate.
  Map<String, GameAggregate> allAggregates() {
    final out = <String, GameAggregate>{};
    _map(_rollupDoc()['games']).forEach((k, v) {
      out[k] = GameAggregate.fromJson(v);
    });
    return out;
  }

  /// Sessions per local calendar day, `YYYY-MM-DD` → count. Bounded by days
  /// played, a few KB a year, and the only thing the activity heatmap needs.
  Map<String, int> activityByDay() {
    final out = <String, int>{};
    _map(_rollupDoc()['days']).forEach((k, v) {
      final n = _int(v);
      if (n > 0) out[k] = n;
    });
    return out;
  }

  /// Consecutive days up to and including today (or yesterday, so a streak
  /// isn't broken until a whole day is missed). Walks the day map through the
  /// [DateTime] constructor, so DST and month ends can't skip or double a day.
  int currentStreak({DateTime? now}) {
    final days = activityByDay();
    if (days.isEmpty) return 0;
    var cursor = GameSession.startOfDay(now ?? DateTime.now());
    if (!days.containsKey(GameSession.dayKeyOf(cursor))) {
      cursor = GameSession.dayBefore(cursor);
      if (!days.containsKey(GameSession.dayKeyOf(cursor))) return 0;
    }
    var streak = 0;
    while (days.containsKey(GameSession.dayKeyOf(cursor))) {
      streak++;
      cursor = GameSession.dayBefore(cursor);
    }
    return streak;
  }

  /// The longest run of consecutive active days ever recorded.
  int longestStreak() {
    final days = activityByDay().keys.toList()..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final prev = _parseDay(days[i - 1]);
      final cur = _parseDay(days[i]);
      if (prev == null || cur == null) continue;
      final expected = GameSession.dayKeyOf(DateTime(prev.year, prev.month, prev.day + 1));
      if (expected == days[i]) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// A page of the session log, newest first. The Activity screen is the only
  /// caller; Stats overview never uses it.
  List<GameSession> sessions({int offset = 0, int limit = 30}) {
    final raw = _rawSessions();
    if (offset >= raw.length) return const [];
    final end = (offset + limit).clamp(0, raw.length);
    final out = <GameSession>[];
    for (var i = offset; i < end; i++) {
      final s = GameSession.fromJson(raw[i]);
      if (s != null) out.add(s);
    }
    return out;
  }

  /// How many sessions are actually retained in the log (≤ [_maxSessions]).
  int get retainedSessionCount => _rawSessions().length;

  Future<void> reset() async {
    await _store.remove(sessionsKey);
    await _store.remove(rollupKey);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Map<String, Object?> _rollupDoc() {
    final json = _store.getJson(rollupKey);
    if (json == null) return _emptyRollup();
    final v = json['schemaVersion'];
    // Unknown/newer schema written by a future build — start clean rather than
    // guess at its shape. Older versions would migrate here.
    if (v is! int || v > schemaVersion) return _emptyRollup();
    return Map<String, Object?>.from(json);
  }

  Map<String, Object?> _emptyRollup() => {
        'schemaVersion': schemaVersion,
        'sessions': 0,
        'seconds': 0,
        'days': <String, Object?>{},
        'games': <String, Object?>{},
      };

  List<Object?> _rawSessions() {
    final json = _store.getJson(sessionsKey);
    if (json == null) return <Object?>[];
    final v = json['schemaVersion'];
    if (v is! int || v > schemaVersion) return <Object?>[];
    final items = json['items'];
    return items is List ? List<Object?>.from(items) : <Object?>[];
  }

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? Map<String, Object?>.from(v) : <String, Object?>{};

  static int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

  static DateTime? _parseDay(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}

/// Approximate stored size of the history documents, for the debug/about
/// screen and for the performance assertion that the log stays small.
int historyByteSize(KeyValueStore store) {
  var total = 0;
  for (final key in [HistoryRepository.sessionsKey, HistoryRepository.rollupKey]) {
    final raw = store.getString(key);
    if (raw != null) total += utf8.encode(raw).length;
  }
  return total;
}
