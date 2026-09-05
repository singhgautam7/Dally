import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// On-screen control scheme for gesture games (Snake).
enum OnScreenControls { swipeOnly, dpad }

/// Where Snake's D-pad sits under the board. Centre is the default: it fills
/// the whole empty area, which is the easiest thing to hit without looking.
enum DpadPosition { left, centre, right }

/// User settings. Persisted as JSON; [schemaVersion] lets future changes
/// migrate or safely reset rather than corrupt existing installs.
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    @Default(2) int schemaVersion,

    /// **Legacy.** One stored `themeId` became the three theme keys below in
    /// v4. Still written for one release so a downgrade is survivable, and
    /// still the migration source on first launch after the update — but never
    /// read to build a palette.
    @Default('ink') String paletteId,

    /// Theme axis 1 — `'light'` or `'dark'`.
    @Default('dark') String themeMode,

    /// Theme axis 2 — one of the ten accent identities.
    @Default('azure') String accentId,

    /// Theme axis 3 — true black background. Dark only; ignored in Light.
    @Default(false) bool amoled,

    /// Accessibility: promotes the two quiet text weights a step.
    @Default(false) bool highContrastText,
    @Default(true) bool hapticsEnabled,
    @Default(false) bool soundEnabled,
    @Default(OnScreenControls.dpad) OnScreenControls onScreenControls,
    @Default(DpadPosition.centre) DpadPosition dpadPosition,
    @Default(400) int longPressMs,

    /// Ludo's die sits in the corner of whoever is in turn and is tapped to
    /// roll. Off puts it back under the board with a Roll button.
    @Default(true) bool ludoDieFollowsTurn,

    /// Collapses every animation to instant. Layered on top of the OS
    /// accessibility setting, never instead of it.
    @Default(false) bool reduceMotion,

    /// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
    @Default(<String, String>{}) Map<String, String> styleChoices,
  }) = _Settings;

  factory Settings.fromJson(Map<String, Object?> json) => _$SettingsFromJson(json);

  static const Settings defaults = Settings();
}
