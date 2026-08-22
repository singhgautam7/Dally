import 'key_value_store.dart';

/// Per-game best scores and counters. Everything lives under one versioned JSON
/// document; reads never throw.
///
/// Keys are namespaced by the caller as `"<gameId>.<statKey>"` (e.g.
/// `"minesweeper.bestTime.expert"`), which keeps stats decoupled from the shell.
class StatsRepository {
  StatsRepository(this._store);

  final KeyValueStore _store;

  static const String _key = 'stats';
  static const int _currentVersion = 1;

  Map<String, Object?> _doc() {
    final json = _store.getJson(_key);
    if (json == null) return _empty();
    final version = json['schemaVersion'];
    if (version is! int || version > _currentVersion) return _empty();
    return json;
  }

  Map<String, Object?> _empty() => {
        'schemaVersion': _currentVersion,
        'bests': <String, Object?>{},
        'counts': <String, Object?>{},
      };

  Map<String, Object?> _section(Map<String, Object?> doc, String name) {
    final s = doc[name];
    return s is Map<String, Object?> ? s : <String, Object?>{};
  }

  /// The best value recorded for [key], or null if none.
  double? bestOf(String key) {
    final v = _section(_doc(), 'bests')[key];
    return v is num ? v.toDouble() : null;
  }

  int countOf(String key) {
    final v = _section(_doc(), 'counts')[key];
    return v is int ? v : (v is num ? v.toInt() : 0);
  }

  /// Records [value] if it beats the stored best under the given direction.
  /// Returns true when a new record was set.
  Future<bool> recordBest(
    String key,
    double value, {
    required bool higherIsBetter,
  }) async {
    final doc = _doc();
    final bests = Map<String, Object?>.from(_section(doc, 'bests'));
    final current = bests[key];
    final isBetter = current is! num ||
        (higherIsBetter ? value > current : value < current);
    if (!isBetter) return false;
    bests[key] = value;
    doc['bests'] = bests;
    await _store.setJson(_key, doc);
    return true;
  }

  Future<void> increment(String key, [int by = 1]) async {
    final doc = _doc();
    final counts = Map<String, Object?>.from(_section(doc, 'counts'));
    counts[key] = countOf(key) + by;
    doc['counts'] = counts;
    await _store.setJson(_key, doc);
  }

  /// Every stored key/value, for the Stats screen. Values are `num`.
  Map<String, num> allBests() {
    final out = <String, num>{};
    _section(_doc(), 'bests').forEach((k, v) {
      if (v is num) out[k] = v;
    });
    return out;
  }

  Map<String, int> allCounts() {
    final out = <String, int>{};
    _section(_doc(), 'counts').forEach((k, v) {
      if (v is int) out[k] = v;
    });
    return out;
  }

  Future<void> reset() => _store.remove(_key);
}
