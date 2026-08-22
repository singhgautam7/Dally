import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../storage/settings.dart';
import 'palette.dart';
import 'palettes.dart';

/// Holds and persists [Settings], the source of truth for the active palette
/// and all gameplay preferences. Kept granular so a palette switch or a single
/// toggle doesn't rebuild unrelated subtrees (widgets `select` off it).
final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> _persist(Settings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> selectPalette(String paletteId) =>
      _persist(state.copyWith(paletteId: paletteId));

  Future<void> setHaptics(bool value) =>
      _persist(state.copyWith(hapticsEnabled: value));

  Future<void> setSound(bool value) =>
      _persist(state.copyWith(soundEnabled: value));

  Future<void> setOnScreenControls(OnScreenControls value) =>
      _persist(state.copyWith(onScreenControls: value));

  Future<void> setHandedness(Handedness value) =>
      _persist(state.copyWith(handedness: value));

  Future<void> setLongPressMs(int value) =>
      _persist(state.copyWith(longPressMs: value));

  Future<void> setStyleChoice(String gameId, String styleId) {
    final next = Map<String, String>.from(state.styleChoices)..[gameId] = styleId;
    return _persist(state.copyWith(styleChoices: next));
  }
}

/// The active palette, derived from the persisted id. Unknown ids fall back to
/// the default so a stale choice can never crash the app.
final paletteProvider = Provider<Palette>((ref) {
  final id = ref.watch(settingsControllerProvider.select((s) => s.paletteId));
  return DallyPalettes.byId(id);
});
