import 'key_value_store.dart';
import 'settings.dart';

/// Persists [Settings]. Reads are total: any corruption or version mismatch
/// falls back to defaults rather than throwing.
class SettingsRepository {
  SettingsRepository(this._store);

  final KeyValueStore _store;

  static const String _key = 'settings';
  static const int _currentVersion = 1;

  Settings load() {
    final json = _store.getJson(_key);
    if (json == null) return Settings.defaults;
    try {
      final version = json['schemaVersion'];
      if (version is! int || version > _currentVersion) {
        // Newer/unknown schema written by a future build — start clean.
        return Settings.defaults;
      }
      return Settings.fromJson(json);
    } catch (_) {
      return Settings.defaults;
    }
  }

  Future<void> save(Settings settings) => _store.setJson(_key, settings.toJson());
}
