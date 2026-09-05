import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../storage/settings.dart';
import 'accents.dart';
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

  // ── Theme: three independent axes ─────────────────────────────────────────

  /// Applies a named preset by writing the triple it stands for. The preset
  /// name itself is never stored — it is derived by matching the triple back,
  /// so a preset renamed later cannot orphan anyone's settings.
  Future<void> selectPreset(ThemePreset preset) => _persist(state.copyWith(
        paletteId: preset.id,
        themeMode: preset.mode.id,
        accentId: preset.accentId,
        amoled: preset.amoled,
      ));

  /// Legacy entry point, kept for callers that still hand over a preset id.
  Future<void> selectPalette(String paletteId) =>
      selectPreset(DallyPalettes.presetById(paletteId) ?? DallyPalettes.fallback);

  Future<void> setThemeMode(DallyMode mode) => _persist(state.copyWith(themeMode: mode.id));

  Future<void> setAccent(String accentId) => _persist(state.copyWith(accentId: accentId));

  /// Dark only. A stale `true` in Light is ignored by the derivation rather
  /// than corrected here, so switching back to Dark restores what was chosen.
  Future<void> setAmoled(bool value) => _persist(state.copyWith(amoled: value));

  Future<void> setHighContrastText(bool value) =>
      _persist(state.copyWith(highContrastText: value));

  // ── Everything else ───────────────────────────────────────────────────────

  Future<void> setHaptics(bool value) =>
      _persist(state.copyWith(hapticsEnabled: value));

  Future<void> setSound(bool value) =>
      _persist(state.copyWith(soundEnabled: value));

  Future<void> setOnScreenControls(OnScreenControls value) =>
      _persist(state.copyWith(onScreenControls: value));

  Future<void> setDpadPosition(DpadPosition value) =>
      _persist(state.copyWith(dpadPosition: value));

  Future<void> setLudoDieFollowsTurn(bool value) =>
      _persist(state.copyWith(ludoDieFollowsTurn: value));

  Future<void> setLongPressMs(int value) =>
      _persist(state.copyWith(longPressMs: value));

  Future<void> setReduceMotion(bool value) =>
      _persist(state.copyWith(reduceMotion: value));

  Future<void> setStyleChoice(String gameId, String styleId) {
    final next = Map<String, String>.from(state.styleChoices)..[gameId] = styleId;
    return _persist(state.copyWith(styleChoices: next));
  }
}

/// The three theme axes, as one watchable value. Everything that cares about
/// the *choice* rather than the resolved colours (the theme screen, the preset
/// cards) reads this.
class ThemeTriple {
  const ThemeTriple(this.mode, this.accentId, this.amoled, {this.highContrastText = false});

  final DallyMode mode;
  final String accentId;
  final bool amoled;
  final bool highContrastText;

  /// AMOLED only means anything in Dark.
  bool get amoledActive => mode == DallyMode.dark && amoled;

  /// The preset this triple names, or null when it is a custom combination.
  ThemePreset? get preset => DallyPalettes.presetFor(mode, accentId, amoled);

  @override
  bool operator ==(Object other) =>
      other is ThemeTriple &&
      other.mode == mode &&
      other.accentId == accentId &&
      other.amoled == amoled &&
      other.highContrastText == highContrastText;

  @override
  int get hashCode => Object.hash(mode, accentId, amoled, highContrastText);
}

final themeTripleProvider = Provider<ThemeTriple>((ref) {
  final s = ref.watch(settingsControllerProvider.select((s) => ThemeTriple(
        modeFromId(s.themeMode),
        s.accentId,
        s.amoled,
        highContrastText: s.highContrastText,
      )));
  return s;
});

/// The active palette, derived from the three persisted axes. Unknown values
/// fall back to Ink, so a stale choice can never crash the app.
final paletteProvider = Provider<Palette>((ref) {
  final t = ref.watch(themeTripleProvider);
  return DallyPalettes.palette(
    mode: t.mode,
    accentId: t.accentId,
    amoled: t.amoled,
    highContrastText: t.highContrastText,
  );
});
