import 'package:dally/core/app_providers.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/theme_controller.dart';
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
