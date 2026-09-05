import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/storage/settings.dart';
import 'package:dally/core/storage/settings_repository.dart';
import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsRepository> repoWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsRepository(await KeyValueStore.open());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1 → v2 theme migration', () {
    // Every shipped id maps to exactly one triple, so this is a lookup with no
    // nearest-match guessing and nobody visibly loses their theme.
    const expected = {
      'ink': (DallyMode.dark, 'azure', false),
      'ember': (DallyMode.dark, 'ember', false),
      'tide': (DallyMode.dark, 'tide', false),
      'paper': (DallyMode.light, 'azure', false),
      'meadow': (DallyMode.light, 'meadow', false),
      'blush': (DallyMode.light, 'blush', false),
      'void': (DallyMode.dark, 'azure', true),
      'neon': (DallyMode.dark, 'neon', true),
    };

    for (final entry in expected.entries) {
      test('${entry.key} becomes its triple', () async {
        final repo = await repoWith({
          'settings': '{"schemaVersion":1,"paletteId":"${entry.key}"}',
        });
        final s = repo.load();
        expect(s.schemaVersion, 2);
        expect(modeFromId(s.themeMode), entry.value.$1);
        expect(s.accentId, entry.value.$2);
        expect(s.amoled, entry.value.$3);
        // …and the triple names the same preset back.
        expect(DallyPalettes.presetFor(modeFromId(s.themeMode), s.accentId, s.amoled)?.id,
            entry.key);
      });
    }

    test('the old key survives the migration, for one release', () async {
      final repo = await repoWith({'settings': '{"schemaVersion":1,"paletteId":"tide"}'});
      expect(repo.load().paletteId, 'tide');
    });

    test('an unrecognised id falls back to Ink', () async {
      final repo = await repoWith({'settings': '{"schemaVersion":1,"paletteId":"aubergine"}'});
      final s = repo.load();
      expect(modeFromId(s.themeMode), DallyMode.dark);
      expect(s.accentId, 'azure');
      expect(s.amoled, isFalse);
    });

    test('an absent id falls back to Ink', () async {
      final repo = await repoWith({'settings': '{"schemaVersion":1}'});
      final s = repo.load();
      expect(s.accentId, 'azure');
      expect(modeFromId(s.themeMode), DallyMode.dark);
    });

    test('other settings are untouched by the migration', () async {
      final repo = await repoWith({
        'settings': '{"schemaVersion":1,"paletteId":"paper","longPressMs":250,'
            '"soundEnabled":true,"styleChoices":{"chess":"outline"}}',
      });
      final s = repo.load();
      expect(s.longPressMs, 250);
      expect(s.soundEnabled, isTrue);
      expect(s.styleChoices['chess'], 'outline');
    });

    test('a v2 payload is read as-is, never re-migrated', () async {
      final repo = await repoWith({
        'settings': '{"schemaVersion":2,"paletteId":"ink","themeMode":"light",'
            '"accentId":"citron","amoled":true}',
      });
      final s = repo.load();
      // A custom triple must survive even though `paletteId` still says Ink.
      expect(modeFromId(s.themeMode), DallyMode.light);
      expect(s.accentId, 'citron');
      expect(s.amoled, isTrue);
      expect(DallyPalettes.presetFor(modeFromId(s.themeMode), s.accentId, s.amoled), isNull);
    });

    test('a newer schema is discarded to defaults rather than guessed at', () async {
      final repo = await repoWith({'settings': '{"schemaVersion":99,"accentId":"nope"}'});
      expect(repo.load(), Settings.defaults);
    });

    test('corruption is discarded, not thrown', () async {
      final repo = await repoWith({'settings': 'not json at all'});
      expect(repo.load(), Settings.defaults);
    });

    test('saving stamps the current schema version', () async {
      final repo = await repoWith({});
      await repo.save(const Settings(schemaVersion: 1, accentId: 'iris'));
      final s = repo.load();
      expect(s.schemaVersion, 2);
      expect(s.accentId, 'iris');
    });
  });
}
