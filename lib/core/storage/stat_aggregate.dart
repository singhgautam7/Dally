import 'game_session.dart';

/// Running totals for one numeric metric — enough to answer "best", "average"
/// and "how many" in constant time without ever re-reading the session log.
class MetricRollup {
  const MetricRollup({this.count = 0, this.sum = 0, this.min, this.max});

  final int count;
  final num sum;
  final num? min;
  final num? max;

  bool get isEmpty => count == 0;

  double? get average => count == 0 ? null : sum / count;

  /// The best value under the metric's direction. Null when never recorded, so
  /// callers can render "—" rather than a zero that was never earned.
  num? best({required bool higherIsBetter}) => higherIsBetter ? max : min;

  MetricRollup add(num value) => MetricRollup(
        count: count + 1,
        sum: sum + value,
        min: min == null || value < min! ? value : min,
        max: max == null || value > max! ? value : max,
      );

  Map<String, Object?> toJson() => {
        'n': count,
        's': sum,
        if (min != null) 'lo': min,
        if (max != null) 'hi': max,
      };

  static MetricRollup fromJson(Object? raw) {
    if (raw is! Map) return const MetricRollup();
    final n = raw['n'];
    final s = raw['s'];
    return MetricRollup(
      count: n is int ? n : 0,
      sum: s is num ? s : 0,
      min: raw['lo'] is num ? raw['lo'] as num : null,
      max: raw['hi'] is num ? raw['hi'] as num : null,
    );
  }
}

/// Everything the Stats screen knows about one game (or one config of one
/// game), rolled up incrementally as sessions are written.
class GameAggregate {
  const GameAggregate({
    this.sessions = 0,
    this.seconds = 0,
    this.outcomes = const {},
    this.metrics = const {},
    this.configs = const {},
    this.lastPlayedMillis,
  });

  final int sessions;
  final int seconds;

  /// `SessionOutcome.name` → count.
  final Map<String, int> outcomes;

  /// Metric key → rollup. `score` is the game's headline number; everything
  /// else comes from the session's `extras`, i.e. from the module's own schema.
  final Map<String, MetricRollup> metrics;

  /// Per-config breakdown (difficulty, preset, speed) with the same shape,
  /// one level deep. Empty for games that report no config.
  final Map<String, GameAggregate> configs;

  final int? lastPlayedMillis;

  bool get isEmpty => sessions == 0;

  MetricRollup metric(String key) => metrics[key] ?? const MetricRollup();

  int outcome(SessionOutcome o) => outcomes[o.name] ?? 0;

  GameAggregate config(String label) => configs[label] ?? const GameAggregate();

  Map<String, Object?> toJson() => {
        'n': sessions,
        'sec': seconds,
        if (outcomes.isNotEmpty) 'out': outcomes,
        if (metrics.isNotEmpty)
          'ext': metrics.map((k, v) => MapEntry(k, v.toJson())),
        if (configs.isNotEmpty)
          'cfg': configs.map((k, v) => MapEntry(k, v.toJson())),
        if (lastPlayedMillis != null) 'last': lastPlayedMillis,
      };

  static GameAggregate fromJson(Object? raw, {bool nested = false}) {
    if (raw is! Map) return const GameAggregate();
    final outcomes = <String, int>{};
    final out = raw['out'];
    if (out is Map) {
      out.forEach((k, v) {
        if (k is String && v is int) outcomes[k] = v;
      });
    }
    final metrics = <String, MetricRollup>{};
    final ext = raw['ext'];
    if (ext is Map) {
      ext.forEach((k, v) {
        if (k is String) metrics[k] = MetricRollup.fromJson(v);
      });
    }
    final configs = <String, GameAggregate>{};
    if (!nested) {
      final cfg = raw['cfg'];
      if (cfg is Map) {
        cfg.forEach((k, v) {
          if (k is String) configs[k] = GameAggregate.fromJson(v, nested: true);
        });
      }
    }
    final n = raw['n'];
    final sec = raw['sec'];
    final last = raw['last'];
    return GameAggregate(
      sessions: n is int ? n : 0,
      seconds: sec is int ? sec : 0,
      outcomes: outcomes,
      metrics: metrics,
      configs: configs,
      lastPlayedMillis: last is int ? last : null,
    );
  }
}
