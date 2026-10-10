import 'dart:async';

import 'key_value_store.dart';
import 'settings.dart';
import 'settings_migrations.dart';

/// Persists [Settings]. Reads are total: any corruption or version mismatch
/// falls back to defaults rather than throwing.
class SettingsRepository {
  SettingsRepository(this._store);

  final KeyValueStore _store;

  static const String _key = 'settings';

  Settings load() {
    final json = _store.getJson(_key);
    if (json == null) return Settings.defaults;
    try {
      final version = json['schemaVersion'];
      if (version is! int || version > kSettingsSchemaVersion) {
        // Newer/unknown schema written by a future build — start clean.
        return Settings.defaults;
      }
      if (version == kSettingsSchemaVersion) return Settings.fromJson(json);
      // Written back at once, so each migration runs a single time per install
      // instead of on every launch until something else happens to save.
      final migrated = migrateSettings(json, version);
      unawaited(save(migrated));
      return migrated;
    } catch (_) {
      return Settings.defaults;
    }
  }

  Future<void> save(Settings settings) =>
      _store.setJson(_key, settings.copyWith(schemaVersion: kSettingsSchemaVersion).toJson());
}
