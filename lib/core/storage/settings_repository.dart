import '../theme/accents.dart';
import '../theme/palettes.dart';
import 'key_value_store.dart';
import 'settings.dart';

/// Persists [Settings]. Reads are total: any corruption or version mismatch
/// falls back to defaults rather than throwing.
class SettingsRepository {
  SettingsRepository(this._store);

  final KeyValueStore _store;

  static const String _key = 'settings';

  /// v2 split the single `paletteId` into `themeMode` + `accentId` + `amoled`.
  static const int _currentVersion = 2;

  Settings load() {
    final json = _store.getJson(_key);
    if (json == null) return Settings.defaults;
    try {
      final version = json['schemaVersion'];
      if (version is! int || version > _currentVersion) {
        // Newer/unknown schema written by a future build — start clean.
        return Settings.defaults;
      }
      final settings = Settings.fromJson(json);
      return version < 2 ? migrateTheme(settings) : settings;
    } catch (_) {
      return Settings.defaults;
    }
  }

  /// v1 → v2: the stored `paletteId` becomes the three theme keys.
  ///
  /// Every shipped id maps to exactly one triple, so this is a lookup with no
  /// nearest-match guessing and nobody visibly loses their theme. An
  /// unrecognised or absent id falls back to Ink — Dark, Azure, AMOLED off —
  /// which is also the first-launch default. The old key is left in place for
  /// one release so a downgrade is survivable.
  static Settings migrateTheme(Settings old) {
    final preset = DallyPalettes.presetById(old.paletteId) ?? DallyPalettes.fallback;
    return old.copyWith(
      schemaVersion: _currentVersion,
      themeMode: preset.mode.id,
      accentId: preset.accentId,
      amoled: preset.amoled,
    );
  }

  Future<void> save(Settings settings) =>
      _store.setJson(_key, settings.copyWith(schemaVersion: _currentVersion).toJson());
}
