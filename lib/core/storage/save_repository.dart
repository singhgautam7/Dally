import 'key_value_store.dart';

/// Per-game in-progress save/restore. Each game owns the shape of its blob; the
/// only contract is that it is JSON-encodable and carries a `schemaVersion`.
///
/// A corrupt or version-mismatched save is discarded (returns null), so the game
/// offers a fresh board rather than crashing.
class SaveRepository {
  SaveRepository(this._store);

  final KeyValueStore _store;

  String _key(String gameId) => 'save.$gameId';

  /// Loads the raw save blob for [gameId]. Callers pass the [maxSchemaVersion]
  /// they understand; anything newer is discarded.
  Map<String, Object?>? load(String gameId, {required int maxSchemaVersion}) {
    final json = _store.getJson(_key(gameId));
    if (json == null) return null;
    final version = json['schemaVersion'];
    if (version is! int || version > maxSchemaVersion) return null;
    return json;
  }

  bool hasSave(String gameId) => _store.getString(_key(gameId)) != null;

  /// Persists [data] for [gameId]. [data] must already include `schemaVersion`.
  Future<void> save(String gameId, Map<String, Object?> data) =>
      _store.setJson(_key(gameId), data);

  Future<void> clear(String gameId) => _store.remove(_key(gameId));
}
