import 'package:dally/core/app_providers.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/core/widgets/style_picker_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await KeyValueStore.open();
  return ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
}

void main() {
  test('a game with no styles has no default to persist', () async {
    final container = await containerWith({});
    addTearDown(container.dispose);
    final module = container.read(gameByIdProvider('random_number'))!;
    expect(module.styleOptions, isEmpty);
    expect(module.defaultStyleId, isNull);
  });

  test('the default style is the recommended one', () async {
    final container = await containerWith({});
    addTearDown(container.dispose);
    final coin = container.read(gameByIdProvider('coin_flip'))!;
    expect(coin.defaultStyleId, 'classic');
    expect(coin.styleOptions.firstWhere((o) => o.recommended).id, 'classic');
  });

  test('a chosen style is persisted and read back', () async {
    final container = await containerWith({});
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.notifier).setStyleChoice('dice', 'pixel');
    expect(container.read(settingsControllerProvider).styleChoices['dice'], 'pixel');

    // A fresh container over the same store sees the saved choice.
    final store = container.read(keyValueStoreProvider);
    final reopened = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(settingsControllerProvider).styleChoices['dice'], 'pixel');
  });

  test('choices are kept per game, not shared', () async {
    final container = await containerWith({});
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);
    await notifier.setStyleChoice('dice', 'tally');
    await notifier.setStyleChoice('coin_flip', 'pixel');
    final choices = container.read(settingsControllerProvider).styleChoices;
    expect(choices['dice'], 'tally');
    expect(choices['coin_flip'], 'pixel');
  });

  group('multi-row style pickers', () {
    test('Jumper offers a character row alongside the platform row', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final jumper = container.read(gameByIdProvider('jumper'))!;
      final groups = jumper.styleGroups;
      expect(groups, hasLength(2));
      expect(groups.map((g) => g.label), ['Character', 'Platforms']);
      // The platform row keeps the bare game id, so an existing choice is not
      // orphaned by the character row arriving beside it.
      expect(groups.firstWhere((g) => g.label == 'Platforms').id, '');
      expect(groups.firstWhere((g) => g.label == 'Character').id, 'character');
    });

    test('the two rows share an option id without sharing a choice', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final jumper = container.read(gameByIdProvider('jumper'))!;
      final character = jumper.styleGroups.firstWhere((g) => g.id == 'character');
      final platforms = jumper.styleGroups.firstWhere((g) => g.id == '');
      // Both rows have a "Pixel" — which is exactly why the key is per row.
      expect(character.options.any((o) => o.id == 'pixel'), isTrue);
      expect(platforms.options.any((o) => o.id == 'pixel'), isTrue);
      expect(styleKeyFor(jumper, character), 'jumper.character');
      expect(styleKeyFor(jumper, platforms), 'jumper');
    });

    test('each row persists on its own and survives a reopen', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final notifier = container.read(settingsControllerProvider.notifier);
      await notifier.setStyleChoice('jumper', 'hairline');
      await notifier.setStyleChoice('jumper.character', 'arrow');

      final store = container.read(keyValueStoreProvider);
      final reopened = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(reopened.dispose);
      final choices = reopened.read(settingsControllerProvider).styleChoices;
      expect(choices['jumper'], 'hairline');
      expect(choices['jumper.character'], 'arrow');
    });

    test('every row falls back to its own recommended option', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final jumper = container.read(gameByIdProvider('jumper'))!;
      for (final g in jumper.styleGroups) {
        expect(g.defaultId, g.options.firstWhere((o) => o.recommended).id,
            reason: g.label);
      }
    });

    test('a single-row game still gets exactly one group', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final dice = container.read(gameByIdProvider('dice'))!;
      expect(dice.styleGroups, hasLength(1));
      expect(dice.styleGroups.single.id, '');
      expect(dice.styleGroups.single.options, dice.styleOptions);
    });
  });

  test('a corrupt settings blob falls back to defaults rather than crashing', () async {
    final container = await containerWith({'settings': 'not json'});
    addTearDown(container.dispose);
    expect(container.read(settingsControllerProvider).styleChoices, isEmpty);
    expect(container.read(settingsControllerProvider).paletteId, 'ink');
  });

  test('a settings blob from a newer build is discarded, not guessed at', () async {
    final container = await containerWith({
      'settings': '{"schemaVersion":99,"paletteId":"future"}',
    });
    addTearDown(container.dispose);
    expect(container.read(settingsControllerProvider).paletteId, 'ink');
  });
}
