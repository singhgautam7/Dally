import '../theme/accents.dart';
import '../theme/palettes.dart';
import 'settings.dart';

/// The schema version [Settings] are written at. A change to what an absent or
/// stored value means bumps it and adds a step to [migrateSettings].
const int kSettingsSchemaVersion = 3;

/// Brings a stored settings blob written at schema [from] up to
/// [kSettingsSchemaVersion], one step at a time.
///
/// Runs once per install, not on every launch: [SettingsRepository.load] writes
/// the result straight back, so the next launch reads a current blob and never
/// comes here again.
Settings migrateSettings(Map<String, Object?> json, int from) {
  final raw = Map<String, Object?>.of(json);

  // v2 → v3: the first-launch theme moved from Ink (Dark, Azure) to the Blush
  // preset (Light, Blush), the one closest to the app icon's pink. An older
  // blob was written under Ink's defaults, so a theme key missing from it
  // meant Ink's value; pin those before the new defaults can fill the gap. A
  // key the blob does carry is the user's, and is kept as it is.
  raw.putIfAbsent('paletteId', () => 'ink');
  raw.putIfAbsent('themeMode', () => 'dark');
  raw.putIfAbsent('accentId', () => 'azure');

  var settings = Settings.fromJson(raw);
  if (from < 2) settings = _splitTheme(settings);
  return settings.copyWith(schemaVersion: kSettingsSchemaVersion);
}

/// v1 → v2: the stored `paletteId` becomes the three theme keys.
///
/// Every shipped id maps to exactly one triple, so this is a lookup with no
/// nearest-match guessing and nobody visibly loses their theme. An
/// unrecognised or absent id falls back to Ink — Dark, Azure, AMOLED off —
/// which was the first-launch default then. The old key is left in place for
/// one release so a downgrade is survivable.
Settings _splitTheme(Settings old) {
  final preset = DallyPalettes.presetById(old.paletteId) ?? DallyPalettes.fallback;
  return old.copyWith(
    themeMode: preset.mode.id,
    accentId: preset.accentId,
    amoled: preset.amoled,
  );
}
